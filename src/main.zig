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
const Err = @import("err-printer.zig");

const version = "zldr v0.0.1\n";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = if (builtin.mode == .Debug)
        gpa.allocator()
    else
        std.heap.c_allocator;

    const parsers = comptime .{
        .platform = clap.parsers.enumeration(Platform),
        .page = clap.parsers.string,
        .dir = clap.parsers.string,
    };

    const out = io.getStdOut();
    const out_writer = out.writer();
    const is_tty = out.isTty();
    var bw = io.bufferedWriter(out_writer);
    const stdout = bw.writer();

    const stderr = io.getStdErr().writer();
    var errPrinter = try Err.init(stderr, is_tty);

    const params = comptime clap.parseParamsComptime(
        \\-h, --help                  Print help
        \\-v, --version               Get zldr version 
        \\-p, --platform <platform>   Search using a specific platform
        \\-u, --update                Update the tldr pages cache
        \\-l, --list                  List all pages for the current platform
        \\-c, --clear-cache           Clear the cache
        \\    --list-platforms        List all available platforms
        \\    --cache-dir <dir>       Specify the cache directory to use (default: ${system cache directory}/zldr)
        \\<page>                      The command to show the tldr page for
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
        try stdout.print("Ved Kothavade <ved@kothavade.com>", .{});
        try stdout.print(
            \\
            \\      __    __    
            \\ ____/ /___/ /____
            \\/_  / / __  / ___/
            \\ / /_/ /_/ / /    
            \\/___/\__,_/_/     
        , .{});
        try stdout.print("\n\nA fast tdlr client written in Zig.\n\n", .{});
        try stdout.print("USAGE:\n    zldr [OPTIONS] <page>\n\n", .{});
        try stdout.print("OPTIONS:\n\n", .{});
        try bw.flush();
        _ = try clap.help(out_writer, clap.Help, &params, .{
            .description_on_new_line = false,
            .description_indent = 4,
        });
        return;
    }

    if (res.args.version != 0) {
        try stdout.print(version, .{});
        try bw.flush();
        return;
    }

    if (res.args.@"list-platforms" != 0) {
        try Platform.list(stdout);
        try bw.flush();
        return;
    }

    const platform = if (res.args.platform) |p| p else Platform.getPlatform();

    var cache_dir: fs.Dir = undefined;
    defer cache_dir.close();

    if (res.args.@"cache-dir") |path| {
        cache_dir = fs.cwd().makeOpenPath(path, .{}) catch |err| {
            try errPrinter.p("Failed to open cache directory `{s}`: {}\n", .{ path, err });
            return;
        };
    } else {
        cache_dir = try kf.open(allocator, kf.KnownFolder.cache, .{}) orelse {
            try errPrinter.p("Failed to get system cache directory.\n", .{});
            return;
        };
    }

    var cache = try Cache.init(allocator, cache_dir);
    defer cache.deinit();

    if (res.args.@"clear-cache" != 0) {
        try stdout.print("Clearing cache...", .{});
        if (!is_tty) try stdout.print("\n", .{});
        try bw.flush();
        try cache.clear();
        if (is_tty) {
            try at.clear.clearCurrentLine(stdout);
            try at.cursor.setCursorColumn(stdout, 0);
        }
        try stdout.print("Cleared cache!\n", .{});
        try bw.flush();
        return;
    }

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
                    try errPrinter.p("Cache not initialized. You should call `zldr -u`.\n", .{});
                    return;
                },
                else => |leftover| return leftover,
            }
        };
        try bw.flush();
        return;
    }

    if (res.positionals.len == 0) {
        try errPrinter.p("No page specified.\nRun `zldr -h to see useage.\n", .{});
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
                try errPrinter.p("Cache not initialized. You should call `zldr -u`.\n", .{});
                return;
            },
            error.PageNotFound => {
                if (is_tty) try at.format.updateStyle(stderr, .{ .foreground = .Red }, null);
                try errPrinter.p("Page for `{s}` not found in cache.\nYou can try updating the cache by running `zldr -u`.\nYou can also request a page for this command here:\n", .{page_name});
                const link = "https://github.com/tldr-pages/tldr/issues/new?title=Page%20request:%20";
                if (is_tty) {
                    try at.format.updateStyle(stderr, .{ .foreground = .Blue }, null);
                    try stderr.print("\x1b]8;;{s}{s}\x1b\\{s}{s}\x1b]8;;\x1b\\\n", .{ link, page_name, link, page_name });
                    try at.format.resetStyle(stderr);
                } else {
                    try stderr.print("{s}{s}\n", .{ link, page_name });
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
