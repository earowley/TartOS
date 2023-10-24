ENTRY(resetVector)

SECTIONS
{
	. = 0x80000;

	.text : {
		*(.text)
		*(.rodata)
	}

	.data : {
		*(.data)
	}

	.bss (NOLOAD) : ALIGN(16) {
		__bss_start = .;
		*(.bss)
		*(COMMON)
		. = ALIGN(8);
		__bss_end = .;
	}
}
