ZIG_SOURCES = $(wildcard src/**/*.zig) src/main.zig
ASM_SOURCES = $(wildcard src/asm/*.s)
ELF = zig-out/bin/rpi
IMG = kernel8.img

img: $(IMG)
elf: $(ELF)

$(IMG): $(ELF)
	llvm-objcopy -O binary $(ELF) $(IMG)

$(ELF): $(ZIG_SOURCES) $(ASM_SOURCES)
	zig build

run: $(IMG)
	qemu-system-aarch64 -M raspi3b -kernel kernel8.img -d in_asm

clean:
	rm -f $(ELF) $(IMG)
