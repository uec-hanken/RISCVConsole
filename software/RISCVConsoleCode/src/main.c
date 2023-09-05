/* Copyright (c) 2018 SiFive, Inc */
/* SPDX-License-Identifier: Apache-2.0 */
/* SPDX-License-Identifier: GPL-2.0-or-later */
/* See the file LICENSE for further information */

#include "main.h"
#include "encoding.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>
#include <stdio.h>
#include <barrier.h>
#include <platform.h>
#include <plic/plic_driver.h>

#include "libfdt/libfdt.h"
#include "uart/uart.h"
#include <kprintf/kprintf.h>

#include "lib/rsa/rsa.h"
#include "lib/rsa/rsa.c"
#include "util/rsa.c"
#include "lib/sha3/sha3.h"
#include "lib/hwsha3/hwsha3.h"
#include "lib/aes/aes.h"

#include "common.h"

unsigned long aes_reg;
unsigned long sha3_reg;
unsigned long rsa_reg;
volatile unsigned long dtb_target;

// Sanctum header fields in DRAM
extern byte sanctum_m_public_key[32];
extern byte sanctum_dev_public_key[32];
extern byte sanctum_dev_secret_key[64];
unsigned int sanctum_sm_size;
extern byte sanctum_sm_hash[64];
extern byte sanctum_sm_public_key[32];
extern byte sanctum_sm_secret_key[64];
extern byte sanctum_sm_signature[64];

// Structures for registering different interrupt handlers
// for different parts of the application.
void no_interrupt_handler (void) {};
function_ptr_t g_ext_interrupt_handlers[32];
function_ptr_t g_time_interrupt_handler = no_interrupt_handler;
plic_instance_t g_plic;// Instance data for the PLIC.

#define RTC_FREQ 1000000 // TODO: This is now extracted

void boot_fail(long code, int trap)
{
  kputs("BOOT FAILED\r\nCODE: ");
  uart_put_hex((void*)uart_reg, code);
  kputs("\r\nTRAP: ");
  uart_put_hex((void*)uart_reg, trap);
  while(1);
}

void handle_m_ext_interrupt(){
  int int_num  = PLIC_claim_interrupt(&g_plic);
  if ((int_num >=1 ) && (int_num < 32/*plic_ndevs*/)) {
    g_ext_interrupt_handlers[int_num]();
  }
  else {
    boot_fail((long) read_csr(mcause), 1);
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");
  }
  PLIC_complete_interrupt(&g_plic, int_num);
}

void handle_m_time_interrupt() {
  clear_csr(mie, MIP_MTIP);

  // Reset the timer for 1s in the future.
  // This also clears the existing timer interrupt.

  volatile unsigned long *mtime    = (unsigned long*)(CLINT_CTRL_ADDR + CLINT_MTIME);
  volatile unsigned long *mtimecmp = (unsigned long*)(CLINT_CTRL_ADDR + CLINT_MTIMECMP);
  unsigned long now = *mtime;
  unsigned long then = now + RTC_FREQ;
  *mtimecmp = then;

  g_time_interrupt_handler();

  // Re-enable the timer interrupt.
  set_csr(mie, MIP_MTIP);
}

uintptr_t handle_trap(uintptr_t mcause, uintptr_t epc)
{
  // External Machine-Level interrupt from PLIC
  if ((mcause & MCAUSE_INT) && ((mcause & MCAUSE_CAUSE) == IRQ_M_EXT)) {
    handle_m_ext_interrupt();
    // External Machine-Level interrupt from PLIC
  } else if ((mcause & MCAUSE_INT) && ((mcause & MCAUSE_CAUSE) == IRQ_M_TIMER)){
    handle_m_time_interrupt();
  }
  else {
    boot_fail((long) read_csr(mcause), 1);
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");
  }
  return epc;
}

// Helpers for fdt

