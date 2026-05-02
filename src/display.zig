const std = @import("std");
const syscall = @import("syscall.zig");

/// Rgb565 color
pub const Color = packed struct(u16) {
    b: u5,
    g: u6,
    r: u5,

    /// Pure black (#000000)
    pub const black: Color = .{ .r = 0, .g = 0, .b = 0 };
    /// Pure white (#FFFFFF)
    pub const white: Color = .{ .r = 31, .g = 63, .b = 31 };
    /// Pure red (#FF0000)
    pub const red: Color = .{ .r = 31, .g = 0, .b = 0 };
    /// Pure green (#00FF00)
    pub const green: Color = .{ .r = 0, .g = 63, .b = 0 };
    /// Pure blue (#0000FF)
    pub const blue: Color = .{ .r = 0, .g = 0, .b = 31 };

    /// converts a RGB color unsigned integer to a color.
    /// useful for hex colors.
    ///
    /// # Example
    ///
    /// ```zig
    /// const c: Color = .fromRgb24Int(0xff0000);
    ///                                     ^ any hex color!
    /// ```
    pub fn fromRgb24Int(rgb: u24) Color {
        const b: u8 = @truncate(rgb);
        const g: u8 = @truncate(rgb >> 8);
        const r: u8 = @truncate(rgb >> 16);
        return .{ .r = @truncate(r >> 3), .g = @truncate(g >> 2), .b = @truncate(b >> 3) };
    }
};

test Color {
    const red_decl: Color = .red;
    const red_hex: Color = .fromRgb24Int(0xFF0000);

    try std.testing.expectEqual(red_decl, red_hex);
}

/// Width of the screen in pixels
pub const screen_width: u16 = 320;
/// Height of the screen in pixels
pub const screen_height: u16 = 240;

/// Rectangle; x and y represent the top-left corner of the rectangle.
pub const Rect = packed struct(u64) {
    x: u16,
    y: u16,
    width: u16,
    height: u16,

    /// Rectangle covering the entire screen perfectly
    pub const full_screen: Rect = .{
        .x = 0,
        .y = 0,
        .width = screen_width,
        .height = screen_height,
    };

    /// Displays the list of pixels inside of the bounds of `self`.
    /// Errors if the lengths aren't the same.
    ///
    /// # Example
    /// ```zig
    /// const eadk = @import("eadk");
    /// const Color = eadk.display.Color;
    /// const Rect = eadk.display.Rect;
    ///
    /// pub fn main() void {
    ///     // Draw 4 pixels in the top-left corner
    ///     const rect: Rect = .{ .x = 0, .y = 0, .width = 2, .height = 2 };
    ///     rect.pushPixels(&.{.black, .red, .green, .blue}) catch @panic("Mismatched sizes");
    ///
    ///     while (true) {};
    /// }
    /// ```
    pub fn pushPixels(self: *const Rect, pixels: []const Color) error{MismatchedSizes}!void {
        if (pixels.len != self.width * self.height)
            return error.MismatchedSizes;

        self.pushPixelsUnchecked(pixels.ptr);
    }

    /// Displays the list of pixels inside of the bounds of `self`.
    ///
    /// # Example
    /// ```zig
    /// const eadk = @import("eadk");
    /// const Color = eadk.display.Color;
    /// const Rect = eadk.display.Rect;
    ///
    /// pub fn main() void {
    ///     // Draw 4 pixels in the top-left corner
    ///     const rect: Rect = .{ .x = 0, .y = 0, .width = 2, .height = 2 };
    ///     rect.pushPixelsUnchecked(@as([]const Color, &.{.black, .red, .green, .blue}).ptr);
    ///
    ///     while (true) {};
    /// }
    /// ```
    pub fn pushPixelsUnchecked(self: *const Rect, pixels: [*]const Color) void {
        syscall.svc3(.display_push_rect, self.lo(), self.hi(), @intFromPtr(pixels));
    }

    /// Fills the area of `self` with `color`
    pub fn pushColor(self: *const Rect, color: Color) void {
        syscall.svc3(.display_push_rect_uniform, self.lo(), self.hi(), @as(u16, @bitCast(color)));
    }

    /// Get the colors of the pixels in `self`, and write them to the given buffer.
    /// Errors if the lengths aren't the same.
    pub fn pullPixels(self: *const Rect, pixels: []Color) error{MismatchedSizes}!void {
        if (pixels.len != self.width * self.height)
            return error.MismatchedSizes;

        self.pullPixelsUnchecked(pixels.ptr);
    }

    /// Get the colors of the pixels in `self`, and write them to the given buffer.
    pub fn pullPixelsUnchecked(self: *const Rect, pixels: [*]Color) void {
        syscall.svc3(.display_pull_rect, self.lo(), self.hi(), @intFromPtr(pixels));
    }

    // Get the center of `self` as a point.
    pub fn centerPointUnchecked(self: *const Rect) Point {
        return .{ .x = self.x + self.width / 2, .y = self.y + self.height / 2 };
    }

    fn lo(self: *const Rect) u32 {
        return (@as(u32, self.y) << 16) | self.x;
    }

    fn hi(self: *const Rect) u32 {
        return (@as(u32, self.height) << 16) | self.width;
    }
};

