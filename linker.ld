OUTPUT_FORMAT(elf64-x86-64)
   ENTRY(kernel_entry)

   PHDRS {
      requests PT_LOAD FLAGS(6); /* read + write */
      text   PT_LOAD FLAGS(5); /* read + execute */
      rodata PT_LOAD FLAGS(4); /* read */
      data   PT_LOAD FLAGS(6); /* read + write */
   }

   SECTIONS {
      /* Virtual address. Limine maps this to physical RAM. */
      . = 0xffffffff80000000;

      .limine_requests : ALIGN(8) {
         KEEP(*(.limine_requests_start))
         KEEP(*(.limine_requests))
         KEEP(*(.limine_requests_end))
      } :requests

      .text : ALIGN(0x1000) {
         *(.text .text.*)
      } :text

      .rodata : ALIGN(0x1000) {
         *(.rodata .rodata.*)
         *(.odinti .odinti.*)
      } :rodata

      .data : ALIGN(0x1000) {
         *(.data .data.*)
      } :data

      .bss : ALIGN(0x1000) {
         *(COMMON)
         *(.bss .bss.*)
      } :data

      /DISCARD/ : {
         *(.eh_frame .eh_frame.*)
         *(.note .note.*)
      }
   }
