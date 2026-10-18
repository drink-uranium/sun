/*
 * Linker script for the OpenBoot firmware image on PCs: the boot stub at
 * STUB_BASE and the saved dictionary image at its origin.
 */
OUTPUT_FORMAT("elf32-i386")
OUTPUT_ARCH(i386)
ENTRY(_start)

PHDRS
{
	stub PT_LOAD;
	dict PT_LOAD;
}

SECTIONS
{
	. = STUB_BASE;
	.stub : { *(.text.stub) } :stub
	.stub.bss (NOLOAD) : { *(.bss.stub) } :stub

	. = DICT_ORIGIN;
	.dict : { *(.dict) } :dict

	/DISCARD/ : { *(.note*) *(.comment) *(.eh_frame) }
}
