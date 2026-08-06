package main

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
	idt_init()

	uart_write_string("Triggering INT3\r\n")
	x86_trigger_int3()
	uart_write_string("Returned from INT3\r\n")
	uart_write_string("Triggering UD2\r\n")
	x86_trigger_ud2()
	kernel_panic("UD2 returned unexpectedly")

	uart_write_string("CS: ")
	uart_write_hex64(u64(x86_read_cs()))
	uart_write_string("\r\nSS: ")
	uart_write_hex64(u64(x86_read_ss()))
	uart_write_string("\r\n")
	x86_halt()
}
