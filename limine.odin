package main

// https://github.com/Limine-Bootloader/limine-protocol
// Pinned protocol commit:
// 4e1587972c148d43b2f397e4e5983bdd6c2a55a0

LIMINE_BASE_REVISION                       :: u64(6)
LIMINE_MEMORY_MAP_USABLE                   :: u64(0)
LIMINE_MEMORY_MAP_RESERVED                 :: u64(1)
LIMINE_MEMORY_MAP_ACPI_RECLAIMABLE         :: u64(2)
LIMINE_MEMORY_MAP_ACPI_NVS                 :: u64(3)
LIMINE_MEMORY_MAP_BAD_MEMORY               :: u64(4)
LIMINE_MEMORY_MAP_BOOTLOADER_RECLAIMABLE   :: u64(5)
LIMINE_MEMORY_MAP_EXECUTABLE_AND_MODULES   :: u64(6)
LIMINE_MEMORY_MAP_FRAMEBUFFER              :: u64(7)
LIMINE_PAGE_SIZE                           :: u64(4096)

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

memory_map_validate_and_print :: proc "contextless" (memory_map: ^Memory_Map_Response) {
	has_prior := false
	prior_base: u64 = 0
	max_prior_end: u64 = 0
	max_prior_protected_end: u64 = 0
	for index in 0 ..< memory_map.entry_count {
		entry := memory_map.entries[index]
		if entry == nil {
			kernel_panic("nil memory map entry")
		}
		if has_prior && entry.base < prior_base {
			kernel_panic("memory map entries are not sorted")
		}
		if entry.length > max(u64) - entry.base {
			kernel_panic("memory map entry range overflows")
		}
		if entry.kind != LIMINE_MEMORY_MAP_USABLE &&
		   entry.kind != LIMINE_MEMORY_MAP_RESERVED &&
		   entry.kind != LIMINE_MEMORY_MAP_ACPI_RECLAIMABLE &&
		   entry.kind != LIMINE_MEMORY_MAP_ACPI_NVS &&
		   entry.kind != LIMINE_MEMORY_MAP_BAD_MEMORY &&
		   entry.kind != LIMINE_MEMORY_MAP_BOOTLOADER_RECLAIMABLE &&
		   entry.kind != LIMINE_MEMORY_MAP_EXECUTABLE_AND_MODULES &&
		   entry.kind != LIMINE_MEMORY_MAP_FRAMEBUFFER {
			kernel_panic("unknown memory map entry kind")
		}
		protected_kind := entry.kind == LIMINE_MEMORY_MAP_USABLE || entry.kind == LIMINE_MEMORY_MAP_BOOTLOADER_RECLAIMABLE
		if protected_kind && (entry.base % LIMINE_PAGE_SIZE != 0 || entry.length % LIMINE_PAGE_SIZE != 0) {
			kernel_panic("memory map entry is not page-aligned")
		}
		if entry.length != 0 {
			entry_end := entry.base + entry.length
			if protected_kind {
				if entry.base < max_prior_end {
					kernel_panic("memory map protected range overlaps another entry")
				}
			} else if entry.base < max_prior_protected_end {
				kernel_panic("memory map protected range overlaps another entry")
			}
			if entry_end > max_prior_end {
				max_prior_end = entry_end
			}
			if protected_kind && entry_end > max_prior_protected_end {
				max_prior_protected_end = entry_end
			}
		}
		has_prior = true
		prior_base = entry.base

		uart_write_string("MEM base=")
		uart_write_hex64(entry.base)
		uart_write_string(" length=")
		uart_write_hex64(entry.length)
		uart_write_string(" kind=")
		uart_write_hex64(entry.kind)
		uart_write_string("\r\n")
	}
}
