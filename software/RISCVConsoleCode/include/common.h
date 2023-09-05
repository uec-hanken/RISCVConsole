#ifndef _FSBL_COMMON_H
#define _FSBL_COMMON_H

#define MAX_CORES 8

#ifndef FSBL_TARGET_ADDR
#define FSBL_TARGET_ADDR MEMORY_MEM_ADDR
#endif

#define PAYLOAD_DEST FSBL_TARGET_ADDR
#define PAYLOAD_SIZE	(26 << 11)

extern volatile unsigned long dtb_target;

#endif
