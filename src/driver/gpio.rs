//! # GPIOモジュール
//!
//! ## モジュール概要
//!
//! GPIO操作を行うためのライブラリです。このモジュールでは、GPIOピンの機能設定とプルアップ/プルダウンの設定を行うための関数と構造体を提供します。
//!
//! ### 列挙型
//!
//! #### `GPIOFunc`
//!
//! GPIOピンの機能設定を表す列挙型です。
//!
//! - `INPUT`: 入力モード
//! - `OUTPUT`: 出力モード
//! - `ALT0`〜`ALT5`: 代替機能モード
//!
//! #### `PullUpDown`
//!
//! GPIOピンのプルアップおよびプルダウン設定を表す列挙型です。
//!
//! - `None`: プルアップおよびプルダウンを無効化
//! - `PullDown`: プルダウンを有効化
//! - `PullUp`: プルアップを有効化
//!
//! ### 構造体
//!
//! #### `GPIOPin`
//!
//! GPIOピンを表す構造体です。
//!
//! ##### フィールド
//!
//! - `pin_number`: ピン番号
//!
//! ##### メソッド
//!
//! - `set_function(func: GPIOFunc)`: GPIOピンの機能を設定します。
//! - `set_pull_up_down(pud: PullUpDown)`: GPIOピンのプルアップまたはプルダウンを設定します。
//!
//! ### 関数
//!
//! #### `to_u32_ptr_mut(address: u32) -> *mut u32`
//!
//! アドレスをu32の可変ポインタに変換するためのヘルパー関数です。
//!
//! #### `wait_cycles(cycles: u32)`
//!
//! 指定されたサイクル数だけ待機するための関数です。
//!
//! ## 使用例
//!
//! ```rust
//! let pin = GPIOPin { pin_number: 12 };
//! pin.set_function(GPIOFunc::OUTPUT);
//! pin.set_pull_up_down(PullUpDown::PullDown);
//! ```
//!
//! この例では、ピン番号12のGPIOピンを出力モードに設定し、プルダウンを有効化しています。

use core::{
    arch::asm,
    ptr::{read_volatile, write_volatile},
};

const GPIO_BASE_ADDRESS: u32 = 0x3f20_0000; // GPIOのベースアドレス, Raspberry Pi 3

// const GPIO_BASE_ADDRESS: u32 = 0xfe20_0000; // GPIOのベースアドレス, Raspberry Pi 4

/// GPIOの機能設定を表す列挙型
pub enum GPIOFunc {
    INPUT = 0b000,
    OUTPUT = 0b001,
    ALT0 = 0b100,
    ALT1 = 0b101,
    ALT2 = 0b110,
    ALT3 = 0b111,
    ALT4 = 0b011,
    ALT5 = 0b010,
}

/// GPIOピンのプルアップおよびプルダウン設定を表す列挙型
pub enum PullUpDown {
    None = 0b00,
    PullDown = 0b01,
    PullUp = 0b10,
}

/// GPIOピンを表す構造体
pub struct GPIOPin {
    pin_number: u32,
}

impl GPIOPin {
    pub fn new(pin_number: u32) -> Self {
        Self { pin_number }
    }

    /// GPIOピンの機能を設定します。
    ///
    /// # Arguments
    ///
    /// * `func` - GPIOピンの機能設定
    pub fn set_function(&self, func: GPIOFunc) {
        let register_offset = self.pin_number / 10;
        let field_offset = (self.pin_number % 10) * 3;

        let register_address = GPIO_BASE_ADDRESS + register_offset * 4;
        let register_ptr = to_u32_ptr_mut(register_address);
        let mut value = unsafe { read_volatile(register_ptr) };

        value &= !(0b111 << field_offset);
        value |= (func as u32) << field_offset;

        unsafe { write_volatile(register_ptr, value) };
    }

    /// GPIOピンのプルアップまたはプルダウンを設定します。
    ///
    /// # Arguments
    ///
    /// * `pud` - プルアップまたはプルダウンの設定
    pub fn set_pull_up_down(&self, pud: PullUpDown) {
        let register_offset = self.pin_number / 32;

        let gppud_register_address = GPIO_BASE_ADDRESS + register_offset * 4;
        let gppudclk_register_address = GPIO_BASE_ADDRESS + register_offset * 4 + 0x94;

        let gppud_register_ptr = to_u32_ptr_mut(gppud_register_address);
        let gppudclk_register_ptr = to_u32_ptr_mut(gppudclk_register_address);

        unsafe {
            // Write to GPPUD
            write_volatile(gppud_register_ptr, pud as u32);

            // Wait 150 cycles
            wait_cycles(150);

            // Write to GPPUDCLK0/1
            let mask = 1 << (self.pin_number % 32);
            write_volatile(gppudclk_register_ptr, mask);

            // Wait 150 cycles
            wait_cycles(150);

            // Write to GPPUD to remove the control signal
            write_volatile(gppud_register_ptr, 0);

            // Write to GPPUDCLK0/1 to remove the clock
            write_volatile(gppudclk_register_ptr, 0);
        }
    }
}

/// アドレスをu32の可変ポインタに変換します。
fn to_u32_ptr_mut(address: u32) -> *mut u32 {
    address as *mut u32
}

/// 指定されたサイクル数だけ待機します。
fn wait_cycles(cycles: u32) {
    for _ in 0..cycles {
        unsafe {
            asm!("nop");
        }
    }
}
