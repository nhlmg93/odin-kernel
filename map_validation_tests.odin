#+build !freestanding

package main

import "core:testing"

memory_map_test_validate :: proc(
	entries: []Memory_Map_Entry,
	nil_entry_index := -1,
) -> (
	Memory_Map_Validation_Error,
	u64,
) {
	entry_pointers := make([]^Memory_Map_Entry, len(entries))
	defer delete(entry_pointers)
	for index in 0 ..< len(entries) {
		entry_pointers[index] = &entries[index]
	}
	if nil_entry_index >= 0 {
		entry_pointers[nil_entry_index] = nil
	}

	memory_map := Memory_Map_Response {
		entry_count = u64(len(entry_pointers)),
		entries     = raw_data(entry_pointers),
	}
	_, validation_error, entry_index := memory_map_validate(&memory_map)
	return validation_error, entry_index
}

@(test)
memory_map_validate_response_boundaries_test :: proc(t: ^testing.T) {
	_, validation_error, entry_index := memory_map_validate(nil)
	testing.expect_value(t, validation_error, Memory_Map_Validation_Error.Nil_Response)
	testing.expect_value(t, entry_index, u64(0))

	memory_map := Memory_Map_Response {
		entry_count = 1,
	}
	_, validation_error, entry_index = memory_map_validate(&memory_map)
	testing.expect_value(t, validation_error, Memory_Map_Validation_Error.Nil_Entry_Array)
	testing.expect_value(t, entry_index, u64(0))

	memory_map.entry_count = LIMINE_MEMORY_MAP_ENTRY_COUNT_MAX + 1
	_, validation_error, entry_index = memory_map_validate(&memory_map)
	testing.expect_value(t, validation_error, Memory_Map_Validation_Error.Entry_Count_Too_Large)
	testing.expect_value(t, entry_index, u64(0))
}

@(test)
memory_map_validate_accepts_entry_count_max_test :: proc(t: ^testing.T) {
	entries := make([]Memory_Map_Entry, int(LIMINE_MEMORY_MAP_ENTRY_COUNT_MAX))
	defer delete(entries)

	validation_error, entry_index := memory_map_test_validate(entries)

	testing.expect_value(t, validation_error, Memory_Map_Validation_Error.None)
	testing.expect_value(t, entry_index, u64(0))
}

@(test)
memory_map_validate_empty_map_test :: proc(t: ^testing.T) {
	entries: [0]Memory_Map_Entry
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.None)
	testing.expect_value(t, index, u64(0))
}

@(test)
memory_map_validate_nil_entry_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry{{base = 0, length = 0, kind = LIMINE_MEMORY_MAP_RESERVED}}
	error, index := memory_map_test_validate(entries[:], 0)
	testing.expect_value(t, error, Memory_Map_Validation_Error.Nil_Entry)
	testing.expect_value(t, index, u64(0))
}

@(test)
memory_map_validate_unsorted_bases_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry {
		{base = 0x2000, length = 0, kind = LIMINE_MEMORY_MAP_RESERVED},
		{base = 0x1000, length = 0, kind = LIMINE_MEMORY_MAP_RESERVED},
	}
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.Unsorted)
	testing.expect_value(t, index, u64(1))
}

@(test)
memory_map_validate_range_overflow_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry {
		{base = max(u64), length = 2, kind = LIMINE_MEMORY_MAP_RESERVED},
	}
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.Range_Overflow)
	testing.expect_value(t, index, u64(0))
}

@(test)
memory_map_validate_known_kinds_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry {
		{base = 0x0000, length = 0x1000, kind = LIMINE_MEMORY_MAP_USABLE},
		{base = 0x2000, length = 0x1000, kind = LIMINE_MEMORY_MAP_RESERVED},
		{base = 0x4000, length = 0x1000, kind = LIMINE_MEMORY_MAP_ACPI_RECLAIMABLE},
		{base = 0x6000, length = 0x1000, kind = LIMINE_MEMORY_MAP_ACPI_NVS},
		{base = 0x8000, length = 0x1000, kind = LIMINE_MEMORY_MAP_BAD_MEMORY},
		{base = 0xa000, length = 0x1000, kind = LIMINE_MEMORY_MAP_BOOTLOADER_RECLAIMABLE},
		{base = 0xc000, length = 0x1000, kind = LIMINE_MEMORY_MAP_EXECUTABLE_AND_MODULES},
		{base = 0xe000, length = 0x1000, kind = LIMINE_MEMORY_MAP_FRAMEBUFFER},
		{base = 0x10000, length = 0x1000, kind = LIMINE_MEMORY_MAP_RESERVED_MAPPED},
	}
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.None)
	testing.expect_value(t, index, u64(0))
}