void remove_from_dtb(void* dtb_target, const char* path) {
  int nodeoffset;
  int err;
	do{
    nodeoffset = fdt_path_offset((void*)dtb_target, path);
    if(nodeoffset >= 0) {
      kputs("\r\nINFO: Removing ");
      kputs(path);
      err = fdt_del_node((void*)dtb_target, nodeoffset);
      if (err < 0) {
        kputs("\r\nWARNING: Cannot remove a subnode ");
        kputs(path);
      }
    }
  } while (nodeoffset >= 0) ;
}

static int fdt_translate_address(void *fdt, uint64_t reg, int parent,
				 unsigned long *addr)
{
	int i, rlen;
	int cell_addr, cell_size;
	const fdt32_t *ranges;
	uint64_t offset = 0, caddr = 0, paddr = 0, rsize = 0;

	cell_addr = fdt_address_cells(fdt, parent);
	if (cell_addr < 1)
		return -FDT_ERR_NOTFOUND;

	cell_size = fdt_size_cells(fdt, parent);
	if (cell_size < 0)
		return -FDT_ERR_NOTFOUND;

	ranges = fdt_getprop(fdt, parent, "ranges", &rlen);
	if (ranges && rlen > 0) {
		for (i = 0; i < cell_addr; i++)
			caddr = (caddr << 32) | fdt32_to_cpu(*ranges++);
		for (i = 0; i < cell_addr; i++)
			paddr = (paddr << 32) | fdt32_to_cpu(*ranges++);
		for (i = 0; i < cell_size; i++)
			rsize = (rsize << 32) | fdt32_to_cpu(*ranges++);
		if (reg < caddr || caddr >= (reg + rsize )) {
			//kprintf("invalid address translation\n");
			return -FDT_ERR_NOTFOUND;
		}
		offset = reg - caddr;
		*addr = paddr + offset;
	} else {
		/* No translation required */
		*addr = reg;
	}

	return 0;
}

int fdt_get_node_addr_size(void *fdt, int node, unsigned long *addr,
			   unsigned long *size)
{
	int parent, len, i, rc;
	int cell_addr, cell_size;
	const fdt32_t *prop_addr, *prop_size;
	uint64_t temp = 0;

	parent = fdt_parent_offset(fdt, node);
	if (parent < 0)
		return parent;
	cell_addr = fdt_address_cells(fdt, parent);
	if (cell_addr < 1)
		return -FDT_ERR_NOTFOUND;

	cell_size = fdt_size_cells(fdt, parent);
	if (cell_size < 0)
		return -FDT_ERR_NOTFOUND;

	prop_addr = fdt_getprop(fdt, node, "reg", &len);
	if (!prop_addr)
		return -FDT_ERR_NOTFOUND;
	prop_size = prop_addr + cell_addr;

	if (addr) {
		for (i = 0; i < cell_addr; i++)
			temp = (temp << 32) | fdt32_to_cpu(*prop_addr++);
		do {
			if (parent < 0)
				break;
			rc  = fdt_translate_address(fdt, temp, parent, addr);
			if (rc)
				break;
			parent = fdt_parent_offset(fdt, parent);
			temp = *addr;
		} while (1);
	}
	temp = 0;

	if (size) {
		for (i = 0; i < cell_size; i++)
			temp = (temp << 32) | fdt32_to_cpu(*prop_size++);
		*size = temp;
	}

	return 0;
}

int fdt_parse_hart_id(void *fdt, int cpu_offset, uint32_t *hartid)
{
	int len;
	const void *prop;
	const fdt32_t *val;

	if (!fdt || cpu_offset < 0)
		return -FDT_ERR_NOTFOUND;

	prop = fdt_getprop(fdt, cpu_offset, "device_type", &len);
	if (!prop || !len)
		return -FDT_ERR_NOTFOUND;
	if (strncmp (prop, "cpu", strlen ("cpu")))
		return -FDT_ERR_NOTFOUND;

	val = fdt_getprop(fdt, cpu_offset, "reg", &len);
	if (!val || len < sizeof(fdt32_t))
		return -FDT_ERR_NOTFOUND;

	if (len > sizeof(fdt32_t))
		val++;

	if (hartid)
		*hartid = fdt32_to_cpu(*val);

	return 0;
}

