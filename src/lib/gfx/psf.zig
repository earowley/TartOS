/// The structure representing the header of a PC screen font (.psf)
/// file. If the binary data of a .psf is mapped to a pointer of this
/// type, glyph data can be accessed using the glyph functions.
pub const PCScreenFont = extern struct {
    magic: u32,
    version: u32,
    header_size: u32,
    flags: u32,
    glyph_count: u32,
    bytes_per_glyph: u32,
    glyph_height: u32,
    glyph_width: u32,

    /// Fetch the glyph data at position `ndx`.
    pub fn glyphUnchecked(self: *const PCScreenFont, ndx: u32)
      []const u8 {
        const p: [*]const u8 = @ptrFromInt(
            @intFromPtr(self) +
            self.header_size +
            self.bytes_per_glyph * ndx
        );
        return p[0..self.bytes_per_glyph];
    }

    /// Fetch the glyph data at position `ndx`, or return null if the
    /// glyph does not exist.
    pub fn glyph(self: *const PCScreenFont, ndx: u32) ?[]const u8 {
        if (ndx >= self.glyph_count) return null;
        return self.glyphUnchecked(ndx);
    }
};
