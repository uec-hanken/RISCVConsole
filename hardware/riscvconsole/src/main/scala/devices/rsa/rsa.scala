package riscvconsole.devices.rsa

import chisel3._
import chisel3.util._
import chisel3.util.random._
import chisel3.util.HasBlackBoxResource
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.devices.tilelink.{BasicBusBlockerParams, TLClockBlocker}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.diplomaticobjectmodel._
import freechips.rocketchip.diplomaticobjectmodel.logicaltree._
import freechips.rocketchip.diplomaticobjectmodel.model._
import freechips.rocketchip.interrupts._
import freechips.rocketchip.prci.{ClockGroup, ClockSinkDomain}
import freechips.rocketchip.regmapper._
import freechips.rocketchip.subsystem.{Attachable, PBUS, TLBusWrapperLocation}
import freechips.rocketchip.tilelink._
import freechips.rocketchip.util._


import sys.process._

case class RSAParams
(
  address: BigInt,
  impl: Int = 0,
  nbits: Int = 14
) {
  require(nbits == 14, "TODO: This RSA does not support nbits different than 14")
}

case class OMRSADevice(
                           memoryRegions: Seq[OMMemoryRegion],
                           interrupts: Seq[OMInterrupt],
                           _types: Seq[String] = Seq("OMRSADevice", "OMDevice", "OMComponent")
                         ) extends OMDevice

class RSAPortIO extends Bundle {
}


class RSA_ModExp extends BlackBox with HasBlackBoxResource {
  override def desiredName = "RSA_ModExp"
  val io = IO(new Bundle {
    //Inputs
    val iClk            = Input(Clock())
    val iRstn           = Input(Bool())
    val iStart          = Input(Bool())
    val iWrM            = Input(Bool())
    val iWrE            = Input(Bool())
    val iWrN            = Input(Bool())
    val iRdR            = Input(Bool())
    val iM              = Input(UInt(64.W))
    val iE              = Input(UInt(64.W))
    val iN              = Input(UInt(64.W))
    //Outputs
    val oDone           = Output(Bool())
    val oR              = Output(UInt(64.W))
  })
  // add wrapper/blackbox after it is pre-processed
  addResource("/rsa.preprocessed.v")
}

abstract class RSA(busWidthBytes: Int, val c: RSAParams)
                     (implicit p: Parameters)
  extends IORegisterRouter(
    RegisterRouterParams(
      name = "rsa",
      compat = Seq("uec,rsa-0"),
      base = c.address,
      beatBytes = busWidthBytes),
    new RSAPortIO
  ) {
  // The device in the dts is created here
  ResourceBinding {
    Resource(ResourceAnchors.aliases, "rsa").bind(ResourceAlias(device.label))
  }

  lazy val module = new LazyModuleImp(this) {
    // status_out
    val data_0    = RegInit(0.U(32.W))
    val data_1    = RegInit(0.U(32.W))

    val rst_core_n  = RegInit(true.B)
    val iStart      = RegInit(false.B)
    val iWrM        = WireInit(false.B)
    val iWrE        = WireInit(false.B)
    val iWrN        = WireInit(false.B)
    val iRdR        = WireInit(false.B)
    val iM_0        = RegInit(0.U(32.W))
    val iM_1        = RegInit(0.U(32.W))
    val iE_0        = RegInit(0.U(32.W))
    val iE_1        = RegInit(0.U(32.W))
    val iN_0        = RegInit(0.U(32.W))
    val iN_1        = RegInit(0.U(32.W))
    val ready       = RegInit(false.B)

    val core_rsa = Module(new RSA_ModExp())
    core_rsa.io.iClk     := clock
    core_rsa.io.iRstn    := rst_core_n
    core_rsa.io.iStart   := iStart
    core_rsa.io.iWrM     := iWrM
    core_rsa.io.iWrE     := iWrE
    core_rsa.io.iWrN     := iWrN
    core_rsa.io.iRdR     := iRdR
    core_rsa.io.iM       := Cat(iM_0,iM_1)
    core_rsa.io.iE       := Cat(iE_0,iE_1)
    core_rsa.io.iN       := Cat(iN_0,iN_1)
    //ready                := core_rsa.io.oDone
    data_0               := core_rsa.io.oR(31,0)
    data_1               := core_rsa.io.oR(63,32)

    when(iStart) {
      ready := false.B
    } .elsewhen(core_rsa.io.oDone) {
      ready := true.B
    }

    // Trsa register mapping
    val trsa_map = Seq(
      RSARegs.rst_core_n -> Seq(
        RegField(1, rst_core_n, RegFieldDesc("write_data", "Trsa write data"))
      ),
      RSARegs.iStart -> Seq(
        RegField(1, iStart, RegFieldDesc("write_data", "Trsa write data"))
      ),
      RSARegs.iWrM -> Seq(
        RegField(1, iWrM, RegFieldDesc("write_data", "Trsa write data"))
      ),
      RSARegs.iWrE -> Seq(
        RegField(1, iWrE, RegFieldDesc("write_data", "Trsa write data"))
      ),
      RSARegs.iWrN -> Seq(
        RegField(1, iWrN, RegFieldDesc("write_data", "Trsa write data"))
      ),
      RSARegs.iRdR -> Seq(
        RegField(1, iRdR, RegFieldDesc("write_data", "Trsa write data"))
      ),
      RSARegs.iM_0 -> Seq(
        RegField(32, iM_0, RegFieldDesc("write_data", "Trsa write data"))
      ),
      RSARegs.iM_1 -> Seq(
        RegField(32, iM_1, RegFieldDesc("write_data", "Trsa write data"))
      ),
      RSARegs.iE_0 -> Seq(
        RegField(32, iE_0, RegFieldDesc("write_data", "Trsa write data"))
      ),
      RSARegs.iE_1 -> Seq(
        RegField(32, iE_1, RegFieldDesc("write_data", "Trsa write data"))
      ),
      RSARegs.iN_0 -> Seq(
        RegField(32, iN_0, RegFieldDesc("write_data", "Trsa write data"))
      ),
      RSARegs.iN_1-> Seq(
        RegField(32, iN_1, RegFieldDesc("address", "Trsa address", reset = Some(0)))
      ),
      RSARegs.ready -> Seq(
        RegField.r(1, ready, RegFieldDesc("CS", "Trsa CS", volatile = true))
      ),
      RSARegs.data_0 -> Seq(
        RegField(32, data_0, RegFieldDesc("CS", "Trsa CS", volatile = true))
      ),
      RSARegs.data_1 -> Seq(
        RegField(32, data_1, RegFieldDesc("CS", "Trsa CS", volatile = true))
      )
      
    )
    regmap(
      (trsa_map):_*
    )

  }



  val logicalTreeNode = new LogicalTreeNode(() => Some(device)) {
    def getOMComponents(resourceBindings: ResourceBindings, children: Seq[OMComponent] = Nil): Seq[OMComponent] = {
      val Description(name, mapping) = device.describe(resourceBindings)
      val memRegions = DiplomaticObjectModelAddressing.getOMMemoryRegions(name, resourceBindings, None)
      val interrupts = DiplomaticObjectModelAddressing.describeInterrupts(name, resourceBindings)
      Seq(
        OMRSADevice(
          memoryRegions = memRegions.map(_.copy(
            name = "rsa",
            description = "RSA Push-Register Device"
          )),
          interrupts = interrupts
        )
      )
    }
  }
}

