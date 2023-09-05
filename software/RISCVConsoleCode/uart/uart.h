/* Copyright (c) 2018 SiFive, Inc */
/* SPDX-License-Identifier: Apache-2.0 */
/* SPDX-License-Identifier: GPL-2.0-or-later */
/* See the file LICENSE for further information */

#ifndef _DRIVERS_UART_H
#define _DRIVERS_UART_H


#ifndef __ASSEMBLER__

void uart_putc(void* uartctrl, char c);
char uart_getc(void* uartctrl);
void uart_puts(void* uartctrl, const char * s);
void uart_put_hex_1b(void* uartctrl, uint8_t dec);
void uart_put_hex(void* uartctrl, uint32_t hex);
void uart_put_hex64(void* ua64ctrl, uint64_t hex);
void uart_put_dec(void* uartctrl, uint32_t dec);

#include <stdint.h>
/**
 * Get smallest clock divisor that divides input_hz to a quotient less than or
 * equal to max_target_hz;
 */
static inline unsigned int uart_min_clk_divisor(unsigned long input_hz, unsigned long max_target_hz)
{
  // f_baud = f_in / (div + 1) => div = (f_in / f_baud) - 1
  // div = (f_in / f_baud) - 1
  //
  // The nearest integer solution for div requires rounding up as to not exceed
  // max_target_hz.
  //
  // div = ceil(f_in / f_baud) - 1
  //     = floor((f_in - 1 + f_baud) / f_baud) - 1
  //
  // This should not overflow as long as (f_in - 1 + f_baud) does not exceed
  // 2^32 - 1, which is unlikely since we represent frequencies in kHz.
  unsigned long quotient = (input_hz + max_target_hz - 1) / (max_target_hz);
  // Avoid underflow
  if (quotient == 0) {
    return 0;
  } else {
    return quotient - 1;
  }
}

#endif /* !__ASSEMBLER__ */

#endif /* _DRIVERS_UART_H */
