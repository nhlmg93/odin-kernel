package main

foreign import io "build/io.o"

foreign io {
	x86_out8 :: proc "c" (port: u16, value: u8) ---
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
	x86_trigger_page_fault :: proc "c" () ---
	x86_page_fault_stub :: proc "c" () ---
	x86_load_tss :: proc "c" (selector: u16) ---
	x86_read_tr  :: proc "c" () -> u16 ---
}

