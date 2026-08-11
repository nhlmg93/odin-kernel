#+build !freestanding

package main

import "base:runtime"
import "core:testing"

Allocator_Test_Buffer :: struct #align (4096) {
	bytes: [2 * 4096]byte,
}

allocator_test_buffer: Allocator_Test_Buffer

@(test)
physical_page_allocator_selects_first_usable_range :: proc(t: ^testing.T) {
	reserved := Memory_Map_Entry {
		base   = 0x1000,
		length = 4096,
		kind   = LIMINE_MEMORY_MAP_RESERVED,
	}
	reserved_entries := [1]^Memory_Map_Entry{&reserved}
	memory_map := Memory_Map_Response {
		entry_count = 1,
		entries     = &reserved_entries[0],
	}
	allocator := Physical_Page_Allocator {
		next_physical = 11,
		end_physical  = 22,
	}
	validated_memory_map, validation_error, validation_index := memory_map_validate(&memory_map)

	testing.expect_value(t, validation_error, Memory_Map_Validation_Error.None)
	testing.expect_value(t, validation_index, u64(0))
	testing.expect(t, !physical_page_allocator_init(&allocator, validated_memory_map))
	testing.expect_value(t, allocator.next_physical, u64(0))
	testing.expect_value(t, allocator.end_physical, u64(0))

	short := Memory_Map_Entry {
		base   = 0x2000,
		length = 0,
		kind   = LIMINE_MEMORY_MAP_USABLE,
	}
	first := Memory_Map_Entry {
		base   = 0x4000,
		length = 8192,
		kind   = LIMINE_MEMORY_MAP_USABLE,
	}
	second := Memory_Map_Entry {
		base   = 0x9000,
		length = 16384,
		kind   = LIMINE_MEMORY_MAP_USABLE,
	}
	entries := [4]^Memory_Map_Entry{&reserved, &short, &first, &second}
	memory_map = Memory_Map_Response {
		entry_count = 4,
		entries     = &entries[0],
	}
	validated_memory_map, validation_error, validation_index = memory_map_validate(&memory_map)

	testing.expect_value(t, validation_error, Memory_Map_Validation_Error.None)
	testing.expect_value(t, validation_index, u64(0))
	testing.expect(t, physical_page_allocator_init(&allocator, validated_memory_map))
	testing.expect_value(t, allocator.next_physical, first.base)
	testing.expect_value(t, allocator.end_physical, first.base + first.length)
}

@(test)
physical_page_allocator_advances_across_usable_ranges :: proc(t: ^testing.T) {
	first := Memory_Map_Entry {
		base   = 0x1000,
		length = LIMINE_PAGE_SIZE,
		kind   = LIMINE_MEMORY_MAP_USABLE,
	}
	reserved := Memory_Map_Entry {
		base   = 0x2000,
		length = LIMINE_PAGE_SIZE,
		kind   = LIMINE_MEMORY_MAP_RESERVED,
	}
	second := Memory_Map_Entry {
		base   = 0x3000,
		length = 2 * LIMINE_PAGE_SIZE,
		kind   = LIMINE_MEMORY_MAP_USABLE,
	}
	entries := [3]^Memory_Map_Entry{&first, &reserved, &second}
	memory_map := Memory_Map_Response {
		entry_count = 3,
		entries     = &entries[0],
	}
	validated_memory_map, validation_error, validation_index := memory_map_validate(&memory_map)
	allocator: Physical_Page_Allocator

	testing.expect_value(t, validation_error, Memory_Map_Validation_Error.None)
	testing.expect_value(t, validation_index, u64(0))
	testing.expect(t, physical_page_allocator_init(&allocator, validated_memory_map))

	first_page, first_ok := physical_page_allocate(&allocator)
	second_page, second_ok := physical_page_allocate(&allocator)
	third_page, third_ok := physical_page_allocate(&allocator)
	_, exhausted_ok := physical_page_allocate(&allocator)

	testing.expect(t, first_ok)
	testing.expect(t, second_ok)
	testing.expect(t, third_ok)
	testing.expect(t, !exhausted_ok)
	testing.expect_value(t, first_page, u64(0x1000))
	testing.expect_value(t, second_page, u64(0x3000))
	testing.expect_value(t, third_page, u64(0x4000))
}

