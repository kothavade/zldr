const std = @import("std");
const io = std.io;
const http = std.http;
const fs = std.fs;
const builtin = @import("builtin");

const clap = @import("clap");

const Cache = @import("cache.zig");
const Platform = @import("platform.zig").Platform;

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
        // TODO: page validator
        .page = clap.parsers.string,
    };

    const stdout_file = io.getStdOut().writer();
    var bw = io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const stderr_file = io.getStdErr().writer();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help                  Print help
        \\-v, --version               Get zldr version 
        \\-p, --platform <platform>   Search using a specific platform
        \\-u, --update                Update the tldr pages cache
        \\-l, --list                  List all available pages
        \\    --list_platforms        List all available platforms
        \\<page>
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        // Report useful error and exit
        diag.report(stderr_file, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try stdout.print(version, .{});
        try bw.flush();
        _ = try clap.help(stdout_file, clap.Help, &params, .{});
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

    // TODO: proper cache dir instead of cwd
    var cache = try Cache.init(allocator, fs.cwd());
    defer cache.deinit();

    if (res.args.update != 0) {
        try cache.update();
        return;
    }
    if (res.positionals.len == 0) {
        try stderr_file.print("No page specified.\nRun `zldr -h to see useage.\n", .{});
        try bw.flush();
        return;
    }
    for (res.positionals) |pos| {
        const user_platform = if (res.args.platform) |p| p else Platform.getPlatform();
        const page = cache.getPage(user_platform, pos) catch |err| {
            switch (err) {
                error.UninitializedCache => {
                    try stderr_file.print("Cache not initialized. You should call `zldr -u`.\n", .{});
                    try bw.flush();
                    return;
                },
                fs.File.OpenError.FileNotFound => {
                    try stderr_file.print("Page not found: {s}\n", .{pos});
                    try bw.flush();
                    return;
                },
                else => |leftover| return leftover,
            }
        };
        defer allocator.free(page);
        try stdout.print("{s}", .{page});
        try bw.flush();
        return;
    }
}
