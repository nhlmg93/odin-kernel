.section .text

.global x86_out8
.type x86_out8, @function
x86_out8:
   movw %di, %dx
   movb %sil, %al
   outb %al, %dx
   ret

.global x86_in8
   .type x86_in8, @function
   x86_in8:
      movw %di, %dx
      xorl %eax, %eax
      inb %dx, %al
      ret

.section .note.GNU-stack,"",@progbits
