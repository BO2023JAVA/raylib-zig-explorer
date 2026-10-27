// shapes 进阶图元：三角形 / 圆环 / 圆角矩形。
// 和 demos/shapes.zig 一样，用 comptime 工厂复用同一份参数布局。
const std = @import("std");
const raylib = @import("raylib");
const pg = @import("../playground.zig");

const Kind = enum { triangle, ring, rounded };

const Params = struct {
    // 三角形 drawTriangle：三个顶点
    x1: f32 = 200, y1: f32 = 120,
    x2: f32 = 520, y2: f32 = 140,
    x3: f32 = 360, y3: f32 = 430,
    // 圆环 drawRing
    cx: f32 = 368, cy: f32 = 300,
    inner: f32 = 60, outer: f32 = 130,
    start: f32 = 0, end: f32 = 360,
    // 圆角矩形 drawRectangleRounded（roundness 用百分比，绘制时 /100）
    rx: f32 = 130, ry: f32 = 110,
    rw: f32 = 470, rh: f32 = 360,
    roundness: f32 = 40,
    color: raylib.Color = raylib.Color.green,
};

fn makeDemo(comptime kind: Kind) pg.Demo {
    const S = struct {
        var p: Params = .{};

        fn draw(canvas: raylib.Rectangle) void {
            switch (kind) {
                .triangle => raylib.drawTriangle(
                    .{ .x = canvas.x + p.x1, .y = canvas.y + p.y1 },
                    .{ .x = canvas.x + p.x2, .y = canvas.y + p.y2 },
                    .{ .x = canvas.x + p.x3, .y = canvas.y + p.y3 },
                    p.color,
                ),
                .ring => raylib.drawRing(
                    .{ .x = canvas.x + p.cx, .y = canvas.y + p.cy },
                    p.inner,
                    p.outer,
                    p.start,
                    p.end,
                    64,
                    p.color,
                ),
                .rounded => raylib.drawRectangleRounded(
                    raylib.Rectangle.init(canvas.x + p.rx, canvas.y + p.ry, p.rw, p.rh),
                    p.roundness / 100.0,
                    16,
                    p.color,
                ),
            }
        }

        fn controls(ctx: pg.ControlsCtx) void {
            const panel = ctx.panel;
            switch (kind) {
                .triangle => {
                    panel.sliderInt("V1 X", &p.x1, 0, ctx.canvasWidth);
                    panel.sliderInt("V1 Y", &p.y1, 0, ctx.canvasHeight);
                    panel.sliderInt("V2 X", &p.x2, 0, ctx.canvasWidth);
                    panel.sliderInt("V2 Y", &p.y2, 0, ctx.canvasHeight);
                    panel.sliderInt("V3 X", &p.x3, 0, ctx.canvasWidth);
                    panel.sliderInt("V3 Y", &p.y3, 0, ctx.canvasHeight);
                },
                .ring => {
                    panel.sliderInt("Center X", &p.cx, 0, ctx.canvasWidth);
                    panel.sliderInt("Center Y", &p.cy, 0, ctx.canvasHeight);
                    panel.sliderInt("Inner R", &p.inner, 0, 300);
                    panel.sliderInt("Outer R", &p.outer, 1, 400);
                    panel.sliderInt("Start Angle", &p.start, 0, 360);
                    panel.sliderInt("End Angle", &p.end, 0, 360);
                },
                .rounded => {
                    panel.sliderInt("X", &p.rx, 0, ctx.canvasWidth);
                    panel.sliderInt("Y", &p.ry, 0, ctx.canvasHeight);
                    panel.sliderInt("Width", &p.rw, 1, ctx.canvasWidth);
                    panel.sliderInt("Height", &p.rh, 1, ctx.canvasHeight);
                    panel.sliderInt("Roundness %", &p.roundness, 0, 100);
                },
            }
            panel.gap(4);
            panel.colorPicker("Color", &p.color);
        }

        fn reset() void {
            p = .{};
        }

        fn writeCode(buf: []u8) []const u8 {
            const c = p.color;
            return switch (kind) {
                .triangle => std.fmt.bufPrint(
                    buf,
                    "raylib.drawTriangle(.{{ .x = {d}, .y = {d} }}, .{{ .x = {d}, .y = {d} }}, .{{ .x = {d}, .y = {d} }}, Color.init({d}, {d}, {d}, {d}));",
                    .{ i(p.x1), i(p.y1), i(p.x2), i(p.y2), i(p.x3), i(p.y3), c.r, c.g, c.b, c.a },
                ) catch buf,
                .ring => std.fmt.bufPrint(
                    buf,
                    "raylib.drawRing(.{{ .x = {d}, .y = {d} }}, {d}, {d}, {d}, {d}, 64, Color.init({d}, {d}, {d}, {d}));",
                    .{ i(p.cx), i(p.cy), i(p.inner), i(p.outer), i(p.start), i(p.end), c.r, c.g, c.b, c.a },
                ) catch buf,
                .rounded => std.fmt.bufPrint(
                    buf,
                    "raylib.drawRectangleRounded(Rectangle.init({d}, {d}, {d}, {d}), {d:.2}, 16, Color.init({d}, {d}, {d}, {d}));",
                    .{ i(p.rx), i(p.ry), i(p.rw), i(p.rh), p.roundness / 100.0, c.r, c.g, c.b, c.a },
                ) catch buf,
            };
        }

        fn i(v: f32) i32 {
            return @intFromFloat(v + 0.5);
        }
    };

    return .{
        .name = switch (kind) {
            .triangle => "drawTriangle",
            .ring => "drawRing",
            .rounded => "drawRectangleRounded",
        },
        .hint = switch (kind) {
            .triangle => "Draw a color-filled triangle (counter-clockwise).",
            .ring => "Draw a ring between two radii / angles.",
            .rounded => "Draw a rectangle with rounded edges.",
        },
        .draw = S.draw,
        .drawControls = S.controls,
        .reset = S.reset,
        .writeCode = S.writeCode,
    };
}

pub const triangleDemo = makeDemo(.triangle);
pub const ringDemo = makeDemo(.ring);
pub const roundedDemo = makeDemo(.rounded);
