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

