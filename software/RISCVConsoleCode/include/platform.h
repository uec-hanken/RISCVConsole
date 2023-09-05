// See LICENSE for license details.

#ifndef _SIFIVE_PLATFORM_H
#define _SIFIVE_PLATFORM_H

#include "const.h"
#include "devices/clint.h"
#include "devices/gpio.h"
#include "devices/plic.h"
#include "devices/spi.h"
#include "devices/uart.h"
#include "devices/i2c.h"

#include "devices/rsa.h"
#include "devices/sha3.h"
#include "devices/aes.h"

 // Some things missing from the official encoding.h
#if __riscv_xlen == 32
  #define MCAUSE_INT         0x80000000UL
  #define MCAUSE_CAUSE       0x7FFFFFFFUL
#else
   #define MCAUSE_INT         0x8000000000000000UL
   #define MCAUSE_CAUSE       0x7FFFFFFFFFFFFFFFUL
#endif

// Only include the stuff that is just going to be here always, regardless of the hw configuration.
#define CLINT_CTRL_ADDR _AC(0x2000000,UL)
#define CLINT_CTRL_SIZE _AC(0x10000,UL)
#define MEMORY_MEM_ADDR _AC(0x80000000,UL)
#define MEMORY_MEM_SIZE _AC(0x40000000,UL)
#define PLIC_CTRL_ADDR _AC(0xc000000,UL)
#define PLIC_CTRL_SIZE _AC(0x4000000,UL)

// Helper functions
#define _REG64(p, i) (*(volatile uint64_t *)((p) + (i)))
#define _REG32(p, i) (*(volatile uint32_t *)((p) + (i)))
#define _REG16(p, i) (*(volatile uint16_t *)((p) + (i)))
// Bulk set bits in `reg` to either 0 or 1.
// E.g. SET_BITS(MY_REG, 0x00000007, 0) would generate MY_REG &= ~0x7
// E.g. SET_BITS(MY_REG, 0x00000007, 1) would generate MY_REG |= 0x7
#define SET_BITS(reg, mask, value) if ((value) == 0) { (reg) &= ~(mask); } else { (reg) |= (mask); }
#define CLINT_REG(offset) _REG32(CLINT_CTRL_ADDR, offset)
#define CLINT_REG64(offset) _REG64(CLINT_CTRL_ADDR, offset)


#endif /* _SIFIVE_PLATFORM_H */
