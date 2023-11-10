const std = @import("std");
const c = @import("constants.zig");
const arm = @import("arm.zig");

/// Helper structure for GPIO hardware.
pub const GPIO = extern struct {
    /// Interface directly with the GPIO hardware. This structure
    /// is mapped to the CPU's MMIO address space.
    pub const resource: Self = @ptrFromInt(c.mmio_base + 0x200000);
    pub const pin_count = 54;
    const Self = *volatile @This();

    gpfsel: [6]u32,
    rsvd0: u32,
    gpset: [2]u32,
    rsvd1: u32,
    gpclr: [2]u32,
    rsvd2: u32,
    gplev: [2]u32,
    rsvd3: u32,
    gpeds: [2]u32,
    rsvd4: u32,
    gpren: [2]u32,
    rsvd5: u32,
    gpfen: [2]u32,
    rsvd6: u32,
    gphen: [2]u32,
    rsvd7: u32,
    gplen: [2]u32,
    rsvd8: u32,
    gparen: [2]u32,
    rsvd9: u32,
    gpafen: [2]u32,
    rsvd10: u32,
    gppud: u32,
    gppudclk: [2]u32,

    comptime {std.debug.assert(@sizeOf(GPIO) == 0xA0);}

    /// Program the specified GPIO `pin` to one of its alternate
    /// function `num`.
    pub fn fnSel(self: Self, pin: u8, num: FnSel) void {
        std.debug.assert(pin < pin_count);
        const idx: usize = pin / 10;
        const sh: u5 = @intCast((pin % 10) * 3);
        const clr: u32 = ~(@as(u32, 7) << sh);
        var temp = self.gpfsel[idx];
        temp &= clr;
        temp |= @as(u32, @intFromEnum(num)) << sh;
        self.gpfsel[idx] = temp;
    }

    /// Query the specified GPIO `pin` for its function.
    pub fn fnSts(self: Self, pin: u8) FnSel {
        std.debug.assert(pin < pin_count);
        const idx: usize = pin / 10;
        const sh: u5 = @intCast((pin % 10) * 3);
        return @enumFromInt((self.gpfsel[idx] >> sh) & 7);
    }

    /// Set the output of the specified GPIO `pin`.
    pub fn set(self: Self, pin: u8) void {
        std.debug.assert(pin < pin_count);
        const idx: usize = if (pin < 32) 0 else 1;
        self.gpset[idx] |= (@as(u32, 1) << @intCast(pin & 31));
    }

    /// Clear the output of the specified GPIO `pin`.
    pub fn clear(self: Self, pin: u8) void {
        std.debug.assert(pin < pin_count);
        const idx: usize = if (pin < 32) 0 else 1;
        self.gpclr[idx] |= (@as(u32, 1) << @intCast(pin & 31));
    }

    /// Query the status of the specified GPIO `pin`.
    pub fn status(self: Self, pin: u8) bool {
        std.debug.assert(pin < pin_count);
        const idx: usize = if (pin < 32) 0 else 1;
        const s = self.gplev[idx] & (@as(u32, 1) << @intCast(pin & 31));
        return s > 0;
    }

    /// Set the pull-up/down state of the given `pin`.
    pub fn pud(self: Self, pin: u8, sel: PUD) void {
        std.debug.assert(sel != .reserved);
        std.debug.assert(pin < pin_count);
        self.gppud = @intFromEnum(sel);
        arm.waitCycles(150);
        const idx: usize = if (pin < 32) 0 else 1;
        self.gppudclk[idx] |= (@as(u32, 1) << @intCast(pin & 31));
        arm.waitCycles(150);
        self.gppud = 0;
        self.gppudclk[idx] = 0;
    }

    /// Set `pin` to generate an interrupt on high voltage.
    pub fn setHighDetect(self: Self, pin: u8) void {
        std.debug.assert(pin < pin_count);
        const idx: usize = if (pin < 32) 0 else 1;
        self.gphen[idx] |= (@as(u32, 1) << @intCast(pin & 31));
    }

    /// Set `pin` to generate an interrupt on low voltage.
    pub fn setLowDetect(self: Self, pin: u8) void {
        std.debug.assert(pin < pin_count);
        const idx: usize = if (pin < 32) 0 else 1;
        self.gplen[idx] |= (@as(u32, 1) << @intCast(pin & 31));
    }
};

/// Available functions for GPIO pins.
pub const FnSel = enum(u3) {
    input,
    output,
    alt5,
    alt4,
    alt0,
    alt1,
    alt2,
    alt3,
};

/// Available pull-down actuations for GPIO pins.
pub const PUD = enum(u2) {
    disable,
    pull_up,
    pull_down,
    reserved,
};
