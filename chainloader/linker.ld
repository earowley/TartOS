ENTRY(resetVector)

SECTIONS
{
	. = 0x70000;
	__chainloader_start = .;

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

	. = ALIGN(8);
	__chainloader_size = . - __chainloader_start;
}