@(test)
physical_page_allocator_allocates_sequential_pages_and_keeps_exhausted_state :: proc(
	t: ^testing.T,
) {
	allocator := Physical_Page_Allocator {
		next_physical = 0x1000,
		end_physical  = 0x3000,
	}

	first, first_ok := physical_page_allocate(&allocator)
	second, second_ok := physical_page_allocate(&allocator)
	exhausted_next := allocator.next_physical
	third, third_ok := physical_page_allocate(&allocator)

	testing.expect(t, first_ok)
	testing.expect_value(t, first, u64(0x1000))
	testing.expect(t, second_ok)
	testing.expect_value(t, second, u64(0x2000))
	testing.expect(t, !third_ok)
	testing.expect_value(t, third, u64(0))
	testing.expect_value(t, allocator.next_physical, exhausted_next)
	testing.expect_value(t, allocator.end_physical, u64(0x3000))

	short := Physical_Page_Allocator {
		next_physical = 0x4000,
		end_physical  = 0x4fff,
	}
	_, short_ok := physical_page_allocate(&short)
	testing.expect(t, !short_ok)
	testing.expect_value(t, short.next_physical, u64(0x4000))
	testing.expect_value(t, short.end_physical, u64(0x4fff))
}

@(test)
physical_page_allocator_can_allocate_physical_zero :: proc(t: ^testing.T) {
	allocator := Physical_Page_Allocator {
		next_physical = 0,
		end_physical  = 4096,
	}
	page, ok := physical_page_allocate(&allocator)

	testing.expect(t, ok)
	testing.expect_value(t, page, u64(0))
	testing.expect_value(t, allocator.next_physical, u64(4096))
}

@(test)
x86_virtual_address_canonical_boundaries :: proc(t: ^testing.T) {
	lower_max_48 := (u64(1) << 47) - 1
	upper_min_48 := max(u64) - lower_max_48
	testing.expect(t, x86_virtual_address_is_canonical(lower_max_48, 48))
	testing.expect(t, !x86_virtual_address_is_canonical(lower_max_48 + 1, 48))
	testing.expect(t, !x86_virtual_address_is_canonical(upper_min_48 - 1, 48))
	testing.expect(t, x86_virtual_address_is_canonical(upper_min_48, 48))

	lower_max_57 := (u64(1) << 56) - 1
	upper_min_57 := max(u64) - lower_max_57
	testing.expect(t, x86_virtual_address_is_canonical(lower_max_57, 57))
	testing.expect(t, !x86_virtual_address_is_canonical(lower_max_57 + 1, 57))
	testing.expect(t, !x86_virtual_address_is_canonical(upper_min_57 - 1, 57))
	testing.expect(t, x86_virtual_address_is_canonical(upper_min_57, 57))

	testing.expect(t, !x86_virtual_address_is_canonical(0, 47))
	testing.expect(t, !x86_virtual_address_is_canonical(0, 58))
}

@(test)
kernel_allocator_rejects_noncanonical_span :: proc(t: ^testing.T) {
	lower_max_48 := (u64(1) << 47) - 1
	pages := Physical_Page_Allocator {
		next_physical = lower_max_48,
		end_physical  = lower_max_48 + LIMINE_PAGE_SIZE,
	}
	state := Kernel_Allocator_State {
		pages                 = &pages,
		virtual_address_width = 48,
	}

	memory, err := kernel_allocator_proc(rawptr(&state), .Alloc_Non_Zeroed, 2, 1, nil, 0)

	testing.expect(t, memory == nil)
	testing.expect_value(t, err, runtime.Allocator_Error.Invalid_Argument)
	testing.expect_value(t, pages.next_physical, lower_max_48)
}

@(test)
kernel_allocator_alloc_and_alloc_non_zeroed_use_host_buffer :: proc(t: ^testing.T) {
	base := u64(uintptr(&allocator_test_buffer.bytes[0]))
	for index in 0 ..< 4096 {
		allocator_test_buffer.bytes[index] = 0xa5
	}
	pages := Physical_Page_Allocator {
		next_physical = base,
		end_physical  = base + 8192,
	}
	state := Kernel_Allocator_State {
		pages                 = &pages,
		hhdm_offset           = 0,
		virtual_address_width = 48,
	}

	zeroed, zeroed_error := kernel_allocator_proc(rawptr(&state), .Alloc, 4096, 4096, nil, 0)
	testing.expect_value(t, zeroed_error, runtime.Allocator_Error.None)
	testing.expect_value(t, len(zeroed), 4096)
	testing.expect_value(t, uintptr(raw_data(zeroed)), uintptr(&allocator_test_buffer.bytes[0]))
	for value in zeroed {
		testing.expect_value(t, value, byte(0))
	}

	for index in 4096 ..< 8192 {
		allocator_test_buffer.bytes[index] = 0x5a
	}
	non_zeroed, non_zeroed_error := kernel_allocator_proc(
		rawptr(&state),
		.Alloc_Non_Zeroed,
		4096,
		4096,
		nil,
		0,
	)
	testing.expect_value(t, non_zeroed_error, runtime.Allocator_Error.None)
	testing.expect_value(t, len(non_zeroed), 4096)
	testing.expect_value(
		t,
		uintptr(raw_data(non_zeroed)),
		uintptr(&allocator_test_buffer.bytes[4096]),
	)
	for value in non_zeroed {
		testing.expect_value(t, value, byte(0x5a))
	}
}

