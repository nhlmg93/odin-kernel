package main

GDT_Pointer :: struct #packed {
	limit: u16,
	base:  u64,
}

gdt: [5]u64 = {
	0x0000000000000000, // Required null descriptor
	0x00af9a000000ffff, // Ring-0 64-bit code
	0x00cf92000000ffff, // Ring-0 data
	0, // TSS descriptor low
	0, // TSS descriptor high
}

gdt_init :: proc "contextless" () {
	tss_prepare()

	pointer := GDT_Pointer {
		limit = u16(size_of(gdt) - 1),
		base  = u64(uintptr(&gdt[0])),
	}

	x86_load_gdt(&pointer)

	x86_load_tss(TSS_SELECTOR)

	uart_write_string("TR: ")
	uart_write_hex64(u64(x86_read_tr()))
	uart_write_string("\r\n")
}

#assert(size_of(GDT_Pointer) == 10)
#assert(size_of(gdt) == 40)

