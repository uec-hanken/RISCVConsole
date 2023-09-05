package riscvconsole.devices.rsa


object RSARegs {
  val rst_core_n     = 0x100
  val iStart         = 0x104
  val iWrM           = 0x108
  val iWrE           = 0x10C
  val iWrN           = 0x110
  val iRdR           = 0x114
  val iM_0           = 0x118
  val iM_1           = 0x11C
  val iE_0           = 0x120
  val iE_1           = 0x124
  val iN_0           = 0x128
  val iN_1           = 0x12C
  val ready          = 0x130
  val data_0         = 0x134
  val data_1         = 0x138
}
