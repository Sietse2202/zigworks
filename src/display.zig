//! Display module for zigworks, includes bindings for drawing to the screen, and other related things.

const eadk = @import("root.zig").internal;

/// Rgb565 color
pub const Color = packed struct(u16) {
    b: u5,
    g: u6,
    r: u5,

    /// Pure black (#000000)
    pub const BLACK: Color = Color.fromRgb565(0, 0, 0);
    /// Pure white (#FFFFFF)
    pub const WHITE: Color = Color.fromRgb565(31, 63, 31);
    /// Pure red (#FF0000)
    pub const RED: Color = Color.fromRgb565(31, 0, 0);
    /// Pure green (#00FF00)
    pub const GREEN: Color = Color.fromRgb565(0, 63, 0);
    /// Pure blue (#0000FF)
    pub const BLUE: Color = Color.fromRgb565(0, 0, 31);

    /// Initializer
    pub fn fromRgb565(r: u5, g: u6, b: u5) Color {
        return .{ .r = r, .g = g, .b = b };
    }

    

    /// Helper for converting from more standard formats
    pub fn fromRgb24(r: u8, g: u8, b: u8) Color {
        return Color{
            .r = @intCast(r >> 3),
            .g = @intCast(g >> 2),
            .b = @intCast(b >> 3),
        };
    }
    /// converts a RGB color unsigned integer to a color.
    /// useful for hex colors.
    /// Example:
    /// ```
    /// const c: Color = Color.fromRgb24Int(0xff0000);
    ///                                     ^ any hex color!
    /// ```
    pub inline fn fromRgb24Int(color: u24) Color {
        // __ __ BB
        const b: u8 = @truncate(color);
        // __ GG __
        const g: u8 = @truncate(color >> 8);
        // RR __ __
        const r: u8 = @truncate(color >> 16);
        return Color.fromRgb24(r, g, b);
    }

    /// Cast a u16 to a color
    pub fn fromInt(rgb: u16) Color {
        return @bitCast(rgb);
    }

    /// Cast `this` to a u16,
    pub fn toInt(this: Color) u16 {
        return @bitCast(this);
    }
};

/// Width of the screen in pixels
pub const SCREEN_WIDTH: u16 = 320;
/// Height of the screen in pixels
pub const SCREEN_HEIGHT: u16 = 240;

/// Rectangle, x and y represent the top-left corner of the rectangle.
pub const Rect = packed struct {
    x: u16,
    y: u16,
    width: u16,
    height: u16,

    /// Rectangle covering the entire screen perfectly
    pub const FULL_SCREEN: @This() = .{
        .x = 0,
        .y = 0,
        .width = SCREEN_WIDTH,
        .height = SCREEN_HEIGHT,
    };

    /// Displays the list of pixels inside of the bounds of `this`
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
    ///     rect.pushPixels(&.{Color.BLACK, Color.RED, Color.GREEN, Color.BLUE});
    ///
    ///     while (true) {};
    /// }
    /// ```
    pub fn pushPixels(this: *const @This(), pixels: []const Color) void {
        eadk.eadk_display_push_rect(@bitCast(this.*), @ptrCast(pixels.ptr));
    }

    /// Fills the area of `this` with `color`
    pub fn pushColor(this: *const @This(), color: Color) void {
        eadk.eadk_display_push_rect_uniform(@bitCast(this.*), color.toInt());
    }

    /// Get the colors of the pixels in `this`, and write them to `pixels`
    pub fn pullPixels(this: *const @This(), pixels: []Color) void {
        eadk.eadk_display_pull_rect(@bitCast(this.*), @ptrCast(pixels.ptr));
    }
};

/// Fill the entire screen with `color`
pub fn clearScreen(color: Color) void {
    eadk.eadk_display_push_rect_uniform(@bitCast(Rect.FULL_SCREEN), color.toInt());
}

/// Wait for v-blank, prevents tearing, at the cost of framerate.
pub fn waitForVblank() bool {
    return eadk.eadk_display_wait_for_vblank();
}

/// 2D point on the screen.
pub const Point = struct {
    x: u16,
    y: u16,

    /// Top-left most corner of the screen
    pub const ZERO: @This() = .{ .x = 0, .y = 0 };
    /// Absolute center of the screen
    pub const CENTER: @This() = .{ .x = SCREEN_WIDTH / 2, .y = SCREEN_HEIGHT / 2 };

    /// Draw a string at `this`
    pub fn drawString(
        this: *const @This(),
        text: []const u8,
        options: Theme,
    ) void {
        var point = this.*;

        if (options.centered) {
            point.y -= if (options.large) LARGE_FONT_HEIGHT / 2 else SMALL_FONT_HEIGHT / 2;

            const widthFactor = if (options.large) LARGE_FONT_WIDTH else SMALL_FONT_WIDTH;
            const width = widthFactor * text.len;
            point.x -= @intCast(width / 2);
        }

        eadk.eadk_display_draw_string(
            text.ptr,
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

    pub fn getTextSize(this: *const @This()) [2]u8 {
        return if (this.large) [2]u8{ LARGE_FONT_WIDTH, LARGE_FONT_HEIGHT }
            else [2]u8{ SMALL_FONT_WIDTH, SMALL_FONT_HEIGHT };
    }
};

// Found these constants [here](https://github.com/numworks/epsilon/blob/master/kandinsky/include/kandinsky/font.h)
/// Width of the small text in pixels
pub const SMALL_FONT_WIDTH: u8 = 7;
/// Height of the small text in pixels
pub const SMALL_FONT_HEIGHT: u8 = 14;
/// Width of the large text in pixels
pub const LARGE_FONT_WIDTH: u8 = 10;
/// Height of the large text in pixels
pub const LARGE_FONT_HEIGHT: u8 = 18;

/// Set the brightness of the backlight, non-persistent.
pub fn setBacklightBrightness(brightness: u8) void {
    eadk.eadk_backlight_set_brightness(brightness);
}

/// Get the brightness of the backlight
pub fn getBacklightBrightness() u8 {
    return eadk.eadk_backlight_brightness();
}
