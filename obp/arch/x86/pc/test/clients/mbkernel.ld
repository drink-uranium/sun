ENTRY(_start)
SECTIONS
{
	. = 0x200000;
	.text : { KEEP(*(.multiboot)) *(.text*) *(.rodata*) }
	.data : { *(.data*) }
	.bss : { *(.bss*) *(COMMON) }
	/DISCARD/ : { *(.note*) *(.comment) *(.eh_frame) }
}
