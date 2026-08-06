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

	if !limine_base_revision_supported() {
		kernel_panic("unsupported Limine base revision")
	}

	if limine_hhdm_request.response == nil {
		kernel_panic("Limine did not provide HHDM")
	}

	uart_write_string("HHDM offset: ")
	uart_write_hex64(limine_hhdm_request.response.offset)
	uart_write_string("\r\n")

	memory_map := limine_memory_map_request.response
	if memory_map == nil {
		kernel_panic("Limine did not provide a memory map")
	}

	if memory_map.entry_count != 0 && memory_map.entries == nil {
		kernel_panic("Limine memory map has no entry array")
	}

	uart_write_string("Memory map entries: ")
	uart_write_hex64(memory_map.entry_count)
	uart_write_string("\r\n")

	gdt_init()
	idt_init()

	uart_write_string("Triggering INT3\r\n")
	x86_trigger_int3()
	uart_write_string("Returned from INT3\r\n")
	uart_write_string("Triggering page fault\r\n")
	x86_trigger_page_fault()
	kernel_panic("page fault returned unexpectedly")

	uart_write_string("CS: ")
	uart_write_hex64(u64(x86_read_cs()))
	uart_write_string("\r\nSS: ")
	uart_write_hex64(u64(x86_read_ss()))
	uart_write_string("\r\n")
	x86_halt()
}
