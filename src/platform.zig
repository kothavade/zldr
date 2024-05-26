const std = @import("std");
const builtin = @import("builtin");

pub const Platform = enum {
    Android,
    Common,
    FreeBSD,
    Linux,
    NetBSD,
    OpenBSD,
    OSX,
    SunOS,
    Windows,

    /// Returns the platform correspoding to the target OS.
    pub fn getPlatform() Platform {
        var platform: Platform = undefined;
        if (builtin.target.isAndroid()) {
            platform = Platform.Android;
        } else {
            platform = switch (builtin.target.os.tag) {
                .freebsd => Platform.FreeBSD,
                .linux => Platform.Linux,
                .netbsd => Platform.NetBSD,
                .openbsd => Platform.OpenBSD,
                .macos => Platform.OSX,
                .solaris => Platform.SunOS,
                .windows => Platform.Windows,
                else => Platform.Common,
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