@(test)
kernel_allocator_zero_size_and_bad_arguments_do_not_consume_a_page :: proc(t: ^testing.T) {
	pages := Physical_Page_Allocator {
		next_physical = 0x1000,
		end_physical  = 0x3000,
	}
	state := Kernel_Allocator_State {
		pages = &pages,
	}

	memory, err := kernel_allocator_proc(nil, .Alloc, 0, 0, nil, 0)
	testing.expect(t, memory == nil)
	testing.expect_value(t, err, runtime.Allocator_Error.None)

	invalid_arguments := [3][2]int{{-1, 1}, {1, 0}, {1, 3}}
	for arguments in invalid_arguments {
		memory, err = kernel_allocator_proc(
			rawptr(&state),
			.Alloc,
			arguments[0],
			arguments[1],
			nil,
			0,
		)
		testing.expect(t, memory == nil)
		testing.expect_value(t, err, runtime.Allocator_Error.Invalid_Argument)
	}

	capacity_arguments := [2][2]int{{4097, 1}, {1, 8192}}
	for arguments in capacity_arguments {
		memory, err = kernel_allocator_proc(
			rawptr(&state),
			.Alloc,
			arguments[0],
			arguments[1],
			nil,
			0,
		)
		testing.expect(t, memory == nil)
		testing.expect_value(t, err, runtime.Allocator_Error.Out_Of_Memory)
	}
	testing.expect_value(t, pages.next_physical, u64(0x1000))
}

@(test)
kernel_allocator_rejects_nil_state_and_exhaustion :: proc(t: ^testing.T) {
	memory, err := kernel_allocator_proc(nil, .Alloc, 1, 1, nil, 0)
	testing.expect(t, memory == nil)
	testing.expect_value(t, err, runtime.Allocator_Error.Invalid_Argument)

	state := Kernel_Allocator_State{}
	memory, err = kernel_allocator_proc(rawptr(&state), .Alloc, 1, 1, nil, 0)
	testing.expect(t, memory == nil)
	testing.expect_value(t, err, runtime.Allocator_Error.Invalid_Argument)

	pages := Physical_Page_Allocator {
		next_physical = 0x2000,
		end_physical  = 0x2000,
	}
	state.pages = &pages
	memory, err = kernel_allocator_proc(rawptr(&state), .Alloc, 1, 1, nil, 0)
	testing.expect(t, memory == nil)
	testing.expect_value(t, err, runtime.Allocator_Error.Out_Of_Memory)
	testing.expect_value(t, pages.next_physical, u64(0x2000))
}

@(test)
kernel_allocator_rejects_hhdm_overflow :: proc(t: ^testing.T) {
	page := max(u64) - 2 * LIMINE_PAGE_SIZE + 1
	pages := Physical_Page_Allocator {
		next_physical = page,
		end_physical  = page + LIMINE_PAGE_SIZE,
	}
	state := Kernel_Allocator_State {
		pages       = &pages,
		hhdm_offset = 2 * LIMINE_PAGE_SIZE,
	}

	memory, err := kernel_allocator_proc(rawptr(&state), .Alloc, 1, 1, nil, 0)
	testing.expect(t, memory == nil)
	testing.expect_value(t, err, runtime.Allocator_Error.Invalid_Argument)
	testing.expect_value(t, pages.next_physical, page)
}

@(test)
kernel_allocator_rejects_misaligned_result :: proc(t: ^testing.T) {
	pages := Physical_Page_Allocator {
		next_physical = 0x1000,
		end_physical  = 0x2000,
	}
	state := Kernel_Allocator_State {
		pages                 = &pages,
		hhdm_offset           = 1,
		virtual_address_width = 48,
	}

	memory, err := kernel_allocator_proc(rawptr(&state), .Alloc, 1, 4096, nil, 0)

	testing.expect(t, memory == nil)
	testing.expect_value(t, err, runtime.Allocator_Error.Invalid_Argument)
	testing.expect_value(t, pages.next_physical, u64(0x1000))
}

@(test)
kernel_allocator_does_not_implement_free_or_other_modes :: proc(t: ^testing.T) {
	pages := Physical_Page_Allocator {
		next_physical = 0x1000,
		end_physical  = 0x3000,
	}
	state := Kernel_Allocator_State {
		pages = &pages,
	}
	unsupported := [6]runtime.Allocator_Mode {
		.Free,
		.Free_All,
		.Resize,
		.Query_Features,
		.Query_Info,
		.Resize_Non_Zeroed,
	}

	for mode in unsupported {
		memory, err := kernel_allocator_proc(rawptr(&state), mode, 1, 1, nil, 0)
		testing.expect(t, memory == nil)
		testing.expect_value(t, err, runtime.Allocator_Error.Mode_Not_Implemented)
	}
	testing.expect_value(t, pages.next_physical, u64(0x1000))
}
