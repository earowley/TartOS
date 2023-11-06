const std = @import("std");
const hw = @import("hardware");
const mbox = hw.mbox;

/// Possible errors when working with frame buffers.
pub const FrameBufferError = error {
    FirmwareError,
};

/// An interface for creating and interacting with a GPU frame buffer.
pub const FrameBuffer = struct {
    const Self = @This();
    const bits_per_pixel = 32;

    address: usize,
    size: u32,
    width: u32,
    height: u32,
    bytes_per_row: u32,

    /// Use the firmware interface to create a frame buffer.
    pub fn init(width: u32, height: u32,
      pixel_order: mbox.FrameBufferPixelOrder) FrameBufferError!Self {
        const P = mbox.Package(.{
            mbox.SetPhysicalFrameBuffer,
            mbox.SetVirtualFrameBuffer,
            mbox.SetFrameBufferDepth,
            mbox.SetFrameBufferPixelOrder,
            mbox.SetVirtualFrameBufferOffset,
            mbox.AllocateFrameBuffer,
            mbox.GetFrameBufferPitch,
        });
        P.init();
        const phys = P.payload(0);
        phys.width = width;
        phys.height = height;
        const virt = P.payload(1);
        virt.width = width;
        virt.height = height;
        const depth = P.payload(2);
        depth.bits_per_pixel = bits_per_pixel;
        const order = P.payload(3);
        order.load(pixel_order);
        const offset = P.payload(4);
        offset.x = 0;
        offset.y = 0;
        const alloc = P.payload(5);
        alloc.in_align_out_address = 0x1000;

        if (!P.send())
            return FrameBufferError.FirmwareError;

        return .{
            .address = alloc.in_align_out_address,
            .size = alloc.size_bytes,
            .width = phys.width,
            .height = phys.height,
            .bytes_per_row = P.payload(6).bytes_per_row,
        };
    }

    /// Use the firmware interface to destroy the current frame buffer.
    /// This is not tied to any particular instance of FrameBuffer, and
    /// does not always need to be called as there can only be one
    /// frame buffer active. In other words, alling `init` will also
    /// deinit any existing frame buffers.
    pub fn deinit() FrameBufferError!void {
        const P = mbox.Package(.{mbox.ReleaseFrameBuffer});
        P.init();
        if (!P.send())
            return FrameBufferError.FirmwareError;
    }

    /// Get a pointer to the pixel data at the coordinate `x`, `y`.
    pub fn pixelAt(self: Self, x: u32, y: u32) *Pixel {
        return @ptrFromInt(
            self.address + 
            y * self.bytes_per_row + 
            x * @sizeOf(Pixel)
        );
    }
};

/// A union representing all of the possible 32-bit pixel types. The
/// structure chosen should match with the one submitted to
/// `FrameBuffer.init`.
pub const Pixel = extern union {
    bgr: extern struct {
        b: u8,
        g: u8,
        r: u8,
        a: u8,
    },
    rgb: extern struct {
        r: u8,
        g: u8,
        b: u8,
        a: u8,
    },
};
