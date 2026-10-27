// 3D 模块：drawCube —— 一个 3D 场景（相机 + 网格 + 立方体 + 球体）。
// 用 beginScissorMode 把 3D 画面裁剪到中央画布，避免画出面板边界。
const std = @import("std");
const raylib = @import("raylib");
const pg = @import("../playground.zig");

const Params = struct {
    orbit: bool = true,
    color: raylib.Color = raylib.Color.green,
};

const S = struct {
    var p: Params = .{};
    var cam: raylib.Camera3D = .{
        .position = .{ .x = 14, .y = 12, .z = 14 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .up = .{ .x = 0, .y = 1, .z = 0 },
        .fovy = 45,
        .projection = .perspective,
    };

    fn update() void {
        if (p.orbit) raylib.updateCamera(&cam, .orbital);
    }

    fn draw(canvas: raylib.Rectangle) void {
        raylib.beginScissorMode(
            @intFromFloat(canvas.x),
            @intFromFloat(canvas.y),
            @intFromFloat(canvas.width),
            @intFromFloat(canvas.height),
        );
        cam.begin();
        raylib.drawGrid(16, 1.0);
        raylib.drawCube(.{ .x = 0, .y = 0.5, .z = 0 }, 2, 1, 2, p.color);
        raylib.drawCube(.{ .x = -3, .y = 0.5, .z = -2 }, 1, 1, 1, raylib.Color.blue);
        raylib.drawCube(.{ .x = 3, .y = 1, .z = -1 }, 1.5, 2, 1.5, raylib.Color.orange);
        raylib.drawCube(.{ .x = 0, .y = 0.5, .z = 3 }, 1, 1, 1, raylib.Color.purple);
        raylib.drawSphere(.{ .x = 0, .y = 2.6, .z = 0 }, 0.8, raylib.Color.red);
        cam.end();
        raylib.endScissorMode();
        raylib.drawTextEx(pg.uiFont, "3D: cubes + sphere, camera orbits the scene", .{ .x = canvas.x + 12, .y = canvas.y + 12 }, 18, 1, raylib.Color.light_gray);
    }

    fn controls(ctx: pg.ControlsCtx) void {
        const panel = ctx.panel;
        panel.check("Orbit camera", &p.orbit);
        panel.gap(4);
        panel.colorPicker("Main cube", &p.color);
    }

    fn reset() void {
        p = .{};
        cam = .{
            .position = .{ .x = 14, .y = 12, .z = 14 },
            .target = .{ .x = 0, .y = 0, .z = 0 },
            .up = .{ .x = 0, .y = 1, .z = 0 },
            .fovy = 45,
            .projection = .perspective,
        };
    }

    fn writeCode(buf: []u8) []const u8 {
        const c = p.color;
        return std.fmt.bufPrint(
            buf,
            "raylib.drawCube(.{{ .x = 0, .y = 0.5, .z = 0 }}, 2, 1, 2, Color.init({d}, {d}, {d}, {d}));",
            .{ c.r, c.g, c.b, c.a },
        ) catch buf;
    }
};

pub const drawCubeDemo: pg.Demo = .{
    .name = "drawCube",
    .hint = "A 3D scene: grid, cubes and a sphere under a camera.",
    .update = S.update,
    .draw = S.draw,
    .drawControls = S.controls,
    .reset = S.reset,
    .writeCode = S.writeCode,
};
