/* Copyright (c) 2018 SiFive, Inc */
/* SPDX-License-Identifier: Apache-2.0 */
/* SPDX-License-Identifier: GPL-2.0-or-later */
/* See the file LICENSE for further information */

#include "clkutils.h"
#include "main.h"

extern inline uint64_t clkutils_read_mtime();
extern inline uint64_t clkutils_read_mcycle();
extern inline void clkutils_delay_ns(int delay_ns, int period_ns);

#define TIMEBASE timescale_freq

uint32_t metal_time(void) {

  uint32_t mtime_hi_0;
  uint32_t mtime_lo;
  uint32_t mtime_hi_1;
  do {
    mtime_hi_0 = CLINT_REG(CLINT_MTIME + 4);
    mtime_lo   = CLINT_REG(CLINT_MTIME + 0);
    mtime_hi_1 = CLINT_REG(CLINT_MTIME + 4);
  } while (mtime_hi_0 != mtime_hi_1);

  //uint64_t time = (((uint64_t) mtime_hi_1 << 32) | ((uint64_t) mtime_lo));
  
  return (uint32_t)(mtime_lo / TIMEBASE);
}

