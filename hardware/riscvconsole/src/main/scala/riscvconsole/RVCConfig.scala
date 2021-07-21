package riscvconsole.system

import chipsalliance.rocketchip.config._
import freechips.rocketchip.subsystem.{PeripheryBusKey, SystemBusKey, WithRV32}
import freechips.rocketchip.devices.debug._
import riscvconsole.devices.sdram._

class RVCPeripheralsConfig(gpio: Int = 14) extends Config((site, here, up) => {
  case sifive.blocks.devices.uart.PeripheryUARTKey => Seq(
    sifive.blocks.devices.uart.UARTParams(0x10000000))
  case sifive.blocks.devices.gpio.PeripheryGPIOKey => Seq(
    sifive.blocks.devices.gpio.GPIOParams(0x10001000, gpio))
  case freechips.rocketchip.subsystem.PeripheryMaskROMKey => Seq(
    freechips.rocketchip.devices.tilelink.MaskROMParams(0x10000, "MyBootROM"))
  case SDRAMKey => Seq(
    SDRAMConfig(
      address = 0x90000000L,
      sdcfg = sdram_bb_cfg(SDRAM_HZ = site(SystemBusKey).dtsFrequency.getOrElse(100000000L))))
})

class SetFrequency(freq: BigInt) extends Config((site, here, up) => {
  case PeripheryBusKey => up(PeripheryBusKey).copy(dtsFrequency = Some(freq))
  case SystemBusKey => up(SystemBusKey).copy(dtsFrequency = Some(freq))
  case SDRAMKey => up(SDRAMKey).map{sd => sd.copy(sdcfg = sd.sdcfg.copy(SDRAM_HZ = freq))}
})

class RemoveSDRAM extends Config((site, here, up) => {
  case SDRAMKey => Nil
})

class RemoveDebugClockGating extends Config((site, here, up) => {
  case DebugModuleKey => up(DebugModuleKey).map{ debug =>
    debug.copy(clockGate = false)
  }
})

class RVCConfig extends Config(
  new RVCPeripheralsConfig ++
    new SetFrequency(50000000) ++
    new RemoveDebugClockGating ++
    new freechips.rocketchip.subsystem.WithJtagDTM ++
    new freechips.rocketchip.subsystem.WithNoMemPort ++              // no top-level memory port at 0x80000000
    new freechips.rocketchip.subsystem.WithNoMMIOPort ++           // no top-level MMIO master port (overrides default set in rocketchip)
    new freechips.rocketchip.subsystem.WithNoSlavePort ++          // no top-level MMIO slave port (overrides default set in rocketchip)
    new freechips.rocketchip.subsystem.WithInclusiveCache ++       // use Sifive L2 cache
    new freechips.rocketchip.subsystem.WithNExtTopInterrupts(0) ++ // no external interrupts
    new freechips.rocketchip.subsystem.With1TinyCore ++            // single rocket-core with scratchpad
    new WithRV32 ++
    new freechips.rocketchip.subsystem.WithIncoherentBusTopology ++  // Hierarchical buses with broadcast L2
    new freechips.rocketchip.system.BaseConfig)                    // "base" rocketchip system

class RVCHarnessConfig extends Config(new SetFrequency(100000000) ++ new RVCConfig)

class ArrowConfig extends Config(
  new RemoveSDRAM ++
    new RVCPeripheralsConfig(10) ++
    new RemoveDebugClockGating ++
    new freechips.rocketchip.subsystem.WithJtagDTM ++
    new freechips.rocketchip.subsystem.WithNoMemPort ++              // no top-level memory port at 0x80000000
    new freechips.rocketchip.subsystem.WithNoMMIOPort ++           // no top-level MMIO master port (overrides default set in rocketchip)
    new freechips.rocketchip.subsystem.WithNoSlavePort ++          // no top-level MMIO slave port (overrides default set in rocketchip)
    new freechips.rocketchip.subsystem.WithInclusiveCache ++       // use Sifive L2 cache
    new freechips.rocketchip.subsystem.WithNExtTopInterrupts(0) ++ // no external interrupts
    new freechips.rocketchip.subsystem.With1TinyCore ++            // single rocket-core with scratchpad
    new WithRV32 ++
    new freechips.rocketchip.subsystem.WithIncoherentBusTopology ++  // Hierarchical buses without L2
    new freechips.rocketchip.system.BaseConfig)                    // "base" rocketchip system