test Rect {
    _ = Rect;
}

test "Rect.hi and Rect.lo" {
    const rect: Rect = .full_screen;

    try std.testing.expectEqual(rect.lo(), 0x0);
    try std.testing.expectEqual(rect.hi(), 0x00F00140);
}

/// Fill the entire screen with `color`
pub fn clearScreen(color: Color) void {
    const rect: Rect = .full_screen;
    rect.pushColor(color);
}

/// Wait for v-blank, prevents tearing, at the cost of framerate.
pub fn waitForVblank() bool {
    const ret = syscall.svc0r(.display_wait_for_vblank);
    return ret != 0;
}

extern const _userland_trampoline_address: u8;
const eadk_display_draw_string_offset: usize = 0;

pub inline fn trampolineFunctionAddress(comptime offset: usize) usize {
    const base: [*]u8 = &_userland_trampoline_address;
    return @intFromPtr(base) + offset * 4;
}

/// 2D point on the screen.
pub const Point = packed struct(u32) {
    x: u16,
    y: u16,

    /// Top-left most corner of the screen
    pub const top_left: Point = .{ .x = 0, .y = 0 };
    /// Top-right most corner of the screen
    pub const top_right: Point = .{ .x = screen_width - 1, .y = 0 };
    /// Bottom-left most corner of the screen
    pub const bottom_left: Point = .{ .x = 0, .y = screen_height - 1 };
    /// Bottom-right most corner of the screen
    pub const bottom_right: Point = .{ .x = screen_width - 1, .y = screen_height - 1 };

    /// Absolute center of the screen
    pub const center: Point = .{ .x = screen_width / 2, .y = screen_height / 2 };

    /// Draw a string at `self`
    pub fn drawString(
        self: *const Point,
        comptime text: [:0]const u8,
        comptime options: Theme,
    ) void {
        if (text.len > 45)
            @compileError("\"" ++ text ++ "\" is longer than 45 characters");

        var point = self.*;

        switch (comptime options.alignment) {
            .center => {
                const size = options.size.dimensions();
                point.y -|= comptime size.height / 2;

                const width = size.width * text.len;
                point.x -|= comptime width / 2;
            },
            .bottom_left => {
                point.y -|= comptime if (options.size == .large) large_font_height else small_font_height;
            },
            .top_right => {
                point.x -|= comptime if (options.size == .large) large_font_width * text.len else small_font_width * text.len;
            },
            .bottom_right => {
                const size = options.size.dimensions();
                point.x -|= comptime size.width * text.len;
                point.y -|= comptime size.height;
            },
            .top_left => {},
        }

        point.drawStringSimple(text, options.size, options.fg, options.bg);
    }

    pub fn drawStringSimple(
        self: *const Point,
        text: [:0]const u8,
        size: Theme.Size,
        fg: Color,
        bg: Color,
    ) void {
        const addr = trampolineFunctionAddress(eadk_display_draw_string_offset);
        const func: *const fn (Point, [*:0]const u8, bool, Color, Color) callconv(.c) void = @ptrFromInt(addr);
        func(self.*, text.ptr, size == .large, fg, bg);
    }
};

test Point {
    _ = Point;
}

/// Helper struct for displaying text
pub const Theme = struct {
    fg: Color,
    bg: Color,
    // No need to pack these as the padding and alignment of the two colors make it useless and would only hurt performance
    size: Size = .large,
    alignment: Alignment = .top_left,

    pub const Size = enum {
        large,
        small,

        pub fn dimensions(self: Size) struct { width: u8, height: u8 } {
            return switch (self) {
                .large => .{ .width = large_font_width, .height = large_font_height },
                .small => .{ .width = small_font_width, .height = small_font_height },
            };
        }
    };

    pub const Alignment = enum {
        top_left,
        bottom_left,
        top_right,
        bottom_right,
        center,
    };
};

test Theme {
    _ = Theme;
}

// Found these constants [here](https://github.com/numworks/epsilon/blob/master/kandinsky/include/kandinsky/font.h)
/// Width of the small text in pixels
pub const small_font_width: u8 = 7;
/// Height of the small text in pixels
pub const small_font_height: u8 = 14;
/// Width of the large text in pixels
pub const large_font_width: u8 = 10;
/// Height of the large text in pixels
pub const large_font_height: u8 = 18;

/// Set the brightness of the backlight, non-persistent.
pub fn setBacklightBrightness(brightness: u8) void {
    syscall.svc1(.set_backlight_brightness, brightness);
}

/// Get the brightness of the backlight
pub fn getBacklightBrightness() u8 {
    return @truncate(syscall.svc0r(.backlight_brightness));
}