int fdt_parse_max_hart_id(void *fdt, uint32_t *max_hartid)
{
	uint32_t hartid;
	int err, cpu_offset, cpus_offset;

	if (!fdt)
		return -FDT_ERR_NOTFOUND;
	if (!max_hartid)
		return 0;

	*max_hartid = 0;

	cpus_offset = fdt_path_offset(fdt, "/cpus");
	if (cpus_offset < 0)
		return cpus_offset;

	fdt_for_each_subnode(cpu_offset, fdt, cpus_offset) {
		err = fdt_parse_hart_id(fdt, cpu_offset, &hartid);
		if (err)
			continue;

		if (hartid > *max_hartid)
			*max_hartid = hartid;
	}

	return 0;
}

int fdt_find_or_add_subnode(void *fdt, int parentoffset, const char *name)
{
  int offset;

  offset = fdt_subnode_offset(fdt, parentoffset, name);

  if (offset == -FDT_ERR_NOTFOUND)
    offset = fdt_add_subnode(fdt, parentoffset, name);

  if (offset < 0) {
  	uart_puts((void*)uart_reg, fdt_strerror(offset));
  	uart_puts((void*)uart_reg, "\r\n");
  }

  return offset;
}
int timescale_freq = 0;

// Register to extract
unsigned long uart_reg = 0;
int tlclk_freq;
unsigned long plic_reg;
int plic_max_priority;
int plic_ndevs;
int timescale_freq;

void print_meas (uint32_t meas) {
  //uart_put_dec((void*)uart_reg, meas/1000000);
  //uart_puts((void*)uart_reg,"s ");
  //uart_put_dec((void*)uart_reg, (meas%1000000)/1000);
  //uart_puts((void*)uart_reg,"ms ");
  //uart_put_dec((void*)uart_reg, meas%1000);
  //uart_puts((void*)uart_reg,"us\r\n");

  // Use timescale_freq instead of dividing by 1MHz
  uart_put_dec((void*)uart_reg, meas/timescale_freq);
  uart_puts((void*)uart_reg,"s ");
  uart_put_dec((void*)uart_reg, (meas/(timescale_freq/1000))%1000);
  uart_puts((void*)uart_reg,"ms ");
  uart_put_dec((void*)uart_reg, (meas/(timescale_freq/1000000))%1000);
  uart_puts((void*)uart_reg,"us\r\n");
}


void rsa_test(void* rsactrl) {
  uart_puts((void*)uart_reg,"Begin RSA hardware test:\r\n");
  uart_puts((void*)uart_reg,"\r\n");

  uart_puts((void*)uart_reg, "\rSoftware: \r\n");

  uint64_t waitd = sw_rsa_selftest(rsactrl);

  uart_puts((void*)uart_reg, "\rHardware: \r\n");

  hw_rsa_selftest(rsactrl, waitd);

}
// read a hex string, return byte length or -1 on error.

static int test_hexdigit(char ch)
{
    if (ch >= '0' && ch <= '9')
        return  ch - '0';
    if (ch >= 'A' && ch <= 'F')
        return  ch - 'A' + 10;
    if (ch >= 'a' && ch <= 'f')
        return  ch - 'a' + 10;
    return -1;
}

static int test_readhex(uint8_t *buf, const char *str, int maxbytes)
{
    int i, h, l;

    for (i = 0; i < maxbytes; i++) {
        h = test_hexdigit(str[2 * i]);
        if (h < 0)
            return i;
        l = test_hexdigit(str[2 * i + 1]);
        if (l < 0)
            return i;
        buf[i] = (h << 4) + l;
    }

    return i;
}

