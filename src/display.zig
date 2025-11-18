//! Display module for zigworks, includes bindings for drawing to the screen, and other related things.

const eadk = @import("root.zig").eadk_internal;
const std = @import("std");

/// Rgb565 color
pub const Color = packed struct(u16) {
    b: u5,
    g: u6,
    r: u5,

    const Self = @This();

    /// Pure black (#000000)
    pub const black: Color = Color.fromRgb565(0, 0, 0);
    /// Pure white (#FFFFFF)
    pub const white: Color = Color.fromRgb565(31, 63, 31);
    /// Pure red (#FF0000)
    pub const red: Color = Color.fromRgb565(31, 0, 0);
    /// Pure green (#00FF00)
    pub const green: Color = Color.fromRgb565(0, 63, 0);
    /// Pure blue (#0000FF)
    pub const blue: Color = Color.fromRgb565(0, 0, 31);

    /// Initializer
    pub fn fromRgb565(r: u5, g: u6, b: u5) Self {
        return .{ .r = r, .g = g, .b = b };
    }

    /// Helper for converting from more standard formats
    pub fn fromRgb24(r: u8, g: u8, b: u8) Self {
        return Color{
            .r = @intCast(r >> 3),
            .g = @intCast(g >> 2),
            .b = @intCast(b >> 3),
        };
    }
    /// converts a RGB color unsigned integer to a color.
    /// useful for hex colors.
    ///
    /// # Example
    ///
    /// ```zig
    /// const c: Color = Color.fromRgb24Int(0xff0000);
    ///                                     ^ any hex color!
    /// ```
    pub inline fn fromRgb24Int(rgb: u24) Self {
        const b: u8 = @truncate(rgb);
        const g: u8 = @truncate(rgb >> 8);
        const r: u8 = @truncate(rgb >> 16);
        return Color.fromRgb24(r, g, b);
    }

    /// Cast a u16 to a color
    pub fn fromRgb565Int(rgb: u16) Self {
        return @bitCast(rgb);
    }

    /// Convert `self` to a u16,
    pub fn toRgb565Int(self: Self) u16 {
        return @bitCast(self);
    }
};

/// Width of the screen in pixels
pub const screen_width: u16 = 320;
/// Height of the screen in pixels
pub const screen_height: u16 = 240;

/// Rectangle, x and y represent the top-left corner of the rectangle.
pub const Rect = packed struct {
    x: u16,
    y: u16,
    width: u16,
    height: u16,

    pub const Self = @This();

    /// Rectangle covering the entire screen perfectly
    pub const full_screen: Self = .{
        .x = 0,
        .y = 0,
        .width = screen_width,
        .height = screen_height,
    };

    /// Displays the list of pixels inside of the bounds of `self`
    ///
    /// # Example
    /// ```zig
    /// const eadk = @import("eadk");
    /// const Color = eadk.display.Color;
    /// const Rect = eadk.display.Rect;
    ///
    /// pub fn main() void {
    ///     // Draw 4 pixels in the top-left corner
    ///     const rect: Rect = .{ .x = 0, .y = 0, .width = 2, .height = 2};
    ///     rect.pushPixels(&.{Color.black, Color.red, Color.green, Color.blue});
    ///
    ///     while (true) {};
    /// }
    /// ```
    pub fn pushPixels(self: *const Self, pixels: []const Color) void {
        eadk.eadk_display_push_rect(@bitCast(self.*), @ptrCast(pixels.ptr));
    }

    /// Fills the area of `self` with `color`
    pub fn pushColor(self: *const Self, color: Color) void {
        eadk.eadk_display_push_rect_uniform(@bitCast(self.*), color.toInt());
    }

    /// Get the colors of the pixels in `self`, and write them to the given buffer
    pub fn pullPixels(self: *const Self, pixels: []Color) void {
        eadk.eadk_display_pull_rect(@bitCast(self.*), @ptrCast(pixels.ptr));
    }

    pub fn centerPoint(self: Self) Point {
        return .{ .x = self.x + self.width / 2, .y = self.y + self.height / 2 };
    }

    pub fn topLeftPoint(self: Self) Point {
        return .{ .x = self.x, .y = self.y };
    }

    pub fn fromPoint(point: Point, width: u16, height: u16) Self {
        return .{
            .x = point.x,
            .y = point.y,
            .width = width,
            .height = height,
        };
    }
};

/// Fill the entire screen with `color`
pub fn clearScreen(color: Color) void {
    eadk.eadk_display_push_rect_uniform(@bitCast(Rect.full_screen), color.toInt());
}

/// Wait for v-blank, prevents tearing, at the cost of framerate.
pub fn waitForVblank() bool {
    return eadk.eadk_display_wait_for_vblank();
}

/// 2D point on the screen.
pub const Point = struct {
    x: u16,
    y: u16,

    const Self = @This();

    /// Top-left most corner of the screen
    pub const zero: Self = .{ .x = 0, .y = 0 };
    /// Absolute center of the screen
    pub const center: Self = .{ .x = screen_width / 2, .y = screen_height / 2 };

    /// Draw a string at `self`
    pub fn drawString(
        self: *const Self,
        text: [*:0]const u8,
        options: Theme,
    ) void {
        var point = self.*;

        if (options.centered) {
            point.y -= if (options.large) large_font_height / 2 else small_font_height / 2;

            const widthFactor = if (options.large) large_font_width else small_font_width;
            const width = widthFactor * std.mem.len(text);
            point.x -= @intCast(width / 2);
        }

        eadk.eadk_display_draw_string(
            text,
            .{ .x = point.x, .y = point.y },
            options.large,
            @bitCast(options.fg),
            @bitCast(options.bg),
        );
    }
};

/// Helper struct for displaying text
pub const Theme = struct {
    fg: Color,
    bg: Color,
    large: bool = false,
    centered: bool = false,

    const Self = @This();

    pub fn getTextSize(self: *const Self) [2]u8 {
        return if (self.large) [2]u8{ large_font_width, large_font_height }
            else [2]u8{ small_font_width, small_font_height };
    }
};

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
    eadk.eadk_backlight_set_brightness(brightness);
}

/// Get the brightness of the backlight
pub fn getBacklightBrightness() u8 {
    return eadk.eadk_backlight_brightness();
}
