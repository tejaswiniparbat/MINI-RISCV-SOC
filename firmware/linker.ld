/* One 4 KB image at address 0. The same hex file is loaded into imem and dmem. */
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS
{
    .text   : { *(.text.init) *(.text*) }              > RAM
    .rodata : { *(.rodata*) *(.srodata*) }             > RAM
    .data   : { *(.data*) *(.sdata*) }                 > RAM
    .bss    : { *(.bss*) *(.sbss*) *(COMMON) }         > RAM

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
