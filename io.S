.section .text

.global x86_out8
.type   x86_out8, @function

x86_out8:
	movw %di, %dx
	movb %sil, %al
	outb %al, %dx
	ret

.global x86_in8
.type   x86_in8, @function

x86_in8:
	movw %di, %dx
	xorl %eax, %eax
	inb  %dx, %al
	ret

.global x86_halt
.type   x86_halt, @function

x86_halt:
	cli

1:
	hlt
	jmp 1b

.global x86_read_cs
.type   x86_read_cs, @function

x86_read_cs:
	xorl %eax, %eax
	movw %cs, %ax
	ret

.global x86_read_ss
.type   x86_read_ss, @function

x86_read_ss:
	xorl %eax, %eax
	movw %ss, %ax
	ret

.global x86_load_gdt
.type   x86_load_gdt, @function

x86_load_gdt:
	cli
	lgdt (%rdi)

	movw $0x10, %ax
	movw %ax, %ds
	movw %ax, %es
	movw %ax, %ss
	movw %ax, %fs
	movw %ax, %gs

	pushq $0x08
	leaq  1f(%rip), %rax
	pushq %rax
	lretq

1:
	ret

.global x86_load_idt
.type   x86_load_idt, @function

x86_load_idt:
	lidt (%rdi)
	ret

.global x86_trigger_int3
.type   x86_trigger_int3, @function

x86_trigger_int3:
	int3
	ret

.extern breakpoint_handler
.global x86_int3_stub
.type   x86_int3_stub, @function

x86_int3_stub:
	cld

	// Preserve RBX and use it to remember the exception fram
	pushq %rbx
	movq  %rsp, %rbx

	// Saved RIP is now eight bytes above the saved RBX.
	movq 8(%rbx), %rdi

	// Align the stack for the C calling convention.
	andq $-16, %rsp
	call breakpoint_handler

	// Restore the CPU exception frame.
	movq %rbx, %rsp
	popq %rbx
	iretq

   .global x86_trigger_ud2
   .type x86_trigger_ud2, @function

x86_trigger_ud2:
   ud2
   ret

.extern invalid_opcode_handler
.global x86_ud2_stub
.type x86_ud2_stub, @function

x86_ud2_stub:
   cld
   movq (%rsp), %rdi
   andq $-16, %rsp
   call invalid_opcode_handler

   /* A UD2 fault must not return to the same instruction. */
   cli
1:
   hlt
   jmp 1b

.section .note.GNU-stack, "", @progbits
