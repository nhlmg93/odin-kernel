package main

foreign import io "build/io.o"

foreign io {
	x86_out8 :: proc "c" (port: u16, value: u8) ---
	x86_in8 :: proc "c" (port: u16) -> u8 ---
	x86_halt :: proc "c" () ---
	x86_read_cs :: proc "c" () -> u16 ---
	x86_read_ss :: proc "c" () -> u16 ---
	x86_load_gdt :: proc "c" (pointer: ^GDT_Pointer) ---
}

kernel_panic :: proc "contextless" (message: string) {
	uart_write_string("PANIC: ")
	uart_write_string(message)
	uart_write_string("\r\n")
	x86_halt()
}

@(export)
kernel_main :: proc "c" () {
	if !uart_init() {
		kernel_panic("UART loopback failed")
	}
	gdt_init()
	uart_write_string("CS: ")
	uart_write_hex64(u64(x86_read_cs()))
	uart_write_string("\r\nSS: ")
	uart_write_hex64(u64(x86_read_ss()))
	uart_write_string("\r\n")
	x86_halt()
}
