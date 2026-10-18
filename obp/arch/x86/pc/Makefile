# ========== Copyright Header Begin ==========================================
#
# OpenBoot x86 port: build for PC-compatible systems
#
# Copyright 2026 The OpenBoot x86 port contributors
# Use is subject to license terms (see any OpenBoot source file).
#
# ========== Copyright Header End ============================================
#
# GNU make build of OpenBoot for PC-compatible x86 machines.
#
#   make            build build/openboot.elf
#   make run        boot it in QEMU with the console on stdio (COM1)
#   make forth      build build/forth.dic, the hosted development Forth
#
# The build follows the same sequence as the SPARC build:
#
#   1. The kernel sources are metacompiled into kernel.dic (stage-0
#      metacompiler fm/meta/x86/meta86.py, then the GNU assembler).
#   2. The wrapper program (os/unix/x86/wrapper.c) runs kernel.dic as a
#      Linux process.  It loads arch/x86/preload.fth, which loads the
#      tools, the Open Firmware core and the PC platform support from
#      arch/x86/pc/loadprom.fth, and saves the result as openboot.dic.
#   3. openboot.dic is linked with the boot stub (start.S) into an ELF
#      image that can be booted as a coreboot payload or by any Multiboot
#      loader.
#
# Requirements: python3, gcc and binutils that can produce i386 code,
# and a Linux kernel that can run i386 programs.

BP	:= $(abspath ../../..)
B	:= build

CC	?= gcc
AS	:= as --32
LD	:= ld -m elf_i386
OBJCOPY	:= objcopy
PYTHON	?= python3
QEMU	?= qemu-system-i386

# Memory layout; see arch/x86/pc/heap.fth
STUB_BASE	:= 0x01000000
DICT_ORIGIN	:= 0x01100000
MEM_END		:= 0x01d00000

KERNEL_SRC := $(wildcard $(BP)/fm/kernel/*.fth $(BP)/fm/kernel/x86/*.fth) \
	$(BP)/fm/cwrapper/syskey.fth $(BP)/fm/cwrapper/sysdisk.fth \
	$(BP)/fm/cwrapper/x86/boot.fth $(BP)/os/unix/x86/sys.fth \
	$(BP)/fm/lib/cstrings.fth $(BP)/fm/lib/alias.fth $(BP)/fm/lib/xref.fth

WRAPPER_CFLAGS := -m32 -O2 -Wall -ffreestanding -fno-pic -no-pie \
	-fno-stack-protector -fno-builtin -nostdlib -static

FORTH	:= BP=$(BP) $(abspath $(B))/forth
KERNEL_FLAGS := -d kernel.dic -D kernel-hdr-file=kernel.fth

all: $(B)/openboot.elf

$(B):
	mkdir -p $(B)

# ---- 1. The kernel

$(B)/kernel.S $(B)/kernel.labels: $(KERNEL_SRC) $(BP)/fm/meta/x86/meta86.py | $(B)
	$(PYTHON) $(BP)/fm/meta/x86/meta86.py -D KERNEL -I $(BP) \
		-o $(B)/kernel.S -L $(B)/kernel.labels \
		$(BP)/fm/kernel/x86/loadkern.fth

$(B)/kernel.o: $(B)/kernel.S
	$(AS) -o $@ $<

$(B)/kernel.elf: $(B)/kernel.o Makefile
	$(LD) -N -Ttext=$(DICT_ORIGIN) -e cold_entry --no-warn-rwx-segments \
		-o $@ $<

$(B)/kernel.dic: $(B)/kernel.elf
	$(OBJCOPY) -O binary $< $@

$(B)/kernel.fth: $(B)/kernel.elf $(B)/kernel.labels
	$(PYTHON) $(BP)/fm/meta/x86/meta86.py --header-file \
		$(B)/kernel.labels $(B)/kernel.elf $@

# ---- 2. The wrapper and the firmware dictionary

$(B)/forth: $(BP)/os/unix/x86/wrapper.c | $(B)
	$(CC) $(WRAPPER_CFLAGS) -o $@ $<

$(B)/version.fth: | $(B)
	( echo "headerless" ; \
	  date '+td %M td %H bwjoin td %d td %m bwjoin wljoin td %Y' ; \
	  echo "2constant compile-signature" ; \
	  echo "create (sub-release ,\" x86\"" ; \
	  echo "create (obp-release ,\" 4.0.0\"" ; \
	  echo "' (sub-release is sub-release" ; \
	  echo "' (obp-release is obp-release" ; \
	  echo "headers" ) > $@

PROM_SRC = $(shell find $(BP)/arch/x86 $(BP)/os $(BP)/pkg $(BP)/dev \
	$(BP)/fm/lib $(BP)/cpu/x86 $(BP)/arch/sun -name '*.fth')

$(B)/openboot.dic: $(B)/forth $(B)/kernel.dic $(B)/kernel.fth \
		$(B)/version.fth $(PROM_SRC)
	cd $(B) && $(FORTH) $(KERNEL_FLAGS) \
		-D LOADFILE=$(BP)/arch/x86/pc/loadprom.fth \
		-D SAVEFILE=openboot.dic \
		$(BP)/arch/x86/preload.fth < /dev/null
	test -s $@

# ---- 3. The firmware image

$(B)/start.o: start.S Makefile | $(B)
	$(CC) -m32 -c -DDICT_ORIGIN=$(DICT_ORIGIN) -DMEM_END=$(MEM_END) \
		-o $@ $<

$(B)/dict.o: dict.S $(B)/openboot.dic
	$(CC) -m32 -c -DDICT_FILE='"$(abspath $(B))/openboot.dic"' -o $@ dict.S

$(B)/openboot.elf: $(B)/start.o $(B)/dict.o openboot.ld Makefile
	$(LD) -T openboot.ld --defsym STUB_BASE=$(STUB_BASE) \
		--defsym DICT_ORIGIN=$(DICT_ORIGIN) --no-warn-rwx-segments \
		-o $@ $(B)/start.o $(B)/dict.o

# ---- Hosted development Forth, like the SPARC "forth" tools dictionary

$(B)/forth.dic: $(B)/forth $(B)/kernel.dic $(B)/kernel.fth $(PROM_SRC)
	cd $(B) && $(FORTH) $(KERNEL_FLAGS) \
		-D LOADFILE=$(BP)/os/unix/x86/loadutil.fth \
		-D dic-file-name=forth.dic \
		$(BP)/arch/x86/preload.fth < /dev/null

forth: $(B)/forth.dic

# ---- Running

QEMU_FLAGS ?= -m 128 -nographic -no-reboot

run: $(B)/openboot.elf
	$(QEMU) $(QEMU_FLAGS) -kernel $(B)/openboot.elf

clean:
	rm -rf $(B)

.PHONY: all forth run clean
