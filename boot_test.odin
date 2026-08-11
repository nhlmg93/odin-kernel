package main

KERNEL_BOOT_TEST :: #config(KERNEL_BOOT_TEST, false)

kernel_boot_test_run :: proc() {
	value := new(u64)
	if value == nil {
		kernel_panic("boot test allocation failed")
	}

	expected := u64(0xa5a5_5a5a_dead_beef)
	value^ = expected
	if value^ != expected {
		kernel_panic("boot test allocation read failed")
	}

	uart_write_string("BOOT TEST PASSED\r\n")
	x86_out32(0xf4, 0x10)
	x86_halt()
}
