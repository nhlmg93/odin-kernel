package main

foreign import io "build/io.o"

foreign io {
	x86_out8 :: proc "c" (port: u16, value: u8) ---
	x86_out32 :: proc "c" (port: u16, value: u32) ---
	x86_in8 :: proc "c" (port: u16) -> u8 ---
	x86_halt :: proc "c" () ---
	x86_read_cs :: proc "c" () -> u16 ---
	x86_read_ss :: proc "c" () -> u16 ---
	x86_load_gdt :: proc "c" (pointer: ^GDT_Pointer) ---
	x86_load_idt :: proc "c" (pointer: ^IDT_Pointer) ---
	x86_trigger_int3 :: proc "c" () ---
	x86_int3_stub :: proc "c" () ---
	x86_trigger_ud2 :: proc "c" () ---
	x86_ud2_stub :: proc "c" () ---
	x86_read_cr2 :: proc "c" () -> u64 ---
	x86_read_cr4 :: proc "c" () -> u64 ---
	x86_trigger_page_fault :: proc "c" () ---
	x86_page_fault_stub :: proc "c" () ---
	x86_double_fault_stub :: proc "c" () ---
	x86_load_tss :: proc "c" (selector: u16) ---
	x86_read_tr :: proc "c" () -> u16 ---
}

x86_virtual_address_is_canonical :: proc "contextless" (
	address: u64,
	virtual_address_width: u8,
) -> bool {
	if virtual_address_width != 48 && virtual_address_width != 57 {
		return false
	}

	lower_max := (u64(1) << (virtual_address_width - 1)) - 1
	upper_min := max(u64) - lower_max
	return address <= lower_max || address >= upper_min
}

x86_virtual_address_width :: proc "contextless" () -> u8 {
	X86_CR4_LA57 :: u64(1 << 12)
	if x86_read_cr4() & X86_CR4_LA57 != 0 {
		return 57
	}
	return 48
}
