# OpenBoot for x86 PCs

This directory holds the port of Sun's OpenBoot 4.x firmware to 32-bit
x86 PC-compatible machines.  It is the same firmware as the SPARC
releases: the Forth kernel is metacompiled from `fm/kernel`, the Open
Firmware core (`os/bootprom`, `pkg/*`) is shared, onboard devices get
FCode drivers that are tokenized at build time and byte-loaded during
probing, and the user interface is the familiar `ok` prompt.

The firmware image runs as a **coreboot payload** or from any
**Multiboot** loader (GRUB, `qemu -kernel`), and boots Open Firmware
client programs and Multiboot kernels.

## Building

Requirements: `python3`, `gcc` and binutils that can produce i386 code
(`gcc -m32`), `make`, and a Linux kernel that can run i386 programs (the
build runs the Forth tools as a 32-bit Linux process).  QEMU
(`qemu-system-i386`) is needed only for `make run` and `make test`.

    cd arch/x86/pc
    make            # build/openboot.elf
    make run        # boot it in QEMU, console on stdio
    make test       # QEMU smoke test (test/smoke.sh)

The build follows the SPARC build:

1. `fm/meta/x86/meta86.py`, a stage-0 metacompiler, translates the kernel
   sources (`fm/kernel/x86/loadkern.fth`; the CPU-specific code words are in
   `fm/kernel/x86/kerncode.fth`) into GNU assembler, which is assembled
   into `kernel.dic`.
2. The wrapper program `os/unix/x86/wrapper.c` runs `kernel.dic` under
   Linux.  It loads the tools (`fm/lib`), the Open Firmware core and the PC
   platform code (`arch/x86/pc/loadprom.fth`) and saves `openboot.dic`.
   The same wrapper also builds `forth.dic` (`make forth`, the hosted
   development Forth) and the FCode tokenizer (`pkg/tokenizr`).
3. The FCode drivers in `dev/pc` are tokenized and embedded in the
   firmware (`arch/x86/pc/dropins.fth`).
4. `openboot.dic` is linked with the boot stub `start.S` into
   `openboot.elf`.

## Running

**QEMU:** `qemu-system-i386 -m 128 -nographic -kernel build/openboot.elf`
(this is `make run`).  Add `-drive file=disk.img,format=raw,if=ide` for a
disk or `-initrd program.elf` for a ramdisk.

**coreboot:** add the image as the payload, e.g.

    cbfstool coreboot.rom add-payload -f build/openboot.elf -n fallback/payload

or select "An ELF executable payload" in coreboot's `make menuconfig` and
point it at `openboot.elf`.  OpenBoot finds the memory map in the coreboot
tables.

**GRUB:** `multiboot /boot/openboot.elf` and `boot`.

At least 64MB of RAM is needed.  The console is COM1 at 115200 baud
(`ttya`); `setenv output-device screen` and `setenv input-device keyboard`
select the VGA text display and the PS/2 keyboard.

## The machine

The firmware runs in 32-bit protected mode with flat segments and paging
disabled, so virtual addresses equal physical addresses.

| Range                     | Use                                         |
|---------------------------|---------------------------------------------|
| `00ff0000` - `00ffffff`   | NVRAM image (configuration variables)       |
| `01000000` -              | boot stub, GDT, IDT, stub stack             |
| `01100000` - `01cfffff`   | Forth dictionary, stacks, user area         |
| `01d00000` - `02cfffff`   | heap (`alloc-mem`)                          |
| `03000000` -              | `load-base`: where boot programs are loaded |

The rest of memory is available to client programs (see `/memory`
`available`; the client interface `claim` service allocates from it).

Device tree, as probed on QEMU's i440FX machine:

    /cpus/cpu@0                 CPUID vendor, brand, TSC frequency
    /memory@0                   from coreboot tables, Multiboot or CMOS
    /pci                        PCI host bridge (dev/pc/pci)
    /pci/host@0
    /pci/isa@1                  PCI-to-ISA bridge (dev/pc/isa)
    /pci/isa@1/serial@i3f8      16550 UART (dev/pc/serial)
    /pci/isa@1/keyboard@i60     PS/2 keyboard (dev/pc/keyboard)
    /pci/ide@1,1                IDE controller (dev/ide, dev/pc/ide)
    /pci/ide@1,1/disk           ATA disks
    /pci/ide@1,1/cdrom          ATAPI drives
    /pci/display@2              VGA in text mode (dev/pc/vga)
    /pci/ethernet@3             (no driver; generic node)
    /ramdisk                    the first Multiboot module
    /nvram, /options, /aliases, /chosen, /openprom, /packages

The PCI probe is OpenBoot's generic one (`dev/pci`).  It keeps the
addresses that coreboot or the BIOS assigned to enabled devices; the host
bridge driver (`dev/pc/pci/resources.fth`) works out which part of the PCI
window is free for anything still unassigned.  A PCI device with an FCode
expansion ROM gets its driver from the ROM; chipset devices get theirs
from the `SUNW,builtin-drivers` package, by class code
(`arch/x86/pc/probe.fth`).  Device register access words (`rb@`, `rl!`,
...) do port I/O for addresses below 64K (`cpu/x86/regwords.fth`), so
drivers work with registers in either the memory or the I/O space.

Aliases: `ttya`, `ttyb`, `screen`, `keyboard`, `disk` (= `disk0`),
`disk1`-`disk3`, `cdrom`, `ramdisk`.

## Booting

`boot [device[:partition]] [arguments]`, default `boot-device` is
`disk net`.

* **Disks** use PC partition tables (`arch/x86/pc/disklabel.fth`):
  `disk:1` .. `disk:4` select a primary partition; without a partition the
  active one is used.  Sun VTOC labels (`disk:a`) work as on SPARC.  The
  boot program is an ELF executable stored in the partition as is, e.g.
  `dd if=kernel.elf of=/dev/sdX2`.
* **ramdisk** is the first Multiboot module (`qemu -initrd`, GRUB
  `module`).

A boot program is either

* an **Open Firmware client program** (ELF32), entered with `%eax` = the
  client interface handler, `int cif_handler(cell args[])` (C calling
  convention, big-endian property values as on all Open Firmware
  systems), and a 64K stack; or
* a **Multiboot kernel** (ELF32 with a Multiboot header), entered with
  `%eax` = `0x2badb002` and `%ebx` = a Multiboot information structure
  with the memory map, the boot arguments as command line and the boot
  loader name.

`test/clients` has an example of each.  `boot` after a program has run
resets the machine and boots with the new command ("Rebooting with
command: ..."), as on SPARC.

## Debugging support

Processor exceptions in the firmware or in a client program are reported
("Invalid Opcode at %eip ...") and return to the `ok` prompt with the
processor state saved: `.registers` shows it, and `ftrace` shows the
Forth return stack of the interrupted code.  A client program that calls
the client interface `enter` service is resumed with `go`.

## Limitations

* 32-bit only; memory above 4GB is not used.
* No network, USB, AHCI/NVMe or frame buffer graphics drivers.
* Configuration variables are kept in RAM and survive a warm reset
  (`reset-all`), not a power cycle; writing them to the boot flash is
  board-specific.
* No single-stepping or breakpoints (`fm/lib/*/cpubpsup.fth` has no x86
  version yet) and the disassembler is a stub.
* `power-off` is not implemented (it needs ACPI).
* One processor; the others are left halted.
