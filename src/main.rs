#![feature(lang_items)]
#![feature(alloc_error_handler)]
#![feature(start)]
#![no_std]
#![no_main]

use core::alloc::Layout;

/// Entry point from assembly code.
#[no_mangle]
pub extern "C" fn kernel_main() -> ! {
    loop {
        core::hint::spin_loop()
    }
}

#[alloc_error_handler]
fn on_oom(_layout: Layout) -> ! {
    loop {
        core::hint::spin_loop()
    }
}

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {
        core::hint::spin_loop()
    }
}
