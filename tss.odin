package main

TSS :: struct #packed {
	reserved_0:  u32,
	rsp0:        u64,
	rsp1:        u64,
	rsp2:        u64,
	reserved_1:  u64,
	ist1:        u64,
	ist2:        u64,
	ist3:        u64,
	ist4:        u64,
	ist5:        u64,
	ist6:        u64,
	ist7:        u64,
	reserved_2:  u64,
	reserved_3:  u16,
	iopb_offset: u16,
}

Emergency_Stack :: struct #align (16) {
	bytes: [16 * 1024]u8,
}

tss: TSS
emergency_stack: Emergency_Stack

#assert(size_of(TSS) == 104)
#assert(align_of(Emergency_Stack) == 16)

TSS_SELECTOR :: u16(0x18)

tss_prepare :: proc "contextless" () {
	stack_top := uintptr(&emergency_stack.bytes[0]) + uintptr(len(emergency_stack.bytes))

	tss.ist1 = u64(stack_top)
	tss.iopb_offset = u16(size_of(TSS))

	base := u64(uintptr(&tss))
	limit := u64(size_of(TSS) - 1)

	gdt[3] =
		(limit & 0xffff) |
		((base & 0xffff) << 16) |
		(((base >> 16) & 0xff) << 32) |
		(u64(0x89) << 40) |
		(((limit >> 16) & 0xf) << 48) |
		(((base >> 24) & 0xff) << 56)

	gdt[4] = base >> 32
}

