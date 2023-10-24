const std = @import("std");

pub fn build(b: *std.Build) void {
    const target: std.zig.CrossTarget = .{
        .cpu_arch = .aarch64,
        .cpu_model = .{.explicit = &std.Target.aarch64.cpu.cortex_a53},
        .os_tag = .freestanding,
        .abi = .eabi,
    };

    // Use the optimization settings from command line.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "rpi",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addAssemblyFile(std.build.FileSource.relative(
        "src/reset_vector.s"
    ));
    exe.setLinkerScript(std.build.FileSource.relative("linker.ld"));
    b.installArtifact(exe);
}
