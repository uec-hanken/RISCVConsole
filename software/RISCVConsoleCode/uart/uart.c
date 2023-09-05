/* Copyright (c) 2018 SiFive, Inc */
/* SPDX-License-Identifier: Apache-2.0 */
/* SPDX-License-Identifier: GPL-2.0-or-later */
/* See the file LICENSE for further information */

#include <stdatomic.h>
#include <platform.h>
#include <stdint.h>
#include <stddef.h>
#include "uart.h"


void uart_putc(void* uartctrl, char c) {
  if(uartctrl == NULL) return;
#if __riscv_atomic
  int32_t r;
  do {
    asm volatile (
      "amoor.w %0, %2, %1\n"
      : "=r" (r), "+A" (_REG32((char*)uartctrl, UART_REG_TXFIFO))
      : "r" (c)
    );
  } while (r < 0);
#else
  while ((int) _REG32((char*)uartctrl, UART_REG_TXFIFO) < 0);
  _REG32((char*)uartctrl, UART_REG_TXFIFO) = c;
#endif
}


char uart_getc(void* uartctrl){
  if(uartctrl == NULL) return 0;
  int32_t val = -1;
  while (val < 0){
    val = (int32_t) _REG32((char*)uartctrl, UART_REG_RXFIFO);
  }
  return val & 0xFF;
}


void uart_puts(void* uartctrl, const char * s) {
  if(uartctrl == NULL) return;
  while (*s != '\0'){
    uart_putc(uartctrl, *s++);
  }
}

void uart_put_hex_1b(void* uartctrl, uint8_t hex) {
  if(uartctrl == NULL) return;
  int num_nibbles = sizeof(hex) * 2;
  for (int nibble_idx = num_nibbles - 1; nibble_idx >= 0; nibble_idx--) {
    char nibble = (hex >> (nibble_idx * 4)) & 0xf;
    uart_putc(uartctrl, (nibble < 0xa) ? ('0' + nibble) : ('a' + nibble - 0xa));
  }
}


void uart_put_hex(void* uartctrl, uint32_t hex) {
  if(uartctrl == NULL) return;
  int num_nibbles = sizeof(hex) * 2;
  for (int nibble_idx = num_nibbles - 1; nibble_idx >= 0; nibble_idx--) {
    char nibble = (hex >> (nibble_idx * 4)) & 0xf;
    uart_putc(uartctrl, (nibble < 0xa) ? ('0' + nibble) : ('a' + nibble - 0xa));
  }
}

void uart_put_hex64(void *uartctrl, uint64_t hex){
  if(uartctrl == NULL) return;
  uart_put_hex(uartctrl,hex>>32);
  uart_put_hex(uartctrl,hex&0xFFFFFFFF);
}


void uart_put_dec(void* uartctrl, uint32_t dec) {
  if(uartctrl == NULL) return;
  char p[10];
  uint32_t num = dec;
  if(num==0) uart_putc(uartctrl, '0');
  else {
    for(int i=9; i>=0; i--) {
      p[i] = '0' + num%10;
      num = num/10;
    }
    int flag=0;
    for(int i=0; i<10; i++) {
      if((p[i]!='0')||(flag==1)) {
        uart_putc(uartctrl, p[i]);
        flag = 1;
      }
    }
  }
}
