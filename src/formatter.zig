const std = @import("std");
const at = @import("ansi-term");
const FontStyle = at.style.FontStyle;
const Color = at.style.Color;
const Style = at.style.Style;

pub fn print(writer: anytype, page: []const u8) !void {
    _ = try writer.write("\n");
    var lines = std.mem.splitSequence(u8, page, "\n");
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        switch (line[0]) {
            '#' => try LineState.Heading.print(writer, line[2..]),
            '>' => try LineState.Quote.print(writer, line[2..]),
            '-' => try LineState.List.print(writer, line[2..]),
            '`' => try LineState.Code.print(writer, line[1 .. line.len - 1]),
            else => _ = try writer.write(line),
        }
    }
    _ = try writer.write("\n");
}

fn writeLine(writer: anytype, line: []const u8, baseColor: Color) !void {
    var inCode = false;
    var skipNext = false;
    var linkStart: usize = 0;
    for (line, 0..) |c, i| {
        if (skipNext) {
            skipNext = false;
            continue;
        }
        switch (c) {
            '<' => {
                try at.format.updateStyle(writer, .{ .foreground = .Blue }, null);
                _ = try writer.write("\x1b]8;;");
                linkStart = i + 1;
            },
            '>' => {
                _ = try writer.write("\x07");
                _ = try writer.write(line[linkStart..i]);
                _ = try writer.write("\x1b]8;;\x07");
                try at.format.updateStyle(writer, .{ .foreground = baseColor }, null);
            },
            '`' => {
                if (inCode) {
                    inCode = false;
                    try at.format.updateStyle(writer, .{ .foreground = baseColor }, null);
                } else {
                    inCode = true;
                    try at.format.updateStyle(writer, .{ .foreground = .Cyan }, null);
                }
            },
            '{' => {
                skipNext = true;
                try at.format.updateStyle(writer, .{ .font_style = .{ .underline = true }, .foreground = baseColor }, null);
            },
            '}' => {
                skipNext = true;
                try at.format.updateStyle(writer, .{ .font_style = .{ .underline = false }, .foreground = baseColor }, null);
            },
            else => {
                _ = try writer.writeByte(c);
            },
        }
    }
}

const LineState = enum {
    Heading,
    Quote,
    List,
    Code,
    fn print(self: LineState, writer: anytype, line: []const u8) !void {
        const headingStyle: Style = .{ .font_style = .{ .bold = true } };
        const quoteStyle: Style = .{};
        const listStyle: Style = .{ .foreground = .Green };
        const codeStyle: Style = .{ .foreground = .Cyan };

        switch (self) {
            .Heading => {
                try at.format.updateStyle(writer, headingStyle, null);
                _ = try writer.write("  ");
                try writeLine(writer, line, headingStyle.foreground);
                _ = try writer.write("\n\n");
                try at.format.resetStyle(writer);
            },
            .Quote => {
                try at.format.updateStyle(writer, quoteStyle, null);
                _ = try writer.write("  ");
                try writeLine(writer, line, quoteStyle.foreground);
                _ = try writer.write("\n");
                try at.format.resetStyle(writer);
            },
            .List => {
                try at.format.updateStyle(writer, listStyle, null);
                _ = try writer.write("\n  ");
                try at.format.updateStyle(writer, .{ .foreground = .Green }, null);
                try writeLine(writer, line, listStyle.foreground);
                _ = try writer.write("\n");
                try at.format.resetStyle(writer);
            },
            .Code => {
                try at.format.updateStyle(writer, codeStyle, null);
                _ = try writer.write("      ");
                try writeLine(writer, line, codeStyle.foreground);
                _ = try writer.write("\n");
                try at.format.resetStyle(writer);
            },
        }
    }
};