class TLRSA(busWidthBytes: Int, params: RSAParams)(implicit p: Parameters)
  extends RSA(busWidthBytes, params) with HasTLControlRegMap

case class RSAAttachParams
(
  rsapar: RSAParams,
  controlWhere: TLBusWrapperLocation = PBUS,
  blockerAddr: Option[BigInt] = None,
  controlXType: ClockCrossingType = NoCrossing,
  intXType: ClockCrossingType = NoCrossing)(implicit val p: Parameters) {

  def RSAGen(cbus: TLBusWrapper)(implicit valName: ValName): RSA with HasTLControlRegMap = {
    LazyModule(new TLRSA(cbus.beatBytes, rsapar))
  }

  def attachTo(where: Attachable)(implicit p: Parameters): RSA with HasTLControlRegMap = {
    val name = s"rsa_${RSA.nextId()}"
    val cbus = where.locateTLBusWrapper(controlWhere)
    val rsaClockDomainWrapper = LazyModule(new ClockSinkDomain(take = None))
    val rsa = rsaClockDomainWrapper { RSAGen(cbus) }
    rsa.suggestName(name)

    cbus.coupleTo(s"device_named_$name") { bus =>

      val blockerOpt = blockerAddr.map { a =>
        val blocker = LazyModule(new TLClockBlocker(BasicBusBlockerParams(a, cbus.beatBytes, cbus.beatBytes)))
        cbus.coupleTo(s"bus_blocker_for_$name") { blocker.controlNode := TLFragmenter(cbus) := _ }
        blocker
      }

      rsaClockDomainWrapper.clockNode := (controlXType match {
        case _: SynchronousCrossing =>
          cbus.dtsClk.map(_.bind(rsa.device))
          cbus.fixedClockNode
        case _: RationalCrossing =>
          cbus.clockNode
        case _: AsynchronousCrossing =>
          val rsaClockGroup = ClockGroup()
          rsaClockGroup := where.asyncClockGroupsNode
          blockerOpt.map { _.clockNode := rsaClockGroup } .getOrElse { rsaClockGroup }
      })

      (rsa.controlXing(controlXType)
        := TLFragmenter(cbus)
        := blockerOpt.map { _.node := bus } .getOrElse { bus })
    }

    LogicalModuleTree.add(where.logicalTreeNode, rsa.logicalTreeNode)

    rsa
  }
}

object RSA {
  val nextId = {
    var i = -1; () => {
      i += 1; i
    }
  }
}




