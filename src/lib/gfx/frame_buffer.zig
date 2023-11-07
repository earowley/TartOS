const std = @import("std");
const hw = @import("hardware");
const mbox = hw.mbox;

/// Possible errors when working with frame buffers.
pub const FrameBufferError = error {
    FirmwareError,
};

/// An interface for creating and interacting with a GPU frame buffer.
pub const FrameBuffer = struct {
    const bits_per_pixel = 32;

    address: usize,
    size: u32,
    width: u32,
    height: u32,
    bytes_per_row: u32,

    /// Use the firmware interface to create a frame buffer.
    pub fn init(
        width: u32,
        height: u32,
        pixel_order: mbox.FrameBufferPixelOrder
    ) FrameBufferError!FrameBuffer {
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

    /// Get a pointer to the pixel data at the coordinate `x`, `y` or
    /// null if the pixel does not exist.
    pub fn pixelAt(self: FrameBuffer, x: u32, y: u32) ?*Pixel {
        if (x >= self.width or y >= self.height)
            return null;
        return self.pixelAtUnchecked(x, y);
    }

    /// Get a pointer to the pixel data at the coordinate `x`, `y`.
    pub fn pixelAtUnchecked(self: FrameBuffer, x: u32, y: u32) *Pixel {
        return @ptrFromInt(
            self.address + 
            y * self.bytes_per_row + 
            x * @sizeOf(Pixel)
        );
    }
};

/// Possible errors working with Grids.
pub const GridError = error {
    InvalidSpecification
};

/// Frame buffer abstraction that makes it easier to work with simple
/// grid configurations.
pub const Grid = struct {
    buffer: *const FrameBuffer,
    width: u16,
    height: u16,
    section_width: u16,
    section_height: u16,
    pad_x: u16,
    pad_y: u16,
    spacing: u8,

    /// Create a grid of sections with size `section_width`,
    /// `section_height`. Padding in `pad_x` is the distance from the
    /// left and right sides of the frame, and `pad_y` is the distance
    /// from the top and bottom of the frame. Spacing is the distance
    /// between sections on all sides.
    pub fn init(
        frame_buffer: *const FrameBuffer,
        section_width: u16,
        section_height: u16,
        pad_x: u16,
        pad_y: u16,
        spacing: u8
    ) GridError!Grid {
        if (section_width == 0 or section_height == 0)
            return GridError.InvalidSpecification;
        const rem_x: u16 = @intCast(frame_buffer.width - 2 * pad_x);
        const rem_y: u16 = @intCast(frame_buffer.height - 2 * pad_y);
        if (section_width > rem_x or section_height > rem_y)
            return GridError.InvalidSpecification;

        return Grid {
            .buffer = frame_buffer,
            .width = subdivideScreen(rem_x, section_width, spacing),
            .height = subdivideScreen(rem_y, section_height, spacing),
            .section_width = section_width,
            .section_height = section_height,
            .pad_x = pad_x,
            .pad_y = pad_y,
            .spacing = spacing,
        };
    }

    /// Gets an iterator over the pixels in the grid section at `x`,
    /// `y`.
    pub fn gridSectionUnchecked(self: *const Grid, x: u16, y: u16)
      GridSectionIterator {
        return GridSectionIterator {
            .grid = self,
            .pixel = @ptrFromInt(
                self.buffer.address +
                self.pad_y * self.buffer.bytes_per_row +
                y * (self.section_height + self.spacing) *
                  self.buffer.bytes_per_row +
                (self.pad_x + x * (self.section_width + self.spacing)) *
                  @sizeOf(Pixel)
            ),
        };
    }
};

/// An iterator over the pixels in a grid section.
pub const GridSectionIterator = struct {
    grid: *const Grid,
    pixel: [*]Pixel,
    x: u16 = 0,
    y: u16 = 0,

    /// Get the next pixel in this section, or null if there are no
    /// more pixels.
    pub fn next(self: *GridSectionIterator) ?*Pixel {
        if (self.x >= self.grid.section_width) {
            self.y += 1;
            if (self.y >= self.grid.section_height) {
                return null;
            }
            self.x = 0;
            self.pixel +=
                self.grid.buffer.bytes_per_row / @sizeOf(Pixel) -
                self.grid.section_width;
        }
        const result = &(self.pixel[0]);
        self.x += 1;
        self.pixel += 1;
        return result;
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

fn subdivideScreen(size: u16, section_size: u16, spacing: u16) u16 {
    const adj_seg = section_size + spacing;
    const minimum = size / adj_seg;
    const rem = size % adj_seg;
    return minimum + @as(u16, if (rem >= section_size) 1 else 0);
}