void hwsha3_test(void* sha3ctrl) {
  #include "use_test_keys.h"
  sanctum_sm_size = 0x200;
  // Reserve stack space for secrets
  byte pad[64], swpad[64];
  uint32_t* hs = (uint32_t*)pad;
  uint32_t* ss = (uint32_t*)swpad;
  sha3_ctx_t hash_ctx;
  uint64_t start_mtime;
  uint64_t delta_mtime;

  uart_puts((void*)uart_reg,"Begin SHA-3 hardware test:\r\n\n");

  start_mtime = clkutils_read_mtime();
  sha3_init(&hash_ctx, 64);
  sha3_update(&hash_ctx, (void*)PAYLOAD_DEST, sanctum_sm_size);
  sha3_final(sanctum_sm_hash, &hash_ctx);
  sha3_init(&hash_ctx, 64);
  sha3_update(&hash_ctx, sanctum_dev_secret_key, sizeof(sanctum_dev_secret_key)); // 64
  sha3_update(&hash_ctx, sanctum_sm_hash, sizeof(sanctum_sm_hash)); // 64
  sha3_final(swpad, &hash_ctx);
  delta_mtime = clkutils_read_mtime() - start_mtime;
  uart_puts((void*)uart_reg, "Software: ");
  print_meas(delta_mtime);
  for(int i=0; i<16; i++)
    uart_put_hex((void*)uart_reg, *(ss+i));
  uart_puts((void*)uart_reg,"\r\n\n");

  start_mtime = clkutils_read_mtime();
  hwsha3_init((void*)sha3ctrl);
  hwsha3_final((void*)sha3ctrl, sanctum_sm_hash, (void*)PAYLOAD_DEST, sanctum_sm_size);
  hwsha3_init((void*)sha3ctrl);
  hwsha3_update((void*)sha3ctrl, sanctum_dev_secret_key, sizeof(sanctum_dev_secret_key)); // 64
  hwsha3_final((void*)sha3ctrl, pad, sanctum_sm_hash, sizeof(sanctum_sm_hash)); // 64
  delta_mtime = clkutils_read_mtime() - start_mtime;
  uart_puts((void*)uart_reg, "Hardware: ");
  print_meas(delta_mtime);
  for(int i=0; i<16; i++)
    uart_put_hex((void*)uart_reg, *(hs+i));
  uart_puts((void*)uart_reg,"\r\n\n");

  for(int i=0; i<64; i++)
    if(swpad[i]!=pad[i]) {
      uart_puts((void*)uart_reg,"SHA-3 hardware test fail!\r\n\n\n");
      return;
    }
  uart_puts((void*)uart_reg,"SHA-3 hardware test passed!\r\n\n\n");
}

