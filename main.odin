package main

import "base:runtime"

kernel_panic :: proc "contextless" (message: string) {
	uart_write_string("PANIC: ")
	uart_write_string(message)
	uart_write_string("\r\n")
	x86_halt()
}

@(export)
kernel_main :: proc "c" () {
	context = runtime.default_context()

	if !uart_init() {
		kernel_panic("UART loopback failed")
	}

	gdt_init()
	idt_init()

	if !limine_base_revision_supported() {
		kernel_panic("unsupported Limine base revision")
	}

	if limine_hhdm_request.response == nil {
		kernel_panic("Limine did not provide HHDM")
	}

	hhdm_offset := limine_hhdm_request.response.offset
	if hhdm_offset % LIMINE_PAGE_SIZE != 0 {
		kernel_panic("Limine HHDM offset is not page-aligned")
	}

	memory_map := limine_memory_map_request.response
	validated_memory_map, validation_error, entry_index := memory_map_validate(memory_map)
	if validation_error != .None {
		uart_write_string("Memory map validation error: ")
		uart_write_hex64(u64(validation_error))
		uart_write_string(" entry=")
		uart_write_hex64(entry_index)
		uart_write_string("\r\n")
		kernel_panic("invalid memory map")
	}

	if !physical_page_allocator_init(&physical_page_allocator, validated_memory_map) {
		kernel_panic("no usable physical page range")
	}

	kernel_allocator_state = Kernel_Allocator_State {
		pages                 = &physical_page_allocator,
		hhdm_offset           = hhdm_offset,
		virtual_address_width = x86_virtual_address_width(),
	}
	context.allocator = runtime.Allocator {
		procedure = kernel_allocator_proc,
		data      = &kernel_allocator_state,
	}

	when KERNEL_BOOT_TEST {
		kernel_boot_test_run()
	}

	uart_write_string("Kernel initialized\r\n")
	x86_halt()
}
