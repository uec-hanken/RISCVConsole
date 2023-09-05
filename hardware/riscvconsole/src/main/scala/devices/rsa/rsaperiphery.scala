package riscvconsole.devices.rsa

import freechips.rocketchip.config.Field
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.subsystem.BaseSubsystem

case object PeripheryRSAKey extends Field[List[RSAParams]](List())

trait HasPeripheryRSAFull  { this: BaseSubsystem =>
  val rsaNodes = p(PeripheryRSAKey).zipWithIndex.map{ case (key, i) =>
    RSAAttachParams(key).attachTo(this).ioNode.makeSink
  }
}

trait HasPeripheryRSAFullModuleImp extends LazyModuleImp {
  val outer: HasPeripheryRSAFull
  val rsa = outer.rsaNodes.zipWithIndex.map{ case (node, i) =>
    node.makeIO()(ValName(s"rsa_" + i))
  }
}
