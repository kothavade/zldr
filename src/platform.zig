const std = @import("std");
const builtin = @import("builtin");

pub const Platform = enum {
    android,
    common,
    freebsd,
    linux,
    netbsd,
    openbsd,
    osx,
    sunos,
    windows,

    /// Returns the platform correspoding to the target OS.
    pub fn getPlatform() Platform {
        var platform: Platform = undefined;
        if (builtin.target.isAndroid()) {
            platform = Platform.android;
        } else {
            platform = switch (builtin.target.os.tag) {
                .freebsd => Platform.freebsd,
                .linux => Platform.linux,
                .netbsd => Platform.netbsd,
                .openbsd => Platform.openbsd,
                .macos => Platform.osx,
                .solaris => Platform.sunos,
                .windows => Platform.windows,
                else => Platform.common,
            };
        }
        return platform;
    }

    /// Writes a list of available platforms to the given writer.
    pub fn list(writer: anytype) !void {
        try writer.print("Available platforms:\n", .{});
        for (std.enums.values(Platform)) |p| {
            try writer.print("\t{s}\n", .{@tagName(p)});
        }
    }
};
