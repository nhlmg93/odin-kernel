package main

IDT_Entry :: struct #packed {
	offset_low:      u16,
	selector:        u16,
	ist:             u8,
	type_attributes: u8,
	offset_middle:   u16,
	offset_high:     u32,
	reserved:        u32,
}

IDT_Pointer :: struct #packed {
	limit: u16,
	base:  u64,
}

idt: [256]IDT_Entry

#assert(size_of(IDT_Entry) == 16)
#assert(size_of(IDT_Pointer) == 10)
#assert(size_of(idt) == 4096)
