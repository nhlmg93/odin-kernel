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

idt_set_gate :: proc "contextless" (vector: u8, handler: rawptr) {
	address := u64(uintptr(handler))

	idt[vector] = {
		offset_low      = u16(address & 0xffff),
		selector        = 0x08,
		ist             = 0,
		type_attributes = 0x8e,
		offset_middle   = u16((address >> 16) & 0xffff),
		offset_high     = u32(address >> 32),
		reserved        = 0,
	}
}

idt_init :: proc "contextless" () {
	idt_set_gate(3, rawptr(x86_int3_stub))
	idt_set_gate(6, rawptr(x86_ud2_stub))

	pointer := IDT_Pointer {
		limit = u16(size_of(idt) - 1),
		base  = u64(uintptr(&idt[0])),
	}

	x86_load_idt(&pointer)
}

@(export)
breakpoint_handler :: proc "c" (rip: u64) {
	uart_write_string("INT3 RIP: ")
	uart_write_hex64(rip)
	uart_write_string("\r\n")
}

@(export)
invalid_opcode_handler :: proc "c" (rip: u64) {
	uart_write_string("UD2 RIP: ")
	uart_write_hex64(rip)
	uart_write_string("\r\n")
	x86_halt()
}

#assert(size_of(IDT_Entry) == 16)
#assert(size_of(IDT_Pointer) == 10)
#assert(size_of(idt) == 4096)
