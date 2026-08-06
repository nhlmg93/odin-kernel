package main

foreign import io "build/io.o"

foreign io {
	x86_out8 :: proc "c" (port: u16, value: u8) ---
	x86_in8 :: proc "c" (port: u16) -> u8 ---
	x86_halt :: proc "c" () ---
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
		kernel_panic("deliberate test")
	}
	uart_write_string("Kernel ready\r\n")
	x86_halt()
}
