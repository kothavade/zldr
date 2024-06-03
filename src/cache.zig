const std = @import("std");
const fs = std.fs;
const http = std.http;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Platform = @import("platform.zig").Platform;
const tmpfile = @import("tmpfile.zig");

const Cache = @This();
const cache_dir_name = "zldr";

allocator: Allocator,
parent_dir: fs.Dir,
cache_dir: ?fs.Dir,

/// Initializes the cache inside the parent directory.
pub fn init(allocator: Allocator, parent_dir: fs.Dir) !Cache {
    var cache_dir: ?fs.Dir = undefined;
    if (parent_dir.openDir(cache_dir_name, .{})) |dir| {
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

/// Clears the cache directory.
pub fn clear(self: *Cache) !void {
    if (self.cache_dir != null) {
        self.cache_dir.?.close();
        try self.parent_dir.deleteTree(cache_dir_name);
    }
    self.cache_dir = null;
}

/// Deinitializes the cache.
pub fn deinit(self: *Cache) void {
    if (self.cache_dir != null)
        self.cache_dir.?.close();
}

/// Downloads the latest tldr pages and extracts them to the cache directory.
pub fn update(self: *Cache) !void {
    try clear(self);
    try self.parent_dir.makeDir(cache_dir_name);
    self.cache_dir = try self.parent_dir.openDir(cache_dir_name, .{});

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

// FIXME: see comment in getPage
fn dirHasFile(dir: fs.Dir, file_name: []const u8) !bool {
    dir.access(file_name, .{}) catch |err| switch (err) {
        fs.Dir.AccessError.FileNotFound => return false,
        else => return err,
    };
    return true;
}

/// Returns the content of a page from the cache.
/// Checks the platform folder, common folder, and then all other folders.
/// Must be called after the cache is initialized with `init`.
/// Allocates memory to the result, which must be freed by the caller.
// TODO: many unnecessary allocations
pub fn getPage(self: *Cache, platform: Platform, page_name: []const u8) ![]const u8 {
    if (self.cache_dir == null) {
        return error.UninitializedCache;
    }
    const page_file_name = try std.mem.concat(self.allocator, u8, &.{ page_name, ".md" });
    defer self.allocator.free(page_file_name);

    var found_dir: ?fs.Dir = null;

    if (try dirHasFile(try self.cache_dir.?.openDir(@tagName(platform), .{}), page_file_name)) {
        found_dir = try self.cache_dir.?.openDir(@tagName(platform), .{});
    } else if (try dirHasFile(try self.cache_dir.?.openDir("common", .{}), page_file_name)) {
        found_dir = try self.cache_dir.?.openDir("common", .{});
    } else {
        const values = std.enums.values(Platform);
        for (values) |p| {
            if (p == Platform.common or p == platform) continue;
            // FIXME: dirHasFile can lead to Time-Of-Check Time-Of-Use race.
            // Instead, we should handle the error from openDir directly.
            if (try dirHasFile(try self.cache_dir.?.openDir(@tagName(p), .{}), page_file_name)) {
                std.log.warn("Page not found in platform or common folder, falling back to {s}", .{@tagName(p)});
                found_dir = try self.cache_dir.?.openDir(@tagName(p), .{});
                break;
            }
        }
    }

    if (found_dir == null) {
        return error.PageNotFound;
    }
    defer found_dir.?.close();

    var page_file = try found_dir.?.openFile(page_file_name, .{ .mode = .read_only });
    defer page_file.close();

    const page_size = try page_file.seekableStream().getEndPos();
    const page_content = try page_file.readToEndAlloc(self.allocator, page_size);
    return page_content;
}

/// Writes a list of all pages in the cache for a given Platform to a writer.
pub fn list(self: *Cache, platform: Platform, writer: anytype) !void {
    if (self.cache_dir == null) {
        return error.UninitializedCache;
    }

    var platform_dir = try self.cache_dir.?.openDir(@tagName(platform), .{ .iterate = true });
    defer platform_dir.close();

    var iter = platform_dir.iterate();
    while (try iter.next()) |entry| {
        // Strip `.md`
        _ = try writer.write(entry.name[0 .. entry.name.len - 3]);
        _ = try writer.write("\n");
    }
}
