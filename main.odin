package main

foreign import io "build/io.o"

foreign io {
	x86_out8 :: proc "c" (port: u16, value: u8) ---
	x86_in8 :: proc "c" (port: u16) -> u8 ---
}

COM1 :: u16(0x3f8)

uart_init :: proc "contextless" () -> bool {
	x86_out8(COM1 + 1, 0x00) // Disable UART interrupts
	x86_out8(COM1 + 3, 0x80) // Enable divisor latch
	x86_out8(COM1 + 0, 0x01) // Divisor low: 115200 baud
	x86_out8(COM1 + 1, 0x00) // Divisor high
	x86_out8(COM1 + 3, 0x03) // 8 data bits, no parity, one stop bit
	x86_out8(COM1 + 2, 0xc7) // Enable and clear FIFOs

	// Test the UART in loopback mode.
	x86_out8(COM1 + 4, 0x1e)
	x86_out8(COM1 + 0, 0xae)
	if x86_in8(COM1 + 0) != 0xae {
		return false
	}

	x86_out8(COM1 + 4, 0x0f) // Leave loopback mode
	return true
}

uart_write_byte :: proc "contextless" (value: u8) {
	for x86_in8(COM1 + 5) & 0x20 == 0 {}
	x86_out8(COM1, value)
}

@(export)
kernel_main :: proc "c" () {
	if uart_init() {
		uart_write_byte('K')
	}

	for {}
}

