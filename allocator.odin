package main

import "base:runtime"

Physical_Page_Allocator :: struct {
	memory_map:    Validated_Memory_Map,
	entry_index:   u64,
	next_physical: u64,
	end_physical:  u64,
}

physical_page_allocator_init :: proc "contextless" (
	allocator: ^Physical_Page_Allocator,
	memory_map: Validated_Memory_Map,
) -> bool {
	allocator^ = {
		memory_map = memory_map,
	}

	response := memory_map.response
	if response == nil {
		return false
	}

	for index in 0 ..< response.entry_count {
		entry := response.entries[index]
		if entry.kind == LIMINE_MEMORY_MAP_USABLE && entry.length >= LIMINE_PAGE_SIZE {
			allocator.entry_index = index + 1
			allocator.next_physical = entry.base
			allocator.end_physical = entry.base + entry.length
			return true
		}
	}

	allocator.entry_index = response.entry_count
	return false
}

physical_page_allocate :: proc "contextless" (allocator: ^Physical_Page_Allocator) -> (u64, bool) {
	if allocator.next_physical < allocator.end_physical &&
	   allocator.end_physical - allocator.next_physical >= LIMINE_PAGE_SIZE {
		page := allocator.next_physical
		allocator.next_physical += LIMINE_PAGE_SIZE
		return page, true
	}

	response := allocator.memory_map.response
	if response == nil {
		return 0, false
	}

	for index in allocator.entry_index ..< response.entry_count {
		entry := response.entries[index]
		allocator.entry_index = index + 1
		if entry.kind == LIMINE_MEMORY_MAP_USABLE && entry.length >= LIMINE_PAGE_SIZE {
			page := entry.base
			allocator.next_physical = entry.base + LIMINE_PAGE_SIZE
			allocator.end_physical = entry.base + entry.length
			return page, true
		}
	}

	return 0, false
}

Kernel_Allocator_State :: struct {
	pages:                 ^Physical_Page_Allocator,
	hhdm_offset:           u64,
	virtual_address_width: u8,
}

physical_page_allocator: Physical_Page_Allocator
kernel_allocator_state: Kernel_Allocator_State

kernel_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: runtime.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> (
	[]byte,
	runtime.Allocator_Error,
) {
	if mode == .Free {
		return nil, .Mode_Not_Implemented
	}
	if mode != .Alloc && mode != .Alloc_Non_Zeroed {
		return nil, .Mode_Not_Implemented
	}
	if size == 0 {
		return nil, .None
	}
	if size < 0 || alignment <= 0 || (alignment & (alignment - 1)) != 0 {
		return nil, .Invalid_Argument
	}
	if size > int(LIMINE_PAGE_SIZE) || alignment > int(LIMINE_PAGE_SIZE) {
		return nil, .Out_Of_Memory
	}

	state := (^Kernel_Allocator_State)(allocator_data)
	if state == nil || state.pages == nil {
		return nil, .Invalid_Argument
	}
	pages_before := state.pages^
	physical_page, allocated := physical_page_allocate(state.pages)
	if !allocated {
		return nil, .Out_Of_Memory
	}
	if physical_page > max(u64) - state.hhdm_offset {
		state.pages^ = pages_before
		return nil, .Invalid_Argument
	}
	virtual_address := physical_page + state.hhdm_offset
	allocation_size := u64(size)
	if allocation_size != 0 && virtual_address > max(u64) - (allocation_size - 1) {
		state.pages^ = pages_before
		return nil, .Invalid_Argument
	}
	allocation_end := virtual_address + allocation_size - 1
	if !x86_virtual_address_is_canonical(virtual_address, state.virtual_address_width) ||
	   !x86_virtual_address_is_canonical(allocation_end, state.virtual_address_width) ||
	   virtual_address % u64(alignment) != 0 {
		state.pages^ = pages_before
		return nil, .Invalid_Argument
	}

	result := ([^]u8)(uintptr(virtual_address))[:size]
	if mode == .Alloc {
		for index in 0 ..< size {
			result[index] = 0
		}
	}
	return result, .None
}
