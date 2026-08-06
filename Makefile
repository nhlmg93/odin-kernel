ODIN := odin
BUILD_DIR := build
TARGET := $(BUILD_DIR)/kernal
ODIN_FLAGS := -target:freestanding_amd64_sysv \
	-default-to-nil-allocator \
	-build-mode:obj \
	-use-single-module \
	-no-thread-local \
	-disable-red-zone \
	-no-crt
OBJECT := $(BUILD_DIR)/kernal.obj
KERNEL := $(BUILD_DIR)/kernal.elf
ISO_ROOT := $(BUILD_DIR)/iso-root
ISO := $(BUILD_DIR)/kernal.iso
LIMINE_DIR := /usr/share/limine
ASM_OBJECT := $(BUILD_DIR)/io.o

.PHONY: all object build run check fmt clean help

all: build

object: $(ASM_OBJECT)
	@mkdir -p $(BUILD_DIR)
	$(ODIN) build . $(ODIN_FLAGS) -out:$(OBJECT)

$(ASM_OBJECT): io.S
	@mkdir -p $(BUILD_DIR)
	clang -target x86_64-none-elf -c io.S -o $(ASM_OBJECT)

build: object linker.ld
	ld.lld -T linker.ld -o $(KERNEL) $(OBJECT) $(ASM_OBJECT)

iso: build limine.conf
	rm -rf $(ISO_ROOT)
	mkdir -p $(ISO_ROOT)/boot $(ISO_ROOT)/EFI/BOOT
	cp $(KERNEL) $(ISO_ROOT)/boot/kernal.elf
	cp limine.conf $(ISO_ROOT)/
	cp $(LIMINE_DIR)/limine-bios.sys \
	   $(LIMINE_DIR)/limine-bios-cd.bin \
	   $(LIMINE_DIR)/limine-uefi-cd.bin \
	   $(ISO_ROOT)/
	cp $(LIMINE_DIR)/BOOTX64.EFI $(ISO_ROOT)/EFI/BOOT/
	xorriso -as mkisofs -R -r -J \
	   -b limine-bios-cd.bin \
	   -no-emul-boot -boot-load-size 4 -boot-info-table \
	   -hfsplus -apm-block-size 2048 \
	   --efi-boot limine-uefi-cd.bin \
	   -efi-boot-part --efi-boot-image --protective-msdos-label \
	   $(ISO_ROOT) -o $(ISO)
	limine bios-install $(ISO)

run: iso
	qemu-system-x86_64 \
		 -M q35 \
		 -m 128M \
		 -cdrom $(ISO) \
		 -boot d \
		 -display none \
		 -serial stdio \
		 -monitor none \
		 -no-reboot \
		 -no-shutdown

debug: iso
	qemu-system-x86_64 \
		 -M q35 \
		 -m 128M \
		 -cdrom $(ISO) \
		 -boot d \
		 -display none \
		 -serial stdio \
		 -monitor none \
		 -no-reboot \
		 -no-shutdown \
		 -S \
		 -gdb tcp::1234

check:
	$(ODIN) check .

fmt:
	@command -v odinfmt >/dev/null || { echo "odinfmt is not installed; run: sudo pacman -S odinfmt"; exit 1; }
	odinfmt -w .

clean:
	rm -rf $(BUILD_DIR)
