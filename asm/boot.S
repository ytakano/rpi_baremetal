.section .init, "x"
.global _start

#define STACKSIZE 1024 * 1024 * 2

_start:
    // set stack before _start
    mrs     x6, mpidr_el1 // read cpu id
    and     x6, x6, #0xFF
    add     x7, x6, #1

    mov     x4, #(STACKSIZE)
    mul     x7, x7, x4

    ldr     x8, =__stack_memory
    add     x8, x8, x7
    mov     x20, x8 // save stack pointer

    cbnz    x6, 2f

    // if cpu id == 0

    // clear bss
    ldr     x8, =__bss_start
    ldr     w9, =__bss_size

1:
    cbz     w9, 2f
    str     xzr, [x8], #8
    sub     w9, w9, #1
    cbnz    w9, 1b

2:
    // get current EL
    mrs     x4, CurrentEL
    and     x5, x4, #(0b1100) // clear reserved bits
    cmp     x5, #(1 << 2)
    beq     .EL1

    mrs     x4, hcr_el2
    orr     x4, x4, #(1 << 31) // AArch64
    orr     x4, x4, #(1 << 1)  // SWIO hardwired
    msr     hcr_el2, x4

    // enable CNTP for EL1
    mrs     x8, cnthctl_el2
    orr     x8, x8, #3
    msr     cnthctl_el2, x8
    msr     cntvoff_el2, xzr

    msr     sp_el0, x20  // set stack pointer
    msr     sp_el1, x20

    // running at EL3?
    cmp     x5, #(3 << 2)
    beq     .EL3

    // running at EL2?
    cmp     x5, #(2 << 2)
    beq     .EL2

.EL3:
    b       .loop

.EL2:
    // change execution level to EL1
    mov     x8, #0b100   // EL1t
    msr     spsr_el2, x8
    adr     x8, .EL1     // set entry point
    msr     elr_el2, x8

    eret

    // EL1t
.EL1:
    // disable all interrupt (daif at bits 9..6)
    msr     DAIFSet, #0x0f
    msr     spsel, #0

    mov     sp, x20
    bl      kernel_main

.loop:
    wfe
    b       .loop
