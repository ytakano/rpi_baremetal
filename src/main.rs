#![feature(lang_items)]
#![feature(alloc_error_handler)]
#![feature(start)]
#![cfg_attr(not(test), no_main)]
#![cfg_attr(not(test), no_std)]

pub mod driver;

#[cfg(not(test))]
use core::alloc::Layout;
use core::fmt::Write;

use driver::gpio::{GPIOFunc, PullUpDown};

/// Entry point from assembly code.
#[no_mangle]
pub extern "C" fn kernel_main(_fdt: usize) -> ! {
    unsafe { init_uart() };

    loop {
        core::hint::spin_loop()
    }
}

#[cfg(not(test))]
#[alloc_error_handler]
fn on_oom(_layout: Layout) -> ! {
    loop {
        core::hint::spin_loop()
    }
}

#[cfg(not(test))]
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {
        core::hint::spin_loop()
    }
}

unsafe fn init_uart() {
    let pin14 = driver::gpio::GPIOPin::new(14);
    pin14.set_pull_up_down(PullUpDown::PullDown);
    pin14.set_function(GPIOFunc::ALT0);

    let pin15 = driver::gpio::GPIOPin::new(15);
    pin15.set_pull_up_down(PullUpDown::PullDown);
    pin15.set_function(GPIOFunc::ALT0);

    // Raspi 3
    #[cfg(feature = "raspi3")]
    let mut pl011 = driver::pl011::PL011Uart::new(0x3f20_1000);

    // Raspi 4
    #[cfg(feature = "raspi4")]
    let pl011 = driver::pl011::PL011Uart::new(0xfe20_1000);

    pl011.init(115200);

    let _ = pl011.write_str("Hello, world!\n");
}
