const std = @import("std");
const hw = @import("hardware");
const Iterator = @import("../iterator.zig").Iterator;
const mbox = hw.mbox;

/// An interface for creating and interacting with a GPU frame buffer.
pub const FrameBuffer = struct {
    const bits_per_pixel = 32;
    const bytes_per_pixel = bits_per_pixel / 8;

    address: usize,
    size: u32,
    bytes_per_row: u32,
    width: u16,
    height: u16,

    /// Use the firmware interface to create a frame buffer.
    pub fn init(
        width: u16,
        height: u16,
        pixel_order: mbox.FrameBufferPixelOrder
    ) FrameBuffer {
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

        P.send();

        return .{
            .address = alloc.in_align_out_address,
            .size = alloc.size_bytes,
            .width = @intCast(phys.width),
            .height = @intCast(phys.height),
            .bytes_per_row = P.payload(6).bytes_per_row,
        };
    }

    /// Use the firmware interface to destroy the current frame buffer.
    /// This is not tied to any particular instance of FrameBuffer, and
    /// does not always need to be called as there can only be one
    /// frame buffer active. In other words, calling `init` will also
    /// deinit any existing frame buffer.
    pub fn deinit() void {
        const P = mbox.Package(.{mbox.ReleaseFrameBuffer});
        P.init();
        P.send();
    }

    /// Get the raw pixel data of this frame buffer.
    pub fn pixelData(self: FrameBuffer) []Pixel {
        var result: []Pixel = undefined;
        result.ptr = @ptrFromInt(self.address);
        result.len = self.size / bytes_per_pixel;
        return result;
    }

    /// Get a pointer to the pixel data at the coordinate `x`, `y` or
    /// null if the pixel does not exist.
    pub fn pixelAt(self: FrameBuffer, x: u16, y: u16) ?*Pixel {
        if (x >= self.width or y >= self.height)
            return null;
        return self.pixelAtUnchecked(x, y);
    }

    /// Get a pointer to the pixel data at the coordinate `x`, `y`.
    pub fn pixelAtUnchecked(self: FrameBuffer, x: u16, y: u16) *Pixel {
        return @ptrFromInt(
            self.address + 
            y * self.bytes_per_row + 
            x * bytes_per_pixel
        );
    }

    /// Get the raw pixel data in bytes from rows [`start`, `end`).
    pub fn rowDataUnchecked(self: FrameBuffer, start: u16, end: u16)
      []u8 {
        const length = end - start;
        const p: [*]u8 = @ptrFromInt(
            self.address + start * self.bytes_per_row
        );
        return p[0..length*self.bytes_per_row];
    }

    /// Get an iterator over the pixels of a rectangle starting at
    /// coordinates `x`, `y` with dimensions `width` and `height`.
    pub fn iterRect(
        self: *const FrameBuffer,
        x: u16,
        y: u16,
        width: u16,
        height: u16
    ) Iterator(*Pixel, RectIterContext, RectIterContext.nextFn) {
        return .{
            .cxt = .{
                .fb = self,
                .width = width,
                .height = height,
                .off_x = x,
                .off_y = y,
            }
        };
    }
};

const RectIterContext = struct {
    fb: *const FrameBuffer,
    width: u16,
    height: u16,
    off_x: u16,
    off_y: u16,
    x: u16 = 0,
    y: u16 = 0,

    fn nextFn(cxt: *RectIterContext) ?*Pixel {
        if (cxt.y >= cxt.height) return null;
        const result = cxt.fb.pixelAt(cxt.off_x + cxt.x,
            cxt.off_y + cxt.y);
        cxt.x += 1;
        if (cxt.x >= cxt.width) {
            cxt.x = 0;
            cxt.y += 1;
        }
        return result;
    }
};

/// Possible errors working with Grids.
pub const GridError = error {
    InvalidSpecification,
    UnsupportedFrame,
    ZeroSections,
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
        const max_pad = std.math.maxInt(u16) / 2;
        const max_dim = std.math.maxInt(u16);
        const sub_x = pad_x << 1;
        const sub_y = pad_y << 1;
        if (
            section_width == 0 or
            section_height == 0 or
            pad_x > max_pad or
            pad_y > max_pad or
            frame_buffer.width < sub_x or
            frame_buffer.height < sub_y
        )
            return GridError.InvalidSpecification;
        if (
            frame_buffer.width > max_dim or
            frame_buffer.height > max_dim
        )
            return GridError.UnsupportedFrame;
        const rem_x = frame_buffer.width - sub_x;
        const rem_y = frame_buffer.height - sub_y;
        if (section_width > rem_x or section_height > rem_y)
            return GridError.ZeroSections;

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

    /// Get the raw pixel data in bytes from grid rows [`start`, `end`).
    pub fn rowDataUnchecked(self: Grid, start: u16, end: u16) []u8 {
        return self.buffer.rowDataUnchecked(
            self.pad_y + start * (self.spacing + self.section_height),
            self.pad_y + end * (self.spacing + self.section_height));
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
        const result = &self.pixel[0];
        self.x += 1;
        self.pixel += 1;
        return result;
    }
};

/// A union representing all of the possible 32-bit pixel types. The
/// structure chosen should match with the one submitted to
/// `FrameBuffer.init`.
pub const Pixel = extern union {
    val: u32,
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

    comptime {
        std.debug.assert(@sizeOf(Pixel) == FrameBuffer.bytes_per_pixel);
    }
};

fn subdivideScreen(size: u16, section_size: u16, spacing: u16) u16 {
    const adj_seg = section_size + spacing;
    const minimum = size / adj_seg;
    const rem = size % adj_seg;
    return minimum + @as(u16, if (rem >= section_size) 1 else 0);
}
