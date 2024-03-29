const std = @import("std");
const c = @import("constants.zig");
const arm = @import("arm.zig");

/// Helper structure for mailbox interfacing.
pub const Mailbox = extern struct {
    /// Interface directly with the ARM->VC mailbox. This pointer
    /// is mapped to the CPU's MMIO address space.
    pub const resource: Self = @ptrFromInt(c.mmio_base + 0xB880);
    const Self = *volatile @This();
    const mbox_size = 40;
    const chan_arm_to_vc = 8;
    const mbox_full_mask = 0x80000000;
    const mbox_empty_mask = 0x40000000;
    const mbox_request = 0;
    const mbox_response = 0x80000000;
    const send_timeout_us = 100000;
    const SendError = error{Timeout, InvalidResponse};
    var buffer: [mbox_size]u32 align(16) = [1]u32{0} ** mbox_size;

    read: u32,
    rsvd0: [3]u32,
    poll: u32,
    sender: u32,
    status: u32,
    config: u32,
    write: u32,

    fn send(self: Self) SendError!void {
        comptime {std.debug.assert(buffer.len >= 2);}
        // Size of entire message in bytes
        std.debug.assert(buffer[0] > 0);
        // Make sure we're always sending a request
        std.debug.assert(buffer[1] == mbox_request);
        const mb_addr: u32 = @intCast(@intFromPtr(&buffer));
        const wr = mb_addr | chan_arm_to_vc;
        var us: usize = 0;
        while (
            (self.status & mbox_full_mask) != 0 and
            us < send_timeout_us
        ) : (us += 1) {
            arm.usleep(1);
        }
        if (us == send_timeout_us)
            return SendError.Timeout;
        self.write = wr;

        while (true) {
            us = 0;
            while (
                (self.status & mbox_empty_mask) != 0 and
                us < send_timeout_us
            ) : (us += 1) {
                arm.usleep(1);
            }
            if (us == send_timeout_us)
                return SendError.Timeout;
            if (wr == self.read) {
                if (buffer[1] != mbox_response)
                    return SendError.InvalidResponse;
                return;
            }
        }
    }

    fn mboxFatal(err: SendError) noreturn {
        std.debug.panic("Got unexpected firmware error in mailbox " ++
            "interface: {}", .{err});
    }

    /// Retrieve the system's serial number from the mailbox.
    pub fn serialNumber() u64 {
        const T = Package(.{SerialNumber});
        T.init();
        T.send();
        return T.payload(0).serial();
    }

    /// Retrieve the current firmware revision from the mailbox.
    pub fn firmwareRevision() u32 {
        const T = Package(.{FirmwareRevision});
        T.init();
        T.send();
        return T.payload(0).firmware_revision;
    }

    /// Retrieve a `MemoryInfo` structure that defines the boundaries
    /// of ARM and VC memory.
    pub fn meminfo() MemoryInfo {
        const T = Package(.{GetARMMemory, GetVCMemory});
        T.init();
        T.send();
        const arm_info = T.payload(0);
        const vc_info = T.payload(1);
        const a: [*]allowzero u8 = @ptrFromInt(arm_info.base);
        const v: [*]allowzero u8 = @ptrFromInt(vc_info.base);
        return .{
            .arm = a[0..arm_info.size],
            .vc = v[0..vc_info.size],
        };
    }

    /// Retrieve the clock speed (in Hz) of `clock` from the mailbox.
    pub fn clockSpeed(clock: ClockID) u32 {
        const T = Package(.{GetClockSpeed});
        T.init();
        T.payload(0).id = clock;
        T.send();
        return T.payload(0).speed;
    }

    /// Retrieve the measured clock speed (in Hz) of `clock` from the
    /// mailbox. This may not work on QEMU.
    pub fn clockSpeedEx(clock: ClockID) u32 {
        const T = Package(.{GetClockSpeedEx});
        T.init();
        T.payload(0).id = clock;
        T.send();
        return T.payload(0).speed;
    }

    /// Set the clock speed of `clock` to the specified frequency `hz`.
    /// Turbo settings are automatically adjusted by the firmware.
    pub fn setClockSpeed(clock: ClockID, hz: u32) u32 {
        const T = Package(.{SetClockSpeed});
        T.init();
        const scs = T.payload(0);
        scs.id = clock;
        scs.speed = hz;
        T.send();
        return scs.speed;
    }
};

const Tag = enum(u32) {
    terminator = 0x0,
    get_firmware_revision = 0x1,
    get_serial = 0x10004,
    get_arm_memory = 0x10005,
    get_vc_memory = 0x10006,
    get_clock_rate = 0x30002,
    get_clock_rate_measured = 0x30047,
    set_clock_rate = 0x38002,
    allocate_frame_buffer = 0x40001,
    blank_screen = 0x40002,
    release_frame_buffer = 0x48001,
    set_physical_frame_buffer = 0x48003,
    set_virtual_frame_buffer = 0x48004,
    set_frame_buffer_depth = 0x48005,
    set_frame_buffer_pixel_order = 0x48006,
    get_frame_buffer_pitch = 0x40008,
    set_virtual_frame_buffer_offset = 0x48009,
};

/// Memory information encoded as slices.
pub const MemoryInfo = struct {
    arm: []allowzero u8,
    vc: []allowzero u8,
};

/// Possible pixel orders for the GPU frame buffer.
pub const FrameBufferPixelOrder = enum(u32) {
    bgr,
    rgb,
};

