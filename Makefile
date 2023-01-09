ifndef $(TARGET)
	TARGET = raspi3
endif

ifeq ($(RELEASE), 1)
	OPT = --release
	BUILD = release
else
	BUILD = debug
endif

# 2MiB Stack
STACKSIZE = 1024 * 1024 * 2

# 4 CPUs
NUMCPU = 4

ifeq ($(TARGET),raspi3)
	RUSTC_MISC_ARGS = -C target-cpu=cortex-a53
	INITADDR = 0x80000
else ifeq ($(TARGET),raspi4)
	RUSTC_MISC_ARGS = -C target-cpu=cortex-a72
	INITADDR = 0
endif

FORCE:

all: kernel8.img

boot.o: asm/boot.S
	clang --target=aarch64-elf -c $< -o $@ -D$(TARGET) -DSTACKSIZE="$(STACKSIZE)"

link-raspi.lds: link.lds
	sed "s/#INITADDR#/$(INITADDR)/" $< | sed "s/#STACKSIZE#/$(STACKSIZE)/" | sed "s/#NUMCPU#/$(NUMCPU)/" > $@

target/aarch64-custom/$(BUILD)/rpi_baremetal: boot.o link-raspi.lds FORCE
	RUSTFLAGS="$(RUSTC_MISC_ARGS)" cargo +nightly raspi3

kernel8.img: target/aarch64-custom/$(BUILD)/rpi_baremetal
	rust-objcopy -O binary target/aarch64-custom/$(BUILD)/rpi_baremetal $@

qemu:
	qemu-system-aarch64 -M raspi3b -kernel kernel8.img -serial stdio -display none -monitor telnet::5556,server,nowait

clean:
	rm -f *.o *.img link-raspi.lds
	cargo clean
