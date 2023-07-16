## AArch64ブートコードドキュメント

このドキュメントは、AArch64アーキテクチャ向けのブートコードの解説です。このコードは、プロセッサのブートプロセス中に実行されるアセンブリ言語のコードであり、システムの初期化とスタートアップの準備を行います。

### セクションとグローバル指定子

```assembly
.section .init, "x"
.global _start
```

このコードは、セクションとグローバル指定子を定義しています。`.init`セクションは、初期化コードを含むセクションを定義します。`_start`はエントリーポイントとしてグローバルに定義されています。

### スタックの設定

```assembly
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
```

このセクションでは、スタックの設定が行われています。まず、CPU IDを読み取り、それを使用してスタックを設定します。`mpidr_el1`は、MPIDRレジスタからCPU IDを取得するための特殊なレジスタです。次に、`STACKSIZE`を定義し、スタックサイズを計算します。その後、`__stack_memory`シンボルからスタックメモリのアドレスを読み取り、CPU IDに基づいてスタックポインタを計算し、`x20`レジスタに保存します。

### BSSセクションのクリア

```assembly
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
```

この部分では、BSSセクションをクリアしています。BSSセクションは、初期化されていないグローバル変数や静的変数の領域です。最初の命令は、CPU IDが0であるかどうかをチェックしています。CPU IDが0の場合、BSSセクションをクリアする処理が実行されます。`__bss_start`と`__bss_size`シンボルからBSSセクションの開始アドレスとサイズを読み取り、ループを使用してBSS領域をゼロで埋めます。

### カレント実行レベルの確認

```assembly
    // get current EL
    mrs     x4, CurrentEL
    and     x5, x4, #(0b1100) // clear reserved bits
    cmp     x5, #(1 << 2)
    beq     .EL1
```

この部分では、現在の実行レベル (EL) を取得しています。`CurrentEL`レジスタから現在の実行レベルを読み取り、予約ビットをクリアします。その後、実行レベルがEL1であるかどうかをチェックし、条件分岐して対応するセクションにジャンプします。

### EL2およびEL3の設定

```assembly
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
```

この部分では、EL2およびEL3の設定が行われます。まず、`hcr_el2`レジスタに対してビットのオーバーレイを行い、AArch64モードとSWIOハードウェアの設定を行います。次に、CNTPをEL1で有効にし、カウンタのオフセットをクリアします。その後、スタックポインタを設定し、実行レベルを確認し、対応するセクションにジャンプします。

`.EL3`では、`.loop`ラベルにジャンプします。`.EL2`では、実行レベルをEL1に変更し、エントリーポイントを`.EL1`に設定してから、`eret`命令で実行レベルの切り替えを行います。

`.EL1`では、すべての割り込みを無効化し、`DAIFSet`レジスタを使用して割り込みフラグを設定します。また、スタックポインタを設定し、`kernel_main`関数を呼び出します。

以上が、AArch64ブートコードのドキュメントです。このコードは、スタックの設定、BSSセクションのクリア、実行レベルの確認および設定、およびエントリーポイントの設定を行い、最終的に`kernel_main`関数を呼び出すまでの初期化処理を行います。このコードはシステムのブートプロセスの一部として使用されることが想定されています。
