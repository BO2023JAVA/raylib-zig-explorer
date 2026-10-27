const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const mod = b.addModule("myworld", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "myworld",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "myworld", .module = mod },
            },
        }),
    });
    exe.root_module.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);
    // Win32 子系统：运行时不弹控制台黑窗；--audit 的 stderr 重定向到文件仍可用
    exe.subsystem = .windows;

    b.installArtifact(exe);

    // 把 resources/ 复制到 zig-out/bin/resources，保证直接双击 exe 也能找到字体等资源
    const install_resources = b.addInstallDirectory(.{
        .source_dir = b.path("resources"),
        .install_dir = .bin,
        .install_subdir = "resources",
    });
    b.getInstallStep().dependOn(&install_resources.step);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // zig build catalog：根据 raylib + raygui 头文件和绑定重新生成 src/catalog.zig
    const gen_exe = b.addExecutable(.{
        .name = "gen_catalog",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/gen_catalog.zig"),
            .target = b.graph.host,
        }),
    });
    const gen_cmd = b.addRunArtifact(gen_exe);
    gen_cmd.addArg("zig-pkg/raylib/src/raylib.h");
    gen_cmd.addArg("zig-pkg/raylib_zig-6.0.0-KE8REDSmBQAbyUv_Fh71wgvhQSP2zsmVxtPRLzCgIXWK/lib/raylib.zig");
    gen_cmd.addArg("src/catalog.zig");
    gen_cmd.addArg("zig-pkg/raygui/src/raygui.h");
    gen_cmd.addArg("zig-pkg/raylib_zig-6.0.0-KE8REDSmBQAbyUv_Fh71wgvhQSP2zsmVxtPRLzCgIXWK/lib/raygui.zig");
    const catalog_step = b.step("catalog", "Regenerate src/catalog.zig from raylib + raygui sources");
    catalog_step.dependOn(&gen_cmd.step);
}
