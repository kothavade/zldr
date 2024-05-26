const std = @import("std");
const GitRepoStep = @import("GitRepoStep.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zldr",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const clap_repo = GitRepoStep.create(b, .{
        .url = "https://github.com/Hejsil/zig-clap",
        .branch = "master",
        .sha = "7a2883c7b884ab3e88c9fbf29193894a844da4d5",
    });
    exe.step.dependOn(&clap_repo.step);
    exe.root_module.addAnonymousImport("clap", .{ .root_source_file = b.path(try std.fs.path.join(b.allocator, &[_][]const u8{
        clap_repo.getPath(&exe.step),
        "clap.zig",
    })) });

    const known_folders_repo = GitRepoStep.create(b, .{
        .url = "https://github.com/ziglibs/known-folders",
        .branch = "master",
        .sha = "0ad514dcfb7525e32ae349b9acc0a53976f3a9fa",
    });
    exe.step.dependOn(&known_folders_repo.step);
    exe.root_module.addAnonymousImport("known-folders", .{ .root_source_file = b.path(try std.fs.path.join(b.allocator, &[_][]const u8{
        known_folders_repo.getPath(&exe.step),
        "known-folders.zig",
    })) });

    // FIXME: currently uses my branch, switch to upstream once merged
    const ansi_term_repo = GitRepoStep.create(b, .{
        .url = "https://github.com/kothavade/ansi-term",
        .branch = "patch-1",
        .sha = "11919b5b904a0cf05cb5c3d0cfb6a0f0076bec46",
    });
    exe.step.dependOn(&ansi_term_repo.step);
    exe.root_module.addAnonymousImport("ansi-term", .{ .root_source_file = b.path(try std.fs.path.join(b.allocator, &[_][]const u8{
        ansi_term_repo.getPath(&exe.step),
        "src/main.zig",
    })) });

    if (optimize != .Debug) {
        exe.linkLibC();
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
