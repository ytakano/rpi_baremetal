ENTRY(_start)
SECTIONS
{
    . = 0x80000;
    __ram_start = .;
    .init : { KEEP(*(.init)) }
    .text : { *(.text .text.* .gnu.linkonce.t*) }
    .fini           :
    {
        KEEP (*(SORT_NONE(.fini)))
    }
    PROVIDE (__etext = .);
    PROVIDE (_etext = .);
    PROVIDE (etext = .);

    .rodata : { *(.rodata .rodata.* .gnu.linkonce.r*) }

    .eh_frame_hdr   : { *(.eh_frame_hdr) *(.eh_frame_entry .eh_frame_entry.*) }

    . = ALIGN(8);
    PROVIDE(__eh_frame = .);
    .eh_frame : { KEEP (*(.eh_frame)) *(.eh_frame.*) }

    PROVIDE(_data = .);
    .data : ALIGN(1024 * 64) {
        __data_start = .;
        *(.data .data.* .gnu.linkonce.d*)
        __data_end = .;
    }
    .bss (NOLOAD) : ALIGN(1024 * 64) {
        __bss_start    = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    }
    . = ALIGN(1024 * 64);

    /* 8MiB space for EL1 */
    __stack_memory = .;

   /DISCARD/ : { *(.comment) *(.gnu*) *(.note*) }
}
__bss_size = (__bss_end - __bss_start) >> 3;
