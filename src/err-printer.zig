const std = @import("std");
const at = @import("ansi-term");

const ErrPrinter = @This();
const StdErr = @TypeOf(std.io.getStdErr().writer());

stderr: StdErr,
isTty: bool,

/// Initialize the Ansi struct.
pub fn init(stderr: StdErr, isTty: bool) !ErrPrinter {
    return .{ .stderr = stderr, .isTty = isTty };
}

/// Print a message to stderr with the given format and arguments.
///
/// If the stderr is a tty, the message will be printed in red.
pub fn p(self: *ErrPrinter, comptime format: []const u8, args: anytype) !void {
    if (self.isTty) try at.format.updateStyle(self.stderr, .{ .foreground = .Red }, null);
    try self.stderr.print(format, args);
    if (self.isTty) try at.format.resetStyle(self.stderr);
}
