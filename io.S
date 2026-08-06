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

   .global x86_int3_stub
   .type x86_int3_stub, @function
   x86_int3_stub:
      pushq $0
      pushq $3
      jmp x86_exception_common

   .extern exception_handler
   .global x86_exception_common
   .type x86_exception_common, @function
   x86_exception_common:
      cld

      pushq %rax
      pushq %rbx
      pushq %rcx
      pushq %rdx
      pushq %rbp
      pushq %rsi
      pushq %rdi
      pushq %r8
      pushq %r9
      pushq %r10
      pushq %r11
      pushq %r12
      pushq %r13
      pushq %r14
      pushq %r15

      /* RBX preserves the original frame across the C call. */
      movq %rsp, %rbx
      movq %rsp, %rdi
      andq $-16, %rsp
      call exception_handler
      movq %rbx, %rsp

      popq %r15
      popq %r14
      popq %r13
      popq %r12
      popq %r11
      popq %r10
      popq %r9
      popq %r8
      popq %rdi
      popq %rsi
      popq %rbp
      popq %rdx
      popq %rcx
      popq %rbx
      popq %rax

      /* Remove vector and normalized error code. */
      addq $16, %rsp
      iretq

   .global x86_trigger_ud2
   .type x86_trigger_ud2, @function

x86_trigger_ud2:
   ud2
   ret

   .global x86_ud2_stub
   .type x86_ud2_stub, @function
   x86_ud2_stub:
      pushq $0
      pushq $6
      jmp x86_exception_common

   .global x86_read_cr2
   .type x86_read_cr2, @function
   x86_read_cr2:
      movq %cr2, %rax
      ret

   .global x86_trigger_page_fault
   .type x86_trigger_page_fault, @function
   x86_trigger_page_fault:
      movabsq $0x0000400000000000, %rax
      movq (%rax), %rax
      ret

   .global x86_page_fault_stub
   .type x86_page_fault_stub, @function
   x86_page_fault_stub:
      /* The CPU already pushed the error code. */
      pushq $14
      jmp x86_exception_common


.global x86_load_tss
.type x86_load_tss, @function
x86_load_tss:
   movw %di, %ax
   ltr %ax
   ret

.global x86_read_tr
.type x86_read_tr, @function
x86_read_tr:
   xorl %eax, %eax
   str %ax
   ret

.section .note.GNU-stack, "", @progbits
