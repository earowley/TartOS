ENTRY(resetVector)

SECTIONS
{
	. = 0x80000;
	__kernel_start = .;

	.text : {
		*(.text)
	}

	.rodata : {
		*(.rodata)
		*(.rodata.*)
	}

	.data : {
		*(.data)
	}

	.bss (NOLOAD) : ALIGN(16) {
		*(.bss)
		*(COMMON)
	}

	. = ALIGN(4096);
	__kernel_end = .;
	__kernel_size = __kernel_end - __kernel_start;
}
