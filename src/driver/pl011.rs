//! # PL011Uart
//!
//! PL011Uartは、PL011 UARTコントローラを制御するためのモジュールです。
//!
//! ## 使用方法
//!
//! 1. `PL011Uart`構造体の新しいインスタンスを作成します。
//!
//! ```rust
//! let uart = PL011Uart::new(base_address);
//! ```
//!
//! 2. `init`メソッドを使用してUARTを初期化します。
//!
//! ```rust
//! uart.init(baud_rate);
//! ```
//!
//! 3. `Write`トレイトのメソッドを使用して文字列を送信します。
//!
//! ```rust
//! write!(uart, "Hello, UART!");
//! ```
//!
//! ## メソッド
//!
//! ### `new(base_address: u32) -> PL011Uart`
//!
//! `PL011Uart`構造体の新しいインスタンスを生成します。
//!
//! * `base_address` - UARTのベースアドレス
//!
//! ### `init(&self, baud_rate: u32)`
//!
//! UARTを初期化します。
//!
//! * `baud_rate` - ボーレートの値（bps）
//!
//! ### `write_str(&mut self, s: &str) -> Result`
//!
//! 文字列をUART経由で送信します。
//!
//! * `s` - 送信する文字列
//!
//! ## 例
//!
//! ```rust
//! use core::fmt::Write;
//!
//! let uart = PL011Uart::new(base_address);
//! uart.init(115200);
//! writeln!(uart, "Hello, UART!");
//! ```

use core::{
    fmt::{Result, Write},
    ptr::{read_volatile, write_volatile},
};

pub struct PL011Uart {
    base_address: u32,
}

impl PL011Uart {
    /// PL011Uart構造体の新しいインスタンスを生成します。
    ///
    /// # Arguments
    ///
    /// * `base_address` - UARTのベースアドレス
    ///
    /// # Returns
    ///
    /// `PL011Uart`の新しいインスタンス
    pub fn new(base_address: u32) -> PL011Uart {
        PL011Uart { base_address }
    }

    /// UARTを初期化します。
    ///
    /// # Arguments
    ///
    /// * `baud_rate` - ボーレートの値（bps）
    pub fn init(&self, baud_rate: u32) {
        self.disable_uart(); // UARTの無効化

        // ボーレートの設定
        let uartclk = 48_000_000; // UARTクロックの周波数（例: 48MHz）
        let divisor = uartclk / (16 * baud_rate);
        self.set_baud_rate(divisor);

        // 8ビットデータ、パリティ無し、1ストップビットの設定
        self.set_line_control();

        // FIFOの有効化
        self.enable_fifo();

        // UARTの有効化
        self.enable_uart();
    }

    fn read_register(&self, offset: u32) -> u32 {
        unsafe { read_volatile((self.base_address + offset) as *const u32) }
    }

    fn write_register(&self, offset: u32, value: u32) {
        unsafe { write_volatile((self.base_address + offset) as *mut u32, value) };
    }

    fn disable_uart(&self) {
        self.write_register(0x30, 0); // UARTCRレジスタのUARTENビットをクリアして無効化
    }

    fn set_baud_rate(&self, divisor: u32) {
        self.write_register(0x24, divisor & 0xFFFF); // UARTIBRDレジスタに整数部の値を設定
        self.write_register(0x28, divisor >> 16); // UARTFBRDレジスタに小数部の値を設定
    }

    fn set_line_control(&self) {
        let lcr_h = self.read_register(0x2C); // UARTLCR_Hレジスタの現在の値を読み取る
        self.write_register(0x2C, lcr_h | 0x60); // 8ビットデータ、パリティ無し、1ストップビットを設定
    }

    fn enable_fifo(&self) {
        self.write_register(0x30, 0xC5); // FIFO有効化（UARTCRレジスタのFENビットを設定）
    }

    fn enable_uart(&self) {
        self.write_register(0x30, 0x301); // UART有効化（UARTCRレジスタのUARTENおよびTXEビットを設定）
    }
}

impl Write for PL011Uart {
    /// 文字列をUART経由で送信します。
    ///
    /// # Arguments
    ///
    /// * `s` - 送信する文字列
    ///
    /// # Returns
    ///
    /// `Result`型の結果
    fn write_str(&mut self, s: &str) -> Result {
        for byte in s.bytes() {
            self.write_byte(byte);
        }
        Ok(())
    }
}

impl PL011Uart {
    fn write_byte(&mut self, byte: u8) {
        // UARTDRレジスタにバイトデータを書き込む
        self.write_register(0x00, byte as u32);
    }
}
