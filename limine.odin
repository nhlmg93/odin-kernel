package main

// https://github.com/Limine-Bootloader/limine-protocol
// Pinned protocol commit:
// 4e1587972c148d43b2f397e4e5983bdd6c2a55a0

LIMINE_BASE_REVISION :: u64(6)
LIMINE_MEMORY_MAP_USABLE :: u64(0)
LIMINE_MEMORY_MAP_RESERVED :: u64(1)
LIMINE_MEMORY_MAP_ACPI_RECLAIMABLE :: u64(2)
LIMINE_MEMORY_MAP_ACPI_NVS :: u64(3)
LIMINE_MEMORY_MAP_BAD_MEMORY :: u64(4)
LIMINE_MEMORY_MAP_BOOTLOADER_RECLAIMABLE :: u64(5)
LIMINE_MEMORY_MAP_EXECUTABLE_AND_MODULES :: u64(6)
LIMINE_MEMORY_MAP_FRAMEBUFFER :: u64(7)
LIMINE_MEMORY_MAP_RESERVED_MAPPED :: u64(8)
LIMINE_MEMORY_MAP_ENTRY_COUNT_MAX :: u64(4096)
LIMINE_PAGE_SIZE :: u64(4096)

@(export, link_section = ".limine_requests_start")
limine_requests_start: [4]u64 = {
	0xf6b8f4b39de7d1ae,
	0xfab91a6940fcb9cf,
	0x785c6ed015d3e316,
	0x181e920a7852b9d9,
}

@(export, link_section = ".limine_requests")
limine_base_revision: [3]u64 = {0xf9562b2d5c95a6c8, 0x6a7b384944536bdc, LIMINE_BASE_REVISION}

HHDM_Response :: struct {
	revision: u64,
	offset:   u64,
}

HHDM_Request :: struct {
	id:       [4]u64,
	revision: u64,
	response: ^HHDM_Response,
}

#assert(size_of(HHDM_Response) == 16)
#assert(size_of(HHDM_Request) == 48)

@(export, link_section = ".limine_requests")
limine_hhdm_request: HHDM_Request = {
	id       = {0xc7b1dd30df4c8b88, 0x0a82e883a194f07b, 0x48dcf1cb8ad2b852, 0x63984e959a98244b},
	revision = 0,
}

Memory_Map_Entry :: struct {
	base:   u64,
	length: u64,
	kind:   u64,
}

Memory_Map_Response :: struct {
	revision:    u64,
	entry_count: u64,
	entries:     [^]^Memory_Map_Entry,
}

Memory_Map_Request :: struct {
	id:       [4]u64,
	revision: u64,
	response: ^Memory_Map_Response,
}

#assert(size_of(Memory_Map_Entry) == 24)
#assert(size_of(Memory_Map_Response) == 24)
#assert(size_of(Memory_Map_Request) == 48)

@(export, link_section = ".limine_requests")
limine_memory_map_request: Memory_Map_Request = {
	id       = {0xc7b1dd30df4c8b88, 0x0a82e883a194f07b, 0x67cf3d9d378a806f, 0xe304acdfc50c3c62},
	revision = 0,
}

@(export, link_section = ".limine_requests_end")
limine_requests_end: [2]u64 = {0xadc0e0531bb10d03, 0x9572709f31764c62}

limine_base_revision_supported :: proc "contextless" () -> bool {
	return limine_base_revision[2] == 0
}

Validated_Memory_Map :: struct {
	response: ^Memory_Map_Response,
}

Memory_Map_Validation_Error :: enum {
	None,
	Nil_Response,
	Nil_Entry_Array,
	Entry_Count_Too_Large,
	Nil_Entry,
	Unsorted,
	Range_Overflow,
	Unknown_Kind,
	Unaligned_Protected_Range,
	Protected_Range_Overlap,
}

memory_map_kind_is_known :: proc "contextless" (kind: u64) -> bool {
	return kind == LIMINE_MEMORY_MAP_USABLE ||
	       kind == LIMINE_MEMORY_MAP_RESERVED ||
	       kind == LIMINE_MEMORY_MAP_ACPI_RECLAIMABLE ||
	       kind == LIMINE_MEMORY_MAP_ACPI_NVS ||
	       kind == LIMINE_MEMORY_MAP_BAD_MEMORY ||
	       kind == LIMINE_MEMORY_MAP_BOOTLOADER_RECLAIMABLE ||
	       kind == LIMINE_MEMORY_MAP_EXECUTABLE_AND_MODULES ||
	       kind == LIMINE_MEMORY_MAP_FRAMEBUFFER ||
	       kind == LIMINE_MEMORY_MAP_RESERVED_MAPPED
}

memory_map_kind_is_protected :: proc "contextless" (kind: u64) -> bool {
	return kind == LIMINE_MEMORY_MAP_USABLE ||
	       kind == LIMINE_MEMORY_MAP_BOOTLOADER_RECLAIMABLE
}

memory_map_entry_is_page_aligned :: proc "contextless" (entry: ^Memory_Map_Entry) -> bool {
	return entry.base % LIMINE_PAGE_SIZE == 0 && entry.length % LIMINE_PAGE_SIZE == 0
}

memory_map_entry_overlaps_protected_range :: proc "contextless" (
	entry: ^Memory_Map_Entry,
	max_prior_end: u64,
	max_prior_protected_end: u64,
) -> bool {
	if memory_map_kind_is_protected(entry.kind) {
		return entry.base < max_prior_end
	}
	return entry.base < max_prior_protected_end
}

memory_map_validate :: proc "contextless" (
	memory_map: ^Memory_Map_Response,
) -> (
	Validated_Memory_Map,
	Memory_Map_Validation_Error,
	u64,
) {
	if memory_map == nil {
		return {}, .Nil_Response, 0
	}
	if memory_map.entry_count > LIMINE_MEMORY_MAP_ENTRY_COUNT_MAX {
		return {}, .Entry_Count_Too_Large, 0
	}
	if memory_map.entry_count != 0 && memory_map.entries == nil {
		return {}, .Nil_Entry_Array, 0
	}

	has_prior := false
	prior_base: u64 = 0
	max_prior_end: u64 = 0
	max_prior_protected_end: u64 = 0
	for index in 0 ..< memory_map.entry_count {
		entry := memory_map.entries[index]
		if entry == nil {
			return {}, .Nil_Entry, index
		}
		if has_prior && entry.base < prior_base {
			return {}, .Unsorted, index
		}
		if entry.length > max(u64) - entry.base {
			return {}, .Range_Overflow, index
		}
		if !memory_map_kind_is_known(entry.kind) {
			return {}, .Unknown_Kind, index
		}
		is_protected := memory_map_kind_is_protected(entry.kind)
		if is_protected && !memory_map_entry_is_page_aligned(entry) {
			return {}, .Unaligned_Protected_Range, index
		}
		if entry.length != 0 {
			entry_end := entry.base + entry.length
			if memory_map_entry_overlaps_protected_range(
				entry,
				max_prior_end,
				max_prior_protected_end,
			) {
				return {}, .Protected_Range_Overlap, index
			}
			if entry_end > max_prior_end {
				max_prior_end = entry_end
			}
			if is_protected && entry_end > max_prior_protected_end {
				max_prior_protected_end = entry_end
			}
		}
		has_prior = true
		prior_base = entry.base
	}

	return {response = memory_map}, .None, 0
}