@(test)
memory_map_validate_unknown_kind_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry{{base = 0, length = 0, kind = 9}}
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.Unknown_Kind)
	testing.expect_value(t, index, u64(0))
}

@(test)
memory_map_validate_unaligned_usable_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry {
		{base = 1, length = LIMINE_PAGE_SIZE, kind = LIMINE_MEMORY_MAP_USABLE},
	}
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.Unaligned_Protected_Range)
	testing.expect_value(t, index, u64(0))
}

@(test)
memory_map_validate_unaligned_bootloader_reclaimable_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry {
		{base = 0, length = LIMINE_PAGE_SIZE + 1, kind = LIMINE_MEMORY_MAP_BOOTLOADER_RECLAIMABLE},
	}
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.Unaligned_Protected_Range)
	testing.expect_value(t, index, u64(0))
}

@(test)
memory_map_validate_usable_bootloader_reclaimable_overlap_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry {
		{base = 0, length = 2 * LIMINE_PAGE_SIZE, kind = LIMINE_MEMORY_MAP_USABLE},
		{
			base = LIMINE_PAGE_SIZE,
			length = LIMINE_PAGE_SIZE,
			kind = LIMINE_MEMORY_MAP_BOOTLOADER_RECLAIMABLE,
		},
	}
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.Protected_Range_Overlap)
	testing.expect_value(t, index, u64(1))
}

@(test)
memory_map_validate_protected_after_reserved_overlap_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry {
		{base = 0, length = 0x2000, kind = LIMINE_MEMORY_MAP_RESERVED},
		{base = 0x1000, length = 0x1000, kind = LIMINE_MEMORY_MAP_USABLE},
	}
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.Protected_Range_Overlap)
	testing.expect_value(t, index, u64(1))
}

@(test)
memory_map_validate_reserved_after_protected_overlap_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry {
		{base = 0, length = 0x2000, kind = LIMINE_MEMORY_MAP_USABLE},
		{base = 0x1000, length = 0x1000, kind = LIMINE_MEMORY_MAP_RESERVED},
	}
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.Protected_Range_Overlap)
	testing.expect_value(t, index, u64(1))
}

@(test)
memory_map_validate_protected_adjacency_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry {
		{base = 0, length = 0x1000, kind = LIMINE_MEMORY_MAP_RESERVED},
		{base = 0x1000, length = 0x1000, kind = LIMINE_MEMORY_MAP_USABLE},
		{base = 0x2000, length = 0x1000, kind = LIMINE_MEMORY_MAP_RESERVED},
	}
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.None)
	testing.expect_value(t, index, u64(0))
}

@(test)
memory_map_validate_zero_length_entries_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry {
		{base = 0x1000, length = 0, kind = LIMINE_MEMORY_MAP_USABLE},
		{base = 0x1000, length = 0, kind = LIMINE_MEMORY_MAP_RESERVED},
		{base = 0x1000, length = 0, kind = LIMINE_MEMORY_MAP_BOOTLOADER_RECLAIMABLE},
	}
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.None)
	testing.expect_value(t, index, u64(0))
}

@(test)
memory_map_validate_reserved_overlap_test :: proc(t: ^testing.T) {
	entries := [?]Memory_Map_Entry {
		{base = 0, length = 0x3000, kind = LIMINE_MEMORY_MAP_RESERVED},
		{base = 0x1000, length = 0x1000, kind = LIMINE_MEMORY_MAP_RESERVED},
	}
	error, index := memory_map_test_validate(entries[:])
	testing.expect_value(t, error, Memory_Map_Validation_Error.None)
	testing.expect_value(t, index, u64(0))
}
