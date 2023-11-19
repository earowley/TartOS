ZIG_SOURCES = $(wildcard src/*/*.zig) $(wildcard src/*/*/*.zig)
ASM_SOURCES = $(wildcard src/reset/*.s)
LINKER = linker.ld
ELF = zig-out/bin/rtos
IMG = kernel8.img

img: $(IMG)
elf: $(ELF)

$(IMG): $(ELF)
	llvm-objcopy -O binary $(ELF) $(IMG)

$(ELF): $(ZIG_SOURCES) $(ASM_SOURCES) $(LINKER)
	zig build

run: $(IMG)
	qemu-system-aarch64 -M raspi3b -kernel kernel8.img -serial stdio

runfs: $(IMG)
	qemu-system-aarch64 -M raspi3b -kernel kernel8.img -drive file=sdcard.raw,if=sd,format=raw -serial stdio

clean:
	rm -f $(ELF) $(IMG)

reset: clean
	rm -rf zig-cache/
