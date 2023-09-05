BOOTROM_DIR?=$(abspath .)

ISACONF?=RV32IMAC
CROSSCOMPILE?=riscv64-unknown-elf
CC=$(CROSSCOMPILE)-gcc
CCX=$(CROSSCOMPILE)-g++
OBJCOPY=$(CROSSCOMPILE)-objcopy
OBJDUMP=$(CROSSCOMPILE)-objdump
ifeq ($(ISACONF),RV64GC)
CFLAGS_ARCH=-march=rv64imafdc -mabi=lp64d
else ifeq ($(ISACONF),RV64IMAC)
CFLAGS_ARCH=-march=rv64imac -mabi=lp64
else ifeq ($(ISACONF),RV32GC)
CFLAGS_ARCH=-march=rv32imafdc -mabi=ilp32d
else #RV32IMAC
CFLAGS_ARCH=-march=rv32imac -mabi=ilp32
endif

CFLAGS=$(CFLAGS_ARCH) -mcmodel=medany -O1 -std=gnu11 -Wall -nostartfiles 
CFLAGS+= -fno-common -g -DENTROPY=0 -DNONSMP_HART=0 
CFLAGS+= -I $(BOOTROM_DIR)/include -I. -I./src -I./kprintf -I./lib -I./clkutils -I./libfdt $(ADD_OPTS)
LFLAGS=-static -L $(BOOTROM_DIR)/linker -T memory.lds -T link.lds
FSBL_TARGET_ADDR?=0x80000000UL
FSBL_SOURCE_ADDR?=0x82000000
BUILD_DIR?=$(abspath ./build)

LIB_FS_O= \
	src/start.o \
	src/main.o \
	uart/uart.o \
	$(BUILD_DIR)/version.o \
	clkutils/clkutils.o \
	kprintf/kprintf.o \
	plic/plic_driver.o \
	i2c/driver.o \
	lib/memcpy.o \
	lib/memset.o \
	lib/strcmp.o \
	lib/strncmp.o \
	lib/strlen.o \
	lib/memchr.o \
	lib/memmove.o \
	lib/memcmp.o \
	lib/strrchr.o \
	lib/strnlen.o \
  lib/sha3/sha3.o \
	lib/hwsha3/hwsha3_code.o \
	lib/aes/aes.o \
	libfdt/fdt.o libfdt/fdt_ro.o libfdt/fdt_wip.o libfdt/fdt_sw.o libfdt/fdt_rw.o libfdt/fdt_strerror.o libfdt/fdt_empty_tree.o \
	libfdt/fdt_addresses.o libfdt/fdt_check.o

$(BUILD_DIR)/version.c:
	mkdir -p $(BUILD_DIR)
	echo "const char *gitid = \"$(shell git describe --always --dirty)\";" > $(BUILD_DIR)/version.c
	echo "const char *gitdate = \"$(shell git log -n 1 --date=short --format=format:"%ad.%h" HEAD)\";" >> $(BUILD_DIR)/version.c
	echo "const char *gitversion = \"$(shell git rev-parse HEAD)\";" >> $(BUILD_DIR)/version.c

%.o: %.S
	$(CC) $(CFLAGS) -DFSBL_TARGET_ADDR=$(FSBL_TARGET_ADDR) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -DFSBL_TARGET_ADDR=$(FSBL_TARGET_ADDR) -c $< -o $@

%.o: %.cpp
	$(CCX) $(CFLAGS) -DFSBL_TARGET_ADDR=$(FSBL_TARGET_ADDR) -c $< -o $@

elf := $(BUILD_DIR)/out.elf
$(elf): $(LIB_FS_O)
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LFLAGS) -o $@ $(LIB_FS_O) -lgcc -lm -lgcc -lc

.PHONY: elf
elf: $(elf)

bin := $(BUILD_DIR)/out.bin
$(bin): $(elf)
	$(OBJCOPY) -O binary $< $@
	$(OBJDUMP) -d $^ > $@.dump

.PHONY: bin
bin: $(bin)

hex := $(BUILD_DIR)/out.hex
$(hex): $(bin)
	od -t x4 -An -w4 -v $< > $@

.PHONY: hex
hex: $(hex)

.PHONY: clean
clean::
	rm -rf $(hex) $(elf) $(LIB_FS_O) build
