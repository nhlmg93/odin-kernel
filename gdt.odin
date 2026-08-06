package main

GDT_Pointer :: struct #packed {
	limit: u16,
	base:  u64,
}

gdt: [3]u64 = {
	0x0000000000000000, // Required null descriptor
	0x00af9a000000ffff, // Ring-0 64-bit code
	0x00cf92000000ffff, // Ring-0 data
}

gdt_init :: proc "contextless" () {
	pointer := GDT_Pointer {
		limit = u16(size_of(gdt) - 1),
		base  = u64(uintptr(&gdt[0])),
	}

	x86_load_gdt(&pointer)
}

#assert(size_of(GDT_Pointer) == 10)
#assert(size_of(gdt) == 24)