void hwaes_test(void* aesctrl) {
  uint64_t start_mtime;
  uint64_t delta_mtime;

  // Vectors extracted from the tiny AES test.c file in AES128 mode
  uint8_t aeskey[] = { 0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c };
  //uint8_t aesout[] = { 0x3a, 0xd7, 0x7b, 0xb4, 0x0d, 0x7a, 0x36, 0x60, 0xa8, 0x9e, 0xca, 0xf3, 0x24, 0x66, 0xef, 0x97 };
  uint8_t aesin1[] = { 0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a };
  uint8_t aesin2[] = { 0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a };
  struct AES_ctx ctx;

  uart_puts((void*)uart_reg,"Begin AES hardware test:\r\n\n");

  // Software encrypt AES128
  start_mtime = clkutils_read_mtime();
  AES_init_ctx(&ctx, aeskey);
  AES_ECB_encrypt(&ctx, aesin1);
  delta_mtime = clkutils_read_mtime() - start_mtime;
  uart_puts((void*)uart_reg, "Software: ");
  print_meas(delta_mtime);
  for(int i = 0; i < 4; i++)
    uart_put_hex((void*)uart_reg, *((uint32_t*)aesin1+i));

  // Hardware encrypt AES128
  start_mtime = clkutils_read_mtime();
  // Put the key (only 128 bits lower)
  for(int i = 0; i < 4; i++)
    _REG32((char*)aesctrl, AES_REG_KEY + i*4) = *((uint32_t*)aeskey+i);
  for(int i = 4; i < 8; i++)
    _REG32((char*)aesctrl, AES_REG_KEY + i*4) = 0; // Clean the "other part" of the key, "just in case"
  _REG32((char*)aesctrl, AES_REG_CONFIG) = 1; // AES128, encrypt
  _REG32((char*)aesctrl, AES_REG_STATUS) = 1; // Key Expansion Enable
  while(!(_REG32((char*)aesctrl, AES_REG_STATUS) & 0x4)); // Wait for ready
  // Put the data
  for(int i = 0; i < 4; i++)
    _REG32((char*)aesctrl, AES_REG_BLOCK + i*4) = *((uint32_t*)aesin2+i);
  _REG32((char*)aesctrl, AES_REG_STATUS) = 2; // Data enable
  while(!(_REG32((char*)aesctrl, AES_REG_STATUS) & 0x4)); // Wait for ready
  // Copy back the data to the pointer
  for(int i = 0; i < 4; i++)
    *((uint32_t*)aesin2+i) = _REG32((char*)aesctrl, AES_REG_RESULT + i*4);
  delta_mtime = clkutils_read_mtime() - start_mtime;
  uart_puts((void*)uart_reg, "\r\n\nHardware: ");
  print_meas(delta_mtime);
  for(int i = 0; i < 4; i++)
    uart_put_hex((void*)uart_reg, *((uint32_t*)aesin2+i));
  uart_puts((void*)uart_reg,"\r\n\n");

  for(int i=0; i<16; i++) {
    if(aesin1[i]!=aesin2[i]) {
      uart_puts((void*)uart_reg,"AES hardware test fail!\r\n\n\n");
      return;
    }
  }
  uart_puts((void*)uart_reg,"AES hardware test passed!\r\n\n\n");
}


