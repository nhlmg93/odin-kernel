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

.section .note.GNU-stack, "", @progbits
