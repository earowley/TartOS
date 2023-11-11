<p align="center">
    <picture>
      <img src="logo.png" height="256">
    </picture>
    <h1 align="center" style="margin: 0">TartOS</h1>
</p>

## About

TartOS is a bare-metal operating system for the RPi3, written in Zig.
It is inspired by bztsrc's 
[bare metal tutorial](https://github.com/bztsrc/raspi3-tutorial) 
and draws heavily from it. If you're familiar with it already, the
code in this repo should seem very familiar. The goals of this
project are to:
* Achieve the same level of functionality as the bare metal tutorial
* Use Zig features to make hardware interaction nicer
  * Should serve as a nice base for writing a bare metal program

## Building

Building requires the following utils (which may be installed
from a package manager):
* Zig 0.11.0
* make
* llvm (for llvm-objcopy)

To start, check that Zig is correctly setup:
```shell
# This should make an ELF file under zig-out/bin
$ make elf
```

Next, check that llvm-objcopy can create the image file, or use
another solution to do so:
```shell
# This should make an image file called kernel8.img
$ make img
```

## Running

If you have QEMU installed, you can run the OS directly, but keep
in mind that emulation is limited in features:
```shell
$ make run
```

## Resources
* [Tutorial](https://github.com/bztsrc/raspi3-tutorial) - Individual tutorials for kickstarting bare metal development on the Raspberry Pi 3
* [BCM2835 SoC Peripherals](https://www.raspberrypi.org/app/uploads/2012/02/BCM2835-ARM-Peripherals.pdf) - Peripheral manual for Broadcom SoC on Raspberry Pi 3
* [ARM Cortex-A53](https://developer.arm.com/documentation/ddi0500/j) - Documentation for the CPU core on the Raspberry Pi 3
* [ARMv8-A Architecture Registers](https://developer.arm.com/documentation/ddi0595/2021-12?lang=en) - Summary of special registers on the ARMv8-A architecture
* [ARMv8-A Programmer's Guide](https://developer.arm.com/documentation/den0024/a/) - Programmers reference guide for the ARMv8-A architecture
* [Boot Code Examples](https://developer.arm.com/documentation/dai0527/latest/) - Example ASM boot code for the ARMv8-A architecture
