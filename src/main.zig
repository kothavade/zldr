const std = @import("std");
const io = std.io;
const http = std.http;
const fs = std.fs;
const builtin = @import("builtin");

const clap = @import("clap");
const kf = @import("known-folders");
const at = @import("ansi-term");

const Cache = @import("cache.zig");
const Platform = @import("platform.zig").Platform;
const Formatter = @import("formatter.zig");

const version = "zldr v0.0.1\n";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = if (builtin.mode == .Debug)
        gpa.allocator()
    else
        std.heap.c_allocator;

    const parsers = comptime .{
        // TODO: custom parser, allows lowercase input
        .platform = clap.parsers.enumeration(Platform),
        // TODO: page validator
        .page = clap.parsers.string,
    };

    const out = io.getStdOut();
    const out_writer = out.writer();
    const is_tty = out.isTty();
    var bw = io.bufferedWriter(out_writer);
    const stdout = bw.writer();

    const stderr = io.getStdErr().writer();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help                  Print help
        \\-v, --version               Get zldr version 
        \\-p, --platform <platform>   Search using a specific platform
        \\-u, --update                Update the tldr pages cache
        \\-l, --list                  List all pages for the current platform
        \\    --list_platforms        List all available platforms
        \\<page>
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        // Report useful error and exit
        diag.report(stderr, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try stdout.print(version, .{});
        try stdout.print("Ved Kothavade <ved@kothavade.com>\n", .{});
        try stdout.print("A fast tdlr client written in Zig\n\n", .{});
        try stdout.print("USAGE:\n\tzldr [OPTIONS] <page>\n", .{});
        try stdout.print("ARGS:\n\t<page>:\tThe command to show the tldr page for\n", .{});
        try stdout.print("OPTIONS:\n", .{});
        try bw.flush();
        _ = try clap.help(out_writer, clap.Help, &params, .{});
        return;
    }

    if (res.args.version != 0) {
        try stdout.print(version, .{});
        try bw.flush();
        return;
    }

    if (res.args.list_platforms != 0) {
        try Platform.list(stdout);
        try bw.flush();
        return;
    }

    const platform = if (res.args.platform) |p| p else Platform.getPlatform();

    var cache_dir = try kf.open(allocator, kf.KnownFolder.cache, .{}) orelse {
        try stderr.print("Failed to get system cache directory.\n", .{});
        return;
    };
    defer cache_dir.close();

    var cache = try Cache.init(allocator, cache_dir);
    defer cache.deinit();

    if (res.args.update != 0) {
        try stdout.print("Updating cache...", .{});
        if (!is_tty) try stdout.print("\n", .{});
        try bw.flush();
        try cache.update();
        if (is_tty) {
            try at.clear.clearCurrentLine(stdout);
            try at.cursor.setCursorColumn(stdout, 0);
        }
        try stdout.print("Updated cache!\n", .{});
        try bw.flush();
        return;
    }

    if (res.args.list != 0) {
        cache.list(platform, stdout) catch |err| {
            switch (err) {
                error.UninitializedCache => {
                    try stderr.print("Cache not initialized. You should call `zldr -u`.\n", .{});
                    return;
                },
                else => |leftover| return leftover,
            }
        };
        try bw.flush();
        return;
    }

    if (res.positionals.len == 0) {
        try stderr.print("No page specified.\nRun `zldr -h to see useage.\n", .{});
        return;
    }

    // TODO: reduce allocations
    const page_name_joined = try std.mem.join(allocator, "-", res.positionals);
    defer allocator.free(page_name_joined);

    const page_name = try std.ascii.allocLowerString(allocator, page_name_joined);
    defer allocator.free(page_name);

    const page = cache.getPage(platform, page_name) catch |err| {
        switch (err) {
            error.UninitializedCache => {
                try stderr.print("Cache not initialized. You should call `zldr -u`.\n", .{});
                return;
            },
            error.PageNotFound => {
                if (is_tty) {
                    try stdout.print("Page for `{s}` not found.\nYou can request a page for this command here: ", .{page_name});
                    try at.format.updateStyle(stdout, .{ .font_style = at.style.FontStyle.underline }, null);
                    try stdout.print("https://github.com/tldr-pages/tldr/issues/new?title=page%20request:%20{s}\n", .{page_name});
                    try at.format.resetStyle(stdout);
                } else {
                    try stdout.print(
                        // TODO: use terminal link escape codes
                        "Page for `{s}` not found.\nYou can request a page for this command here: https://github.com/tldr-pages/tldr/issues/new?title=page%20request:%20{s}\n",
                        .{ page_name, page_name },
                    );
                }
                try bw.flush();
                return;
            },
            else => |leftover| return leftover,
        }
    };
    defer allocator.free(page);
    if (is_tty) {
        try Formatter.print(stdout, page);
    } else {
        try stdout.print("{s}", .{page});
    }
    try bw.flush();
    return;
}
