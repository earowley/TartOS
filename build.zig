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
    const optimize_chainloader = std.builtin.Mode.Debug;
    const hardware = b.createModule(std.build.CreateModuleOptions{
        .source_file = .{.path = "src/hardware/hardware.zig"},
    });
    const lib = b.createModule(std.build.CreateModuleOptions{
        .source_file = .{.path = "src/lib/lib.zig"},
        .dependencies = &.{
            .{.name = "hardware", .module = hardware},
        },
    });
    const rtos = b.createModule(std.build.CreateModuleOptions{
        .source_file = .{.path = "src/rtos/rtos.zig"},
        .dependencies = &.{
            .{.name = "hardware", .module = hardware},
            .{.name = "lib", .module = lib}
        },
    });

    const exe = b.addExecutable(.{
        .name = "app",
        .root_source_file = .{.path = "src/rtos/rtos.zig"},
        .target = target,
        .optimize = optimize,
    });

    const chainloader = b.addExecutable(.{
        .name = "chainloader",
        .root_source_file = .{.path = "chainloader/main.zig"},
        .target = target,
        .optimize = optimize_chainloader,
    });

    exe.addModule("lib", lib);
    exe.addModule("hardware", hardware);
    exe.addModule("rtos", rtos);
    exe.addAssemblyFile(std.build.FileSource.relative(
        "src/reset/reset_vector.s"
    ));
    exe.setLinkerScript(std.build.FileSource.relative("linker.ld"));

    chainloader.addModule("lib", lib);
    chainloader.addAssemblyFile(std.build.FileSource.relative(
        "chainloader/reset_vector.s"
    ));
    chainloader.setLinkerScript(std.build.FileSource.relative(
        "chainloader/linker.ld"));
    b.installArtifact(exe);
    b.installArtifact(chainloader);
}
