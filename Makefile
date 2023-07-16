ifndef $(TARGET)
	TARGET = raspi3
endif

ifeq ($(RELEASE), 1)
	OPT = --release
	BUILD = release
else
	BUILD = debug
endif

ifeq ($(TARGET),raspi3)
	RUSTC_MISC_ARGS = -C target-cpu=cortex-a53
else ifeq ($(TARGET),raspi4)
	RUSTC_MISC_ARGS = -C target-cpu=cortex-a72
endif

all: kernel8.img

boot.o: asm/boot.S
	clang --target=aarch64-elf -c $< -o $@

target/aarch64-custom/$(BUILD)/rpi_baremetal: boot.o FORCE
	RUSTFLAGS="$(RUSTC_MISC_ARGS)" cargo +nightly raspi

kernel8.img: target/aarch64-custom/$(BUILD)/rpi_baremetal
	rust-objcopy -O binary target/aarch64-custom/$(BUILD)/rpi_baremetal $@

qemu:
	qemu-system-aarch64 -M raspi3b -kernel kernel8.img -serial stdio -display none -monitor telnet::5556,server,nowait

FORCE:

clean:
	rm -f *.o *.img link-raspi.lds
	cargo clean
