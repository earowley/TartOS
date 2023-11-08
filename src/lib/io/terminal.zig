const std = @import("std");
const gfx = @import("../gfx/gfx.zig");

/// Possible errors when working with Terminals.
pub const TerminalError = gfx.GridError || error {
    UnsupportedGlyphs,
};

/// Writer abstraction type for Terminals.
pub const TerminalWriter = std.io.Writer(*Terminal, TerminalError,
    Terminal.doWriter);

/// A terminal backed by a `FrameBuffer` for rendering.
pub const Terminal = struct {
    grid: gfx.Grid,
    font: *const gfx.PCScreenFont,
    background: gfx.Pixel = .{.val = 0},
    foreground: gfx.Pixel = .{.val = 0xFFFFFFFF},
    cursor_x: u16 = 0,
    cursor_y: u16 = 0,

    /// Create a terminal with the specified `Grid` parameters.
    pub fn init(
        frame_buffer: *const gfx.FrameBuffer,
        font: *const gfx.PCScreenFont,
        pad_x: u16,
        pad_y: u16,
        spacing: u8
    ) TerminalError!Terminal {
        const max_dim = std.math.maxInt(u16);
        if (
            font.glyph_height > max_dim or
            font.glyph_width > max_dim or
            (font.flags & 1) != 0
        )
            return TerminalError.UnsupportedGlyphs;

        return Terminal {
            .grid = try gfx.Grid.init(
                frame_buffer,
                @intCast(font.glyph_width),
                @intCast(font.glyph_height),
                pad_x,
                pad_y,
                spacing
            ),
            .font = font,
        };
    }

    fn doWriter(self: *Terminal, msg: []const u8) TerminalError!usize {
        self.writeASCIIString(msg);
        return msg.len;
    }

    /// Get a writer interface for this terminal.
    pub fn writer(self: *Terminal) TerminalWriter {
        return TerminalWriter {
            .context = self,
        };
    }

    /// Write an ASCII string to this terminal.
    pub fn writeASCIIString(self: *Terminal, msg: []const u8) void {
        for (msg) |c| self.writeASCIIByte(c);
    }

    /// Write a single ASCII byte to this terminal.
    pub fn writeASCIIByte(self: *Terminal, char: u8) void {
        if (char == '\n') {
            self.cursor_x = self.grid.width - 1;
            self.advanceCursor();
            return;
        }
        const glyph = self.font.glyphUnchecked(char);
        var sect_it = self.grid.gridSectionUnchecked(
            self.cursor_x, self.cursor_y);

        for (glyph) |tmp| {
            var bitmap = tmp;
            for (0..8) |_| {
                const pix = sect_it.next().?;
                if (bitmap & 0x80 != 0) {
                    pix.* = self.foreground;
                } else {
                    pix.* = self.background;
                }
                bitmap <<= 1;
            }
            if (self.cursor_x != self.grid.width - 1) {
                for (0..self.grid.spacing) |i| {
                    sect_it.pixel[i] = self.background;
                }
            }
        }

        self.advanceCursor();
    }

    fn advanceCursor(self: *Terminal) void {
        if (self.cursor_x == self.grid.width - 1) {
            self.cursor_x = 0;
            if (self.cursor_y != self.grid.height - 1)
                self.cursor_y += 1;
            return;
        }
        self.cursor_x += 1;
    }
};
