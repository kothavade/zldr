const std = @import("std");
const GitRepoStep = @import("GitRepoStep.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const clap_repo = GitRepoStep.create(b, .{
        .url = "https://github.com/Hejsil/zig-clap",
        .branch = "master",
        .sha = "7a2883c7b884ab3e88c9fbf29193894a844da4d5",
    });
    const known_folders_repo = GitRepoStep.create(b, .{
        .url = "https://github.com/ziglibs/known-folders",
        .branch = "master",
        .sha = "0ad514dcfb7525e32ae349b9acc0a53976f3a9fa",
    });

    const exe = b.addExecutable(.{
        .name = "zldr",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.step.dependOn(&clap_repo.step);
    const clap_path = b.path(try std.fs.path.join(b.allocator, &[_][]const u8{
        clap_repo.getPath(&exe.step),
        "clap.zig",
    }));
    exe.step.dependOn(&known_folders_repo.step);
    const known_folders_path = b.path(try std.fs.path.join(b.allocator, &[_][]const u8{
        known_folders_repo.getPath(&exe.step),
        "known-folders.zig",
    }));

    exe.root_module.addAnonymousImport("known-folders", .{ .root_source_file = known_folders_path });
    exe.root_module.addAnonymousImport("clap", .{ .root_source_file = clap_path });

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
