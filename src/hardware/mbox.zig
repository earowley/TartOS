const std = @import("std");
const c = @import("constants.zig");

pub const mbox: *volatile Mailbox = @ptrFromInt(c.mmio_base + 0xB880);

pub const Mailbox = extern struct {
    const Self = *volatile @This();
    const mbox_size = 16;
    const chan_arm_to_vc = 8;
    const mbox_full_mask = 0x80000000;
    const mbox_empty_mask = 0x40000000;
    const mbox_request = 0;
    const mbox_response = 0x80000000;
    var buffer: [mbox_size]u32 align(16) = [1]u32{0} ** mbox_size;

    read: u32,
    rsvd0: [3]u32,
    poll: u32,
    sender: u32,
    status: u32,
    config: u32,
    write: u32,

    fn send(self: Self) bool {
        comptime {std.debug.assert(buffer.len >= 2);}
        const mb_addr: u32 = @intCast(@intFromPtr(&buffer));
        const wr = mb_addr | chan_arm_to_vc;
        while ((self.status & mbox_full_mask) != 0) {}
        self.write = wr;

        while (true) {
            while ((self.status & mbox_empty_mask) != 0) {}
            if (wr == self.read)
                return buffer[1] == mbox_response;
        }

        unreachable;
    }

    pub fn serialNumber(self: Self) u64 {
        buffer[0] = 8 * @sizeOf(u32);
        buffer[1] = mbox_request;
        buffer[2] = @intFromEnum(Tag.get_serial);
        buffer[3] = 8;
        buffer[4] = mbox_request;
        buffer[5] = 0;
        buffer[6] = 0;
        buffer[7] = @intFromEnum(Tag.terminator);

        const rb: *volatile @TypeOf(buffer) = &buffer;

        if (self.send())
            return (@as(u64, rb[6]) << 32) | rb[5];

        return 0xDEADBEEF;
    }

    pub fn firmwareRevision(self: Self) u32 {
        buffer[0] = 7 * @sizeOf(u32);
        buffer[1] = mbox_request;
        buffer[2] = @intFromEnum(Tag.get_firmware_revision);
        buffer[3] = 4;
        buffer[4] = mbox_request;
        buffer[5] = 0;
        buffer[6] = @intFromEnum(Tag.terminator);

        if (self.send())
            return buffer[5];

        return 0xDEADBEEF;
    }

    pub fn clockSpeed(self: Self, clock: ClockID) u32 {
        buffer[0] = 8 * @sizeOf(u32);
        buffer[1] = mbox_request;
        buffer[2] = @intFromEnum(Tag.get_clock_rate);
        buffer[3] = 8;
        buffer[4] = mbox_request;
        buffer[5] = @intFromEnum(clock);
        buffer[6] = 0;
        buffer[7] = @intFromEnum(Tag.terminator);

        const rb: *volatile @TypeOf(buffer) = &buffer;

        if (self.send())
            return rb[6];

        return 0xDEADBEEF;
    }

    pub fn clockSpeedEx(self: Self, clock: ClockID) u32 {
        buffer[0] = 8 * @sizeOf(u32);
        buffer[1] = mbox_request;
        buffer[2] = @intFromEnum(Tag.get_clock_rate_measured);
        buffer[3] = 8;
        buffer[4] = mbox_request;
        buffer[5] = @intFromEnum(clock);
        buffer[6] = 0;
        buffer[7] = @intFromEnum(Tag.terminator);

        const rb: *volatile @TypeOf(buffer) = &buffer;

        if (self.send())
            return rb[6];

        return 0xDEADBEEF;
    }

    pub fn setClockSpeed(self: Self, clock: ClockID, hz: u32) u32 {
        buffer[0] = 9 * @sizeOf(u32);
        buffer[1] = mbox_request;
        buffer[2] = @intFromEnum(Tag.set_clock_rate);
        buffer[3] = 12;
        buffer[4] = mbox_request;
        buffer[5] = @intFromEnum(clock);
        buffer[6] = hz;
        buffer[7] = 0;
        buffer[8] = @intFromEnum(Tag.terminator);

        const rb: *volatile @TypeOf(buffer) = &buffer;

        if (self.send())
            return rb[6];

        return 0xDEADBEEF;
    }
};

pub const Tag = enum(u32) {
    terminator = 0x0,
    get_firmware_revision = 0x1,
    get_serial = 0x10004,
    get_clock_rate = 0x30002,
    get_clock_rate_measured = 0x30047,
    set_clock_rate = 0x38002,
};

pub const ClockID = enum(u32) {
    reserved,
    emmc,
    uart,
    arm,
    core,
    v3d,
    h264,
    isp,
    sdram,
    pixel,
    pwm,
    hevc,
    emmc2,
    m2mc,
    pixel_bvb,
};
