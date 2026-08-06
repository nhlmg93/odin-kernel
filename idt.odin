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

idt_set_gate :: proc "contextless" (vector: u8, handler: rawptr, ist_index: u8) {
	address := u64(uintptr(handler))

	idt[vector] = {
		offset_low      = u16(address & 0xffff),
		selector        = 0x08,
		ist             = ist_index & 0x7,
		type_attributes = 0x8e,
		offset_middle   = u16((address >> 16) & 0xffff),
		offset_high     = u32(address >> 32),
		reserved        = 0,
	}
}

idt_init :: proc "contextless" () {
	idt_set_gate(3, rawptr(x86_int3_stub), 0)
	idt_set_gate(6, rawptr(x86_ud2_stub), 0)
	idt_set_gate(8, rawptr(x86_double_fault_stub), 1)
	idt_set_gate(14, rawptr(x86_page_fault_stub), 0)

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

Exception_Frame :: struct #packed {
	r15:        u64,
	r14:        u64,
	r13:        u64,
	r12:        u64,
	r11:        u64,
	r10:        u64,
	r9:         u64,
	r8:         u64,
	rdi:        u64,
	rsi:        u64,
	rbp:        u64,
	rdx:        u64,
	rcx:        u64,
	rbx:        u64,
	rax:        u64,
	vector:     u64,
	error_code: u64,
	rip:        u64,
	cs:         u64,
	rflags:     u64,
}

@(export)
exception_handler :: proc "c" (frame: ^Exception_Frame) {
	uart_write_string("EXCEPTION vector: ")
	uart_write_hex64(frame.vector)
	uart_write_string(" RIP: ")
	uart_write_hex64(frame.rip)
	uart_write_string(" error: ")
	uart_write_hex64(frame.error_code)

	if frame.vector == 14 {
		uart_write_string(" CR2: ")
		uart_write_hex64(x86_read_cr2())
		uart_write_string(" IST1: ")
		if tss_emergency_stack_contains(uintptr(frame)) {
			uart_write_string("yes")
		} else {
			uart_write_string("no")
		}
	}

	uart_write_string("\r\n")

	if frame.vector == 3 {
		return
	}

	x86_halt()
}

#assert(size_of(Exception_Frame) == 160)