//HART 0 runs main
int main(int id, unsigned long dtb)
{
  // Use the FDT to get some devices
  int nodeoffset;
  int err = 0;
  int len;
	const fdt32_t *val;
  
  // 1. Get the uart reg
  nodeoffset = fdt_path_offset((void*)dtb, "/soc/serial");
  if (nodeoffset < 0) while(1);
  err = fdt_get_node_addr_size((void*)dtb, nodeoffset, &uart_reg, NULL);
  if (err < 0) while(1);
  // NOTE: If want to force UART, uncomment these
  //uart_reg = 0x64000000;
  //tlclk_freq = 20000000;
  _REG32(uart_reg, UART_REG_TXCTRL) = UART_TXEN;
  _REG32(uart_reg, UART_REG_RXCTRL) = UART_RXEN;
  
  // 2. Get tl_clk 
  nodeoffset = fdt_path_offset((void*)dtb, "/soc/subsystem_pbus_clock");
  if (nodeoffset < 0) {
    kputs("\r\nCannot find '/soc/subsystem_pbus_clock'\r\nAborting...");
    while(1);
  }
  val = fdt_getprop((void*)dtb, nodeoffset, "clock-frequency", &len);
  if(!val || len < sizeof(fdt32_t)) {
    kputs("\r\nThere is no clock-frequency in '/soc/subsystem_pbus_clock'\r\nAborting...");
    while(1);
  }
  if (len > sizeof(fdt32_t)) val++;
  tlclk_freq = fdt32_to_cpu(*val);
  _REG32(uart_reg, UART_REG_DIV) = uart_min_clk_divisor(tlclk_freq, 115200);
  
  // 3. Get the mem_size
  nodeoffset = fdt_path_offset((void*)dtb, "/memory");
  if (nodeoffset < 0) {
    kputs("\r\nCannot find '/memory'\r\nAborting...");
    while(1);
  }
  unsigned long mem_base, mem_size;
  err = fdt_get_node_addr_size((void*)dtb, nodeoffset, &mem_base, &mem_size);
  if (err < 0) {
    kputs("\r\nCannot get reg space from '/memory'\r\nAborting...");
    while(1);
  }
  unsigned long ddr_size = (unsigned long)mem_size; // TODO; get this
  unsigned long ddr_end = (unsigned long)mem_base + ddr_size;
  
  // 4. Get the number of cores
  uint32_t num_cores = 0;
  err = fdt_parse_max_hart_id((void*)dtb, &num_cores);
  num_cores++; // Gives maxid. For max cores we need to add 1
  
  // 5. Get the plic parameters
  nodeoffset = fdt_path_offset((void*)dtb, "/soc/interrupt-controller");
  if (nodeoffset < 0) {
    kputs("\r\nCannot find '/soc/interrupt-controller'\r\nAborting...");
    while(1);
  }
  
  err = fdt_get_node_addr_size((void*)dtb, nodeoffset, &plic_reg, NULL);
  if (err < 0) {
    kputs("\r\nCannot get reg space from '/soc/interrupt-controller'\r\nAborting...");
    while(1);
  }
  
  val = fdt_getprop((void*)dtb, nodeoffset, "riscv,ndev", &len);
  if(!val || len < sizeof(fdt32_t)) {
    kputs("\r\nThere is no riscv,ndev in '/soc/interrupt-controller'\r\nAborting...");
    while(1);
  }
  if (len > sizeof(fdt32_t)) val++;
  plic_ndevs = fdt32_to_cpu(*val);
  
  val = fdt_getprop((void*)dtb, nodeoffset, "riscv,max-priority", &len);
  if(!val || len < sizeof(fdt32_t)) {
    kputs("\r\nThere is no riscv,max-priority in '/soc/interrupt-controller'\r\nAborting...");
    while(1);
  }
  if (len > sizeof(fdt32_t)) val++;
  plic_max_priority = fdt32_to_cpu(*val);

  // Disable the machine & timer interrupts until setup is done.
  clear_csr(mstatus, MSTATUS_MIE);
  clear_csr(mie, MIP_MEIP);
  clear_csr(mie, MIP_MTIP);
  
  if(plic_reg != 0) {
    PLIC_init(&g_plic,
              plic_reg,
              plic_ndevs,
              plic_max_priority);
  }
  // Display some information
#define DEQ(mon, x) ((cdate[0] == mon[0] && cdate[1] == mon[1] && cdate[2] == mon[2]) ? x : 0)
  const char *cdate = __DATE__;
  int month =
    DEQ("Jan", 1) | DEQ("Feb",  2) | DEQ("Mar",  3) | DEQ("Apr",  4) |
    DEQ("May", 5) | DEQ("Jun",  6) | DEQ("Jul",  7) | DEQ("Aug",  8) |
    DEQ("Sep", 9) | DEQ("Oct", 10) | DEQ("Nov", 11) | DEQ("Dec", 12);

  char date[11] = "YYYY-MM-DD";
  date[0] = cdate[7];
  date[1] = cdate[8];
  date[2] = cdate[9];
  date[3] = cdate[10];
  date[5] = '0' + (month/10);
  date[6] = '0' + (month%10);
  date[8] = cdate[4];
  date[9] = cdate[5];

  // Post the serial number and build info
  extern const char * gitid;

  kputs("\r\nRATONA Demo:       ");
  kputs(date);
  kputs("-");
  kputs(__TIME__);
  kputs("-");
  kputs(gitid);
  kputs("\r\nGot TL_CLK: ");
  uart_put_dec((void*)uart_reg, tlclk_freq);
  kputs("\r\nGot NUM_CORES: ");
  uart_put_dec((void*)uart_reg, num_cores);

  // Copy the DTB
  dtb_target = ddr_end - 0x200000UL; // - 2MB
  err = fdt_open_into((void*)dtb, (void*)dtb_target, 0x100000UL); // - 1MB only for the DTB
  if (err < 0) {
    kputs(fdt_strerror(err));
    kputs("\r\n");
    boot_fail(-err, 4);
  }
  //memcpy((void*)dtb_target, (void*)dtb, fdt_size(dtb));
  
  // Put the choosen if non existent, and put the bootargs
  nodeoffset = fdt_find_or_add_subnode((void*)dtb_target, 0, "chosen");
  if (nodeoffset < 0) boot_fail(-nodeoffset, 2);
	
  const char* str = "console=hvc0 earlycon=sbi";
  err = fdt_setprop((void*)dtb_target, nodeoffset, "bootargs", str, strlen(str) + 1);
  if (err < 0) boot_fail(-err, 3);

  // Get the timebase-frequency for the cpu@0
  nodeoffset = fdt_path_offset((void*)dtb_target, "/cpus/cpu@0");
  if (nodeoffset < 0) {
    kputs("\r\nCannot find '/cpus/cpu@0'\r\nAborting...");
    while(1);
  }
  val = fdt_getprop((void*)dtb_target, nodeoffset, "timebase-frequency", &len);
  if(!val || len < sizeof(fdt32_t)) {
    kputs("\r\nThere is no timebase-frequency in '/cpus/cpu@0'\r\nAborting...");
    while(1);
  }
  if (len > sizeof(fdt32_t)) val++;
  timescale_freq = fdt32_to_cpu(*val);
  kputs("\r\nGot TIMEBASE: ");
  uart_put_dec((void*)uart_reg, timescale_freq);
	
	// Put the timebase-frequency for the cpus
  nodeoffset = fdt_subnode_offset((void*)dtb_target, 0, "cpus");
	if (nodeoffset < 0) {
	  kputs("\r\nCannot find 'cpus'\r\nAborting...");
    while(1);
	}
	err = fdt_setprop_u32((void*)dtb_target, nodeoffset, "timebase-frequency", 1000000);
	if (err < 0) {
	  kputs("\r\nCannot set 'timebase-frequency' in 'timebase-frequency'\r\nAborting...");
    while(1);
	}

	// AES
  nodeoffset = fdt_node_offset_by_compatible((void*)dtb_target, 0, "uec,aes3-0");
	if (nodeoffset < 0) {
	  kputs("\r\nCannot find 'uec,aes3-0'\r\nAborting...");
    while(1);
	}
	err = fdt_get_node_addr_size((void*)dtb_target, nodeoffset, &aes_reg, NULL);
	if (err < 0) {
	  kputs("\r\nCannot get reg space from compatible 'uec,aes3-0'\r\nAborting...");
    while(1);
	}
  // SHA3
  nodeoffset = fdt_node_offset_by_compatible((void*)dtb_target, 0, "uec,sha3-0");
	if (nodeoffset < 0) {
	  kputs("\r\nCannot find 'uec,sha3-0'\r\nAborting...");
    while(1);
	}
	err = fdt_get_node_addr_size((void*)dtb_target, nodeoffset, &sha3_reg, NULL);
	if (err < 0) {
	  kputs("\r\nCannot get reg space from compatible 'uec,sha3-0''\r\nAborting...");
    while(1);
	}
  // RSA
  nodeoffset = fdt_node_offset_by_compatible((void*)dtb_target, 0, "uec,rsa-0");
	if (nodeoffset < 0) {
	  kputs("\r\nCannot find 'uec,rsa-0'\r\nAborting...");
    while(1);
	}
	err = fdt_get_node_addr_size((void*)dtb_target, nodeoffset, &rsa_reg, NULL);
	if (err < 0) {
	  kputs("\r\nCannot get reg space from compatible 'uec,rsa-0''\r\nAborting...");
    while(1);
	}

	// Pack the FDT and place the data after it
	fdt_pack((void*)dtb_target);


  // TODO: From this point, insert any code
  kputs("\r\n\n\nWelcome! Hello world!\r\n\n");
  //hwaes_test((void*)aes_reg);
  //kputs("\r\n\n\n");
  //hwsha3_test((void*)sha3_reg);
  //kputs("\r\n\n\n");
  //rsa_test((void*)rsa_reg);
  kputs("\r\nEnd!\r\n");
  // If finished, stay in a infinite loop
  while(1);

  //dead code
  return 0;
}

