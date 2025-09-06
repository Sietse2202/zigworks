//! Zig bindings for the [NumWorks](https://github.com/numworks/epsilon) SDK

pub const internal = @cImport(
    @cInclude("eadk.h")
);

pub const display = @import("display.zig");
pub const keyboard = @import("keyboard.zig");
pub const timing = struct {
    /// Sleep for `ms` ms
    pub fn sleepMillis(ms: u32) void {
        internal.eadk_timing_msleep(ms);
    }

    /// Sleep for `us` μs
    pub fn sleepMicros(us: u32) void {
        internal.eadk_timing_usleep(us);
    }

    /// Get the time the calculator has been on for in milliseconds
    pub fn millis() u64 {
        return internal.eadk_timing_millis();
    }
};
/// This module appears to be broken and is thus deprecated, but is kept in for consistency with the C Header
pub const battery = struct {
    /// Is the calculator charging or not (deprecated)
    pub fn isCharging() bool {
        return internal.eadk_battery_is_charging();
    }

    /// Level of the battery, always in the range [0, 100] (deprecated)
    pub fn getBatteryLevel() u8 {
        return internal.eadk_battery_level();
    }

    /// Voltage the battery uses at the time of calling (deprecated)
    pub fn batteryVoltage() f32 {
        return internal.eadk_battery_voltage();
    }

    /// Whether or not the calculator is plugged in (to a computer presumably) (deprecated)
    pub fn isPluggedIn() bool {
        return internal.eadk_usb_is_plugged();
    }
};

/// Experimental and not yet tested.
pub var EXTERNAL_DATA: []const u8 = internal.eadk_external_data[0..internal.eadk_external_data_size];

pub const random = struct {
    /// Generate a random unsigned integer, can be any `u<n>`, where n ∈ [1, 32]
    pub fn randomInt(comptime T: type) T {
        const type_info = @typeInfo(T);
        if (type_info != .int or type_info.int.signedness != .unsigned) {
            @compileError("randomInt only supports unsigned integer types");
        }

        const bits = @bitSizeOf(T);
        if (bits > 32) {
            @compileError("randomInt only supports types up to 32 bits");
        }

        if (bits == 32) {
            return internal.eadk_random();
        }

        const raw = internal.eadk_random();
        return @truncate(raw >> (32 - bits));
    }

    /// Same constraints as `randomInt` except it is bound to a certain range,
    /// this function aims to retain the distribution of the original
    pub fn randomInRange(comptime T: type, min: T, max: T) T {
        const max_t = @import("std").math.maxInt(T);

        const n = max - min + 1;
        const rem = max_t % n;
        var x = randomInt(T);

        while (x >= max_t - rem) {
            x = randomInt(T);
        }

        return min + x % n;
    }
};

/// Convenience function for setting the required metadata in the final elf, if you don't use the symbols, zig will
/// optimize them away, so be sure to do something like this:
/// ```zig
/// const embed = @embedFile("icon.nwi");
/// const AppMetadata = eadk.setMetadata(embed.len, "Zig App", 0, embed.*);
///
/// // If you don't include this, the data gets optimized away, and your app won't link
/// comptime {
///     _ = AppMetadata.EADK_APP_NAME;
///     _ = AppMetadata.EADK_APP_API_LEVEL;
///     _ = AppMetadata.EADK_APP_ICON;
/// }
/// ```
pub fn setMetadata(
    N: comptime_int,
    comptime name: []const u8,
    comptime apiLevel: u32,
    comptime icon: [N:0]u8,
) type {
    return struct {
        pub export const EADK_APP_NAME: [name.len + 1]u8 linksection(".rodata.eadk_app_name") =
            (name ++ "\x00").*;
        pub export const EADK_APP_API_LEVEL: u32 linksection(".rodata.eadk_api_level") = apiLevel;
        pub export const EADK_APP_ICON: [icon.len]u8 linksection(".rodata.eadk_app_icon") =
            icon;
    };
}
