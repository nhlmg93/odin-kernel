.section .text

.extern kernel_main
.global kernel_entry
.type kernel_entry, @function
kernel_entry:
	movq %cr0, %rax
	andq $-13, %rax
	orq $2, %rax
	movq %rax, %cr0

	movq %cr4, %rax
	orq $0x600, %rax
	movq %rax, %cr4

	jmp kernel_main

.size kernel_entry, .-kernel_entry

.section .note.GNU-stack, "", @progbits