/// Clocks for interfacing with the mailbox.
pub const ClockID = enum(u32) {
    reserved,
    emmc,
    uart,
    arm,
    system,
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

/// Header for mailbox requests.
pub const RequestHeader = extern struct {
    bytes: u32,
    kind: u32 = Mailbox.mbox_request,
};

/// Get serial number tag information.
pub const SerialNumber = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.get_serial),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    serial_low: u32 = 0,
    serial_high: u32 = 0,

    pub fn serial(self: Self) u64 {
        return (@as(u64, self.serial_high) << 32) | self.serial_low;
    }
};

/// Get ARM memory information.
pub const GetARMMemory = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.get_arm_memory),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    base: u32 = 0,
    size: u32 = 0,
};

/// Get VC memory information.
pub const GetVCMemory = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.get_vc_memory),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    base: u32 = 0,
    size: u32 = 0,
};

/// Get firmware revision tag information.
pub const FirmwareRevision = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.get_firmware_revision),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    firmware_revision: u32 = 0,
};

/// Get clock speed tag information.
pub const GetClockSpeed = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.get_clock_rate),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    id: ClockID = undefined,
    speed: u32 = 0,
};

/// Get measured clock speed tag information.
pub const GetClockSpeedEx = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.get_clock_rate_measured),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    id: ClockID = undefined,
    speed: u32 = 0,
};

/// Set clock speed tag information.
pub const SetClockSpeed = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.set_clock_rate),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    id: ClockID = undefined,
    speed: u32 = 0,
    turbo: u32 = 0,
};

/// Allocate frame buffer tag information.
pub const AllocateFrameBuffer = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.allocate_frame_buffer),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    in_align_out_address: u32 = undefined,
    size_bytes: u32 = 0,
};

/// Blank screen tag information.
pub const BlankScreen = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.allocate_frame_buffer),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    state: u32 = undefined,
};

/// Release frame buffer tag information.
pub const ReleaseFrameBuffer = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.release_frame_buffer),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
};

/// Set physical frame buffer tag information.
pub const SetPhysicalFrameBuffer = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.set_physical_frame_buffer),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    width: u32 = undefined,
    height: u32 = undefined,
};

/// Set virtual frame buffer tag information.
pub const SetVirtualFrameBuffer = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.set_virtual_frame_buffer),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    width: u32 = undefined,
    height: u32 = undefined,
};

/// Set frame buffer depth tag information.
pub const SetFrameBufferDepth = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.set_frame_buffer_depth),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    bits_per_pixel: u32 = undefined,
};

/// Set frame buffer pixel order tag information.
pub const SetFrameBufferPixelOrder = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.set_frame_buffer_pixel_order),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    pixel_order: u32 = undefined,

    pub fn load(self: *volatile Self, order: FrameBufferPixelOrder)
      void {
        self.pixel_order = @intFromEnum(order);
    }
};

/// Set frame buffer pixel order tag information.
pub const GetFrameBufferPitch = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.get_frame_buffer_pitch),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    bytes_per_row: u32 = 0,
};

/// Set frame buffer pixel order tag information.
pub const SetVirtualFrameBufferOffset = extern struct {
    const Self = @This();
    const len = @sizeOf(Self) / @sizeOf(u32);

    tag: u32 = @intFromEnum(Tag.set_virtual_frame_buffer_offset),
    buf_bytes: u32 = @sizeOf(Self) - 12,
    kind: u32 = Mailbox.mbox_request,
    x: u32 = undefined,
    y: u32 = undefined,
};

/// Convenience structure for sending mailbox "packages". A mailbox
/// package is one or more mailbox requests to be encoded and sent to
/// VC firmware. All fields that have default or calculatable values
/// will be automatically initialized at compile time or init() time.
/// Variable fields must be initialized before sending. A pointer to
/// each tag can be requested via the payload(idx) function, where
/// idx is the index of the payload from the initialization tuple of
/// this structure.
pub fn Package(comptime payloads: anytype) type {
    return struct {
        const Self = @This();
        const len = blk: {
            // Header, terminating tag
            var val = @sizeOf(RequestHeader) / 4 + 1;
            for (payloads) |T| {
                val += T.len;
            }
            break :blk val;
        };

        comptime {std.debug.assert(Mailbox.mbox_size >= (len));}

        const offsets = blk: {
            var val = [1]comptime_int{0} ** payloads.len;
            var off = @sizeOf(RequestHeader) / 4;
            for (payloads, 0..) |T, idx| {
                val[idx] = off;
                off += T.len;
            }
            break :blk val;
        };

        /// Initialize the buffer. Must be called for each package.
        pub fn init() void {
            const header: *RequestHeader = @ptrCast(&Mailbox.buffer[0]);
            header.bytes = len * @sizeOf(u32);
            header.kind = Mailbox.mbox_request;
            inline for (0..payloads.len) |idx| {
                payload(idx).* = payloads[idx]{};
            }
        }

        /// Get the raw data of the buffer.
        pub fn data() []u32 {
            return Mailbox.buffer[0..len];
        }

        /// Get a pointer to the tag in the specified index `n`.
        pub fn payload(comptime n: comptime_int)
          *volatile payloads[n] {
            return @ptrCast(&Mailbox.buffer[offsets[n]]);
        }

        /// Send the package to the VC mailbox.
        pub fn send() void {
            Mailbox.resource.send() catch |err| Mailbox.mboxFatal(err);
        }
    };
}
