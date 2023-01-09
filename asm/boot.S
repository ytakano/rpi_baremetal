/*
 * MIT License
 *
 * Copyright (c) 2020 Yuuki Takano <ytakanoster@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/*
 * Copyright (c) 2016-2019 Raspberry Pi (Trading) Ltd.
 * Copyright (c) 2016 Stephen Warren <swarren@wwwdotorg.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * * Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * * Neither the name of the copyright holder nor the names of its contributors
 *   may be used to endorse or promote products derived from this software
 *   without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

.section .init, "x"
.global _start

#define BIT(x) (1 << (x))

#ifdef raspi4
    #define BCM2711 1
#endif

#if BCM2711
    #define LOCAL_CONTROL       0xff800000
    #define LOCAL_PRESCALER     0xff800008
#else
    #define LOCAL_CONTROL       0x40000000
    #define LOCAL_PRESCALER     0x40000008
#endif

#if BCM2711
    #define OSC_FREQ            54000000
#else
    #define OSC_FREQ            19200000
#endif

#define CPUECTLR_EL1            S3_1_C15_C2_1
#define CPUECTLR_EL1_SMPEN      BIT(6)

#define L2CTLR_EL1              S3_1_C11_C0_2

#define SCR_RW              BIT(10)
#define SCR_HCE             BIT(8)  // Enable hypervisor call
#define SCR_SMD             BIT(7)  // Disable secure monitor call
#define SCR_RES1_5          BIT(5)
#define SCR_RES1_4          BIT(4)
#define SCR_NS              BIT(0)  // EL0 and EL1 are non-secure world

#define SCR_VAL (SCR_RW | SCR_SMD | SCR_RES1_5 | SCR_RES1_4 | SCR_NS)

_start:
    /*
     * LOCAL_CONTROL:
     * Bit 9 clear: Increment by 1 (vs. 2).
     * Bit 8 clear: Timer source is 19.2MHz crystal (vs. APB).
     */
    mov     x0, #LOCAL_CONTROL
    str     wzr, [x0]

    /* LOCAL_PRESCALER; divide-by (0x80000000 / register_val) == 1 */
    mov     w1, 0x80000000
    str     w1, [x0, #(LOCAL_PRESCALER - LOCAL_CONTROL)]

    /* Set SMPEN */
    mov     x0, #CPUECTLR_EL1_SMPEN
    msr     CPUECTLR_EL1, x0

    /* Set L2 read/write cache latency to 3 */
    mrs     x0, L2CTLR_EL1
    mov     x1, #0x22
    orr     x0, x0, x1
    msr     L2CTLR_EL1, x0

    /* disable all interrupt (daif at bits 9..6) */
    msr     DAIFSet, #0x0f

    /* set stack before _start */
    ldr     x1, =__stack_el1_start
    mrs     x2, mpidr_el1    // read cpu id
    and     x2, x2, #0xFF
    mov     x4, #(STACKSIZE)
    mul     x3, x2, x4
    sub     x1, x1, x3
    mov     x10, x1          // save stack pointer

    cbnz    x2, .L4

    /* if cpu id == 0 */
.L2:
    /* clear bss */
    ldr     x1, =__bss_start
    ldr     w2, =__bss_size

.L3:
    cbz     w2, .L4
    str     xzr, [x1], #8
    sub     w2, w2, #1
    cbnz    w2, .L3

.L4:
    msr     sp_el0, x10  // set stack pointer
    msr     sp_el1, x10

    mrs     x0, hcr_el2
    orr     x0, x0, #(1 << 31) // AArch64
    orr     x0, x0, #(1 << 1)  // SWIO hardwired on Pi3
    msr     hcr_el2, x0
    mrs     x0, hcr_el2

    // enable CNTP for EL1
    mrs     x1, cnthctl_el2
    orr     x1, x1, #3
    msr     cnthctl_el2, x1
    msr     cntvoff_el2, xzr

    // Set up sctlr_el2
    // All set bits below are res1. LE, no WXN/I/SA/C/A/M
    ldr     x0, =0x30c50830
    msr     sctlr_el2, x0

    // get current EL
    mrs     x0, CurrentEL
    and     x0, x0, #(0b1100) // clear reserved bits

    // running at EL3?
    cmp     x0, #(3 << 2)
    beq     .EL3

    // running at EL2?
    cmp     x0, #(2 << 2)
    beq     .EL2

.EL3:
    ldr     x0, =SCR_VAL
    msr     SCR_EL3, x0

    // Set up CNTFRQ_EL0
    ldr     x0, =OSC_FREQ
    msr     CNTFRQ_EL0, x0

    mov     x0, #0x33ff
    msr     cptr_el3, x0 // Disable coprocessor traps to EL3

    mov     x1, #0b100   // EL1t
    msr     spsr_el3, x1
    adr     x1, .EL1     // set entry point
    msr     elr_el3, x1

    eret

.EL2:
    // disable all interrupt (daif at bits 9..6)
    msr     DAIFSet, #0x0f

    // change execution level to EL1
    mov     x1, #0b100   // EL1t
    msr     spsr_el2, x1
    adr     x1, .EL1      // set entry point
    msr     elr_el2, x1

    eret

    // EL1t
.EL1:
    // disable all interrupt (daif at bits 9..6)
    msr     DAIFSet, #0x0f

    mov     sp, x10
    bl      kernel_main

.loop:
    wfe
    b       .loop
