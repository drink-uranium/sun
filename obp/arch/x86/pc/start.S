/*
 * ========== Copyright Header Begin ==========================================
 *
 * OpenBoot x86 port: boot stub for PC-compatible systems
 *
 * Copyright 2026 The OpenBoot x86 port contributors
 * Use is subject to license terms (see any OpenBoot source file).
 *
 * ========== Copyright Header End ============================================
 *
 * start.S -- entry point of the OpenBoot firmware image on PCs.
 *
 * The firmware image is an ELF32 file with two parts: this stub, linked at
 * STUB_BASE, and the saved OpenBoot dictionary image, linked at its origin.
 * The same file can be started by:
 *
 *  - coreboot, as a payload (cbfstool add-payload -f openboot.elf).
 *    coreboot enters the payload in 32-bit flat protected mode.
 *  - any Multiboot loader (GRUB, "qemu -kernel openboot.elf"), which also
 *    enters in 32-bit flat protected mode with %eax = 0x2badb002 and %ebx
 *    pointing to the Multiboot information structure.
 *
 * The stub loads its own GDT and IDT, records how it was started in the
 * boot-info block at STUB_BASE+0x100 (where Forth finds it), and calls the
 * dictionary's cold-code entry point, the same entry point that the Unix
 * wrapper program uses:
 *
 *	cold_code(origin, functions, mem_end, argc, argv)
 *
 * with functions = 0, meaning that there is no operating system.
 *
 * Processor exceptions are vectored to the exception entry in the
 * boot-info block if Forth has installed one there; otherwise the stub
 * reports the exception on COM1 and halts.
 */

#define MULTIBOOT_MAGIC		0x1badb002
#define MULTIBOOT_FLAGS		0x00000003	/* page-align, memory info */

#define COM1			0x3f8

	.section .text.stub, "awx"
	.code32
	.globl	_start
	.globl	stub_base

stub_base:
multiboot_header:
	.long	MULTIBOOT_MAGIC
	.long	MULTIBOOT_FLAGS
	.long	-(MULTIBOOT_MAGIC + MULTIBOOT_FLAGS)

	.org	0x10
_start:
	cli
	cld
	movl	%eax, boot_magic
	movl	%ebx, boot_info

	lgdt	gdt_desc
	ljmp	$0x08, $1f
1:	movw	$0x10, %ax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %fs
	movw	%ax, %gs
	movw	%ax, %ss
	movl	$stub_stack_top, %esp

	call	setup_idt
	lidt	idt_desc

	/* Turn off the FPU emulation bit and enable the FPU */
	movl	%cr0, %eax
	andl	$~0x0c, %eax		/* Clear EM and TS */
	orl	$0x22, %eax		/* Set MP and NE */
	movl	%eax, %cr0
	fninit

	/* Enter Forth */
	pushl	$0			/* argv */
	pushl	$0			/* argc */
	pushl	mem_end			/* mem_end */
	pushl	$0			/* functions: none */
	pushl	$DICT_ORIGIN		/* header (the origin) */
	movl	DICT_ORIGIN + 0x0c, %eax /* cold-code entry from the header */
	call	*%eax

	/* cold-code never returns */
2:	hlt
	jmp	2b

/*
 * The boot-info block.  Forth reads and writes it at STUB_BASE+0x100;
 * keep the layout in sync with arch/x86/pc/bootinfo.fth.
 */
	.org	0x100
boot_info_block:
boot_magic:	.long	0		/* +00 %eax at entry */
boot_info:	.long	0		/* +04 %ebx at entry */
mem_end:	.long	MEM_END		/* +08 top of Forth's initial memory */
exc_entry:	.long	0		/* +0c Forth exception handler, or 0 */
exc_state:	.long	exc_save	/* +10 register save area */
idt_base:	.long	idt		/* +14 the IDT */
stub_end:	.long	stub_end_mark	/* +18 end of the stub */
		.long	0		/* +1c reserved */

/*
 * Exception entry points.  Each pushes a dummy error code if the
 * processor doesn't, then the vector number.
 */
#define EXC_NOERR(n)	.p2align 3; exc_##n: pushl $0; pushl $n; jmp exc_common
#define EXC_ERR(n)	.p2align 3; exc_##n: pushl $n; jmp exc_common

	.p2align 4
exc_stubs:
	EXC_NOERR(0);  EXC_NOERR(1);  EXC_NOERR(2);  EXC_NOERR(3)
	EXC_NOERR(4);  EXC_NOERR(5);  EXC_NOERR(6);  EXC_NOERR(7)
	EXC_ERR(8);    EXC_NOERR(9);  EXC_ERR(10);   EXC_ERR(11)
	EXC_ERR(12);   EXC_ERR(13);   EXC_ERR(14);   EXC_NOERR(15)
	EXC_NOERR(16); EXC_ERR(17);   EXC_NOERR(18); EXC_NOERR(19)

