const std = @import("std");
const fs = std.fs;
const http = std.http;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Platform = @import("platform.zig").Platform;
const tmpfile = @import("tmpfile.zig");

const Cache = @This();

allocator: Allocator,
parent_dir: fs.Dir,
cache_dir: ?fs.Dir,

/// Initializes the cache inside the parent directory.
pub fn init(allocator: Allocator, parent_dir: fs.Dir) !Cache {
    var cache_dir: ?fs.Dir = undefined;
    if (parent_dir.openDir("cache", .{})) |dir| {
        cache_dir = dir;
    } else |err| switch (err) {
        fs.Dir.OpenError.FileNotFound => {
            cache_dir = null;
        },
        else => |leftover| return leftover,
    }
    return .{
        .allocator = allocator,
        .parent_dir = parent_dir,
        .cache_dir = cache_dir,
    };
}

/// Deinitializes the cache.
pub fn deinit(self: *Cache) void {
    if (self.cache_dir != null)
        self.cache_dir.?.close();
}

/// Downloads the latest tldr pages and extracts them to the cache directory.
pub fn update(self: *Cache) !void {
    if (self.cache_dir != null) {
        // TODO: this seems bad
        // TODO: refactor into a clear cache method
        self.cache_dir.?.close();
        try self.parent_dir.deleteTree("cache");
    }
    try self.parent_dir.makeDir("cache");
    self.cache_dir = try self.parent_dir.openDir("cache", .{});

    const url: []const u8 = "https://github.com/tldr-pages/tldr/releases/latest/download/tldr-pages.zip";
    var client = http.Client{ .allocator = self.allocator };
    defer client.deinit();

    var tmp_file = try tmpfile.tmpFile(self.allocator, .{});
    defer tmp_file.deinit();

    const uri = std.Uri.parse(url) catch unreachable;
    var server_header_buffer: [4096 * 2]u8 = undefined;
    var req = try client.open(
        http.Method.GET,
        uri,
        .{
            .server_header_buffer = &server_header_buffer,
        },
    );
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    const Fifo = std.fifo.LinearFifo(u8, .Dynamic);
    var fifo = Fifo.init(self.allocator);
    try fifo.ensureTotalCapacity(4096);
    defer fifo.deinit();
    try fifo.pump(req.reader(), tmp_file.f.writer());

    try std.zip.extract(self.cache_dir.?, tmp_file.f.seekableStream(), .{});
}

/// Returns the content of a page from the cache.
/// Checks the platform folder, and falls back to the common folder if the page is not found.
/// Must be called after the cache is initialized with `init`, and filled with `update`.
/// Allocates memory to the result, which must be freed by the caller.
// TODO: many unnecessary allocations
pub fn getPage(self: Cache, platform: Platform, page_name: []const u8) ![]const u8 {
    if (self.cache_dir == null) {
        return error.UninitializedCache;
    }
    const platform_folder = try std.ascii.allocLowerString(self.allocator, @tagName(platform));
    defer self.allocator.free(platform_folder);

    const page_file_path = try std.mem.concat(self.allocator, u8, &.{ page_name, ".md" });
    defer self.allocator.free(page_file_path);

    const page_path = try std.fs.path.join(self.allocator, &.{ platform_folder, page_file_path });
    defer self.allocator.free(page_path);

    var page_file: fs.File = undefined;
    if (self.cache_dir.?.openFile(page_path, .{ .mode = .read_only })) |file| {
        page_file = file;
    } else |err| switch (err) {
        fs.File.OpenError.FileNotFound => {
            const common_page_path = try std.fs.path.join(self.allocator, &.{ "common", page_file_path });
            defer self.allocator.free(common_page_path);
            page_file = try self.cache_dir.?.openFile(common_page_path, .{ .mode = .read_only });
        },
        else => |leftover_err| return leftover_err,
    }
    defer page_file.close();

    const page_size = try page_file.seekableStream().getEndPos();
    const page_content = try page_file.readToEndAlloc(self.allocator, page_size);
    return page_content;
}

pub fn list(self: *Cache, platform: Platform, writer: anytype) !void {
    if (self.cache_dir == null) {
        return error.UninitializedCache;
    }
    const platform_folder = try std.ascii.allocLowerString(self.allocator, @tagName(platform));
    defer self.allocator.free(platform_folder);

    var platform_dir = try self.cache_dir.?.openDir(platform_folder, .{ .iterate = true });
    defer platform_dir.close();

    var iter = platform_dir.iterate();
    while (try iter.next()) |entry| {
        _ = try writer.write(entry.name[0 .. entry.name.len - 3]);
        _ = try writer.write("\n");
    }
}
