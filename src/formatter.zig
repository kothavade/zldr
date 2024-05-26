const std = @import("std");

pub fn print(writer: anytype, page: []const u8) !void {
    _ = try writer.write(page);
    _ = try writer.write("\n");
    return;
}