/*
 * Common exception code.  The save area layout matches cpu/x86/register.fth:
 *   edi esi ebp esp ebx edx ecx eax  ds es fs gs ss cr2
 *   vector error-code eip cs eflags
 */
exc_common:
	pushal				/* eax ecx edx ebx esp ebp esi edi */
	movl	%esp, %ebp
	movl	exc_state, %edi
	movl	%ebp, %esi
	movl	$8, %ecx
	rep movsl			/* The general registers */
	addl	$20, 12-32(%edi)	/* %esp before the exception: skip the */
					/* vector, error code, eip, cs, eflags */
	movw	%ds, %ax
	movzwl	%ax, %eax
	stosl
	movw	%es, %ax
	stosl
	movw	%fs, %ax
	stosl
	movw	%gs, %ax
	stosl
	movw	%ss, %ax
	stosl
	movl	%cr2, %eax
	stosl
	movl	32(%ebp), %eax		/* vector */
	stosl
	movl	36(%ebp), %eax		/* error code */
	stosl
	movl	40(%ebp), %eax		/* eip */
	stosl
	movl	44(%ebp), %eax		/* cs */
	stosl
	movl	48(%ebp), %eax		/* eflags */
	stosl

	movl	exc_entry, %eax
	testl	%eax, %eax
	jz	report
	cld
	jmp	*%eax			/* Forth takes over; it doesn't return */

/* No Forth handler: report the exception on COM1 and halt */
report:
	movl	$msg_exc, %esi
	call	puts
	movl	32(%ebp), %eax
	call	puthex
	movl	$msg_eip, %esi
	call	puts
	movl	40(%ebp), %eax
	call	puthex
	movl	$msg_err, %esi
	call	puts
	movl	36(%ebp), %eax
	call	puthex
	movl	$msg_cr2, %esi
	call	puts
	movl	%cr2, %eax
	call	puthex
	movl	$msg_nl, %esi
	call	puts
3:	cli
	hlt
	jmp	3b

putc:					/* %al */
	pushl	%edx
	pushl	%eax
	movw	$COM1 + 5, %dx
4:	inb	%dx, %al
	testb	$0x20, %al
	jz	4b
	popl	%eax
	movw	$COM1, %dx
	outb	%al, %dx
	popl	%edx
	ret

puts:					/* %esi */
	lodsb
	testb	%al, %al
	jz	5f
	call	putc
	jmp	puts
5:	ret

puthex:					/* %eax */
	movl	$8, %ecx
	movl	%eax, %edx
6:	roll	$4, %edx
	movl	%edx, %eax
	andl	$0x0f, %eax
	movb	hexdigits(%eax), %al
	call	putc
	loop	6b
	ret

/* Fill the IDT with interrupt gates for the exception stubs */
setup_idt:
	movl	$idt, %edi
	movl	$exc_stubs, %ebx
	xorl	%ecx, %ecx
7:	movl	%ebx, %eax
	movw	%ax, (%edi)		/* offset 15:0 */
	movw	$0x08, 2(%edi)		/* selector */
	movw	$0x8e00, 4(%edi)	/* present, ring 0, 32-bit interrupt gate */
	shrl	$16, %eax
	movw	%ax, 6(%edi)		/* offset 31:16 */
	addl	$8, %edi
	addl	$8, %ebx
	incl	%ecx
	cmpl	$20, %ecx
	jne	7b
	ret

msg_exc:	.asciz	"\r\nOpenBoot: unexpected exception "
msg_eip:	.asciz	" at "
msg_err:	.asciz	" error "
msg_cr2:	.asciz	" cr2 "
msg_nl:		.asciz	"\r\n"
hexdigits:	.ascii	"0123456789abcdef"

	.p2align 3
gdt:
	.quad	0x0000000000000000	/* null */
	.quad	0x00cf9a000000ffff	/* 0x08: code, flat 4GB */
	.quad	0x00cf92000000ffff	/* 0x10: data, flat 4GB */
	.quad	0x00009a000000ffff	/* 0x18: 16-bit code, 64KB */
	.quad	0x000092000000ffff	/* 0x20: 16-bit data, 64KB */
gdt_end:
gdt_desc:
	.word	gdt_end - gdt - 1
	.long	gdt

	.p2align 3
idt_desc:
	.word	256 * 8 - 1
	.long	idt

	.section .bss.stub, "aw", @nobits
	.p2align 4
idt:	.space	256 * 8
exc_save:
	.space	32 * 4
	.p2align 4
	.space	16384
stub_stack_top:
stub_end_mark:
