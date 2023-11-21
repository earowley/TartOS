APP_SOURCES = $(wildcard src/*/*.zig) $(wildcard src/*/*/*.zig) $(wildcard src/reset/*.s)
CHAINLOADER_SOURCES = chainloader/main.zig chainloader/reset_vector.s
APP_LINKER = linker.ld
CHAINLOADER_LINKER = chainloader/linker.ld
APP_ELF = zig-out/bin/app
CHAINLOADER_ELF = zig-out/bin/chainloader
APP_IMG = artifacts/app.img
CHAINLOADER_IMG = artifacts/chainloader.img
APP_LOADABLE = artifacts/app.bin

app: $(APP_IMG)
appelf: $(APP_ELF)
chain: $(CHAINLOADER_IMG)
chainelf: $(CHAINLOADER_ELF)
all: app chain

$(APP_IMG): $(APP_ELF)
	llvm-objcopy -O binary $(APP_ELF) $(APP_IMG)

$(APP_ELF): $(APP_SOURCES) $(APP_LINKER)
	zig build

$(CHAINLOADER_IMG): $(CHAINLOADER_ELF)
	llvm-objcopy -O binary $(CHAINLOADER_ELF) $(CHAINLOADER_IMG)

$(CHAINLOADER_ELF): $(CHAINLOADER_SOURCES) $(CHAINLOADER_LINKER)
	zig build

$(APP_LOADABLE): $(APP_IMG)
	scripts/mkload $(APP_IMG) $(APP_LOADABLE)

run: $(APP_IMG)
	qemu-system-aarch64 -M raspi3b -kernel $(APP_IMG) -serial stdio

runfs: $(APP_IMG)
	qemu-system-aarch64 -M raspi3b -kernel $(APP_IMG) -drive file=sdcard.raw,if=sd,format=raw -serial stdio

clean:
	rm -f $(APP_ELF) $(APP_IMG) $(APP_LOADABLE) $(CHAINLOADER_ELF) $(CHAINLOADER_IMG)

reset: clean
	rm -rf zig-cache/
