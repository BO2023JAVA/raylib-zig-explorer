// 第一节实验课：shapes 基础图元（直线 / 圆 / 矩形）。
// 三个实验共用一份参数，用 comptime 工厂生成，避免把几乎相同的代码抄三遍。
// 学习方法：拖动右侧滑块，对照底部生成的代码和画布上的效果。
const std = @import("std");
const raylib = @import("raylib");
const pg = @import("../playground.zig");

const Kind = enum { line, circle, rectangle };

/// 所有图元的可调参数。坐标是"相对于画布左上角"的像素值。
const Params = struct {
    // 直线 drawLineEx
    x1: f32 = 80,
    y1: f32 = 60,
    x2: f32 = 460,
    y2: f32 = 300,
    thick: f32 = 3,
    // 圆 drawCircleV
    cx: f32 = 270,
    cy: f32 = 200,
    radius: f32 = 80,
    // 矩形 drawRectangleRec
    rx: f32 = 120,
    ry: f32 = 90,
    rw: f32 = 300,
    rh: f32 = 220,
    // 圆 / 矩形共用：实心还是描边
    filled: bool = true,
    color: raylib.Color = raylib.Color.orange,
};

fn makeDemo(comptime kind: Kind) pg.Demo {
    const S = struct {
        var p: Params = .{};

        fn draw(canvas: raylib.Rectangle) void {
            switch (kind) {
                .line => raylib.drawLineEx(
                    .{ .x = canvas.x + p.x1, .y = canvas.y + p.y1 },
                    .{ .x = canvas.x + p.x2, .y = canvas.y + p.y2 },
                    p.thick,
                    p.color,
                ),
                .circle => {
                    const center = raylib.Vector2{ .x = canvas.x + p.cx, .y = canvas.y + p.cy };
                    if (p.filled) raylib.drawCircleV(center, p.radius, p.color) // 实心
                    else raylib.drawCircleLinesV(center, p.radius, p.color); // 描边
                },
                .rectangle => {
                    const rec = raylib.Rectangle.init(canvas.x + p.rx, canvas.y + p.ry, p.rw, p.rh);
                    if (p.filled) raylib.drawRectangleRec(rec, p.color) // 实心
                    else raylib.drawRectangleLinesEx(rec, p.thick, p.color); // 描边
                },
            }
        }

        fn controls(ctx: pg.ControlsCtx) void {
            const panel = ctx.panel;
            switch (kind) {
                .line => {
                    panel.sliderInt("Start X", &p.x1, 0, ctx.canvasWidth);
                    panel.sliderInt("Start Y", &p.y1, 0, ctx.canvasHeight);
                    panel.sliderInt("End X", &p.x2, 0, ctx.canvasWidth);
                    panel.sliderInt("End Y", &p.y2, 0, ctx.canvasHeight);
                    panel.sliderInt("Thickness", &p.thick, 1, 12);
                },
                .circle => {
                    panel.sliderInt("Center X", &p.cx, 0, ctx.canvasWidth);
                    panel.sliderInt("Center Y", &p.cy, 0, ctx.canvasHeight);
                    panel.sliderInt("Radius", &p.radius, 1, @min(ctx.canvasWidth, ctx.canvasHeight) / 2.0);
                    panel.check("Filled", &p.filled);
                },
                .rectangle => {
                    panel.sliderInt("X", &p.rx, 0, ctx.canvasWidth);
                    panel.sliderInt("Y", &p.ry, 0, ctx.canvasHeight);
                    panel.sliderInt("Width", &p.rw, 1, ctx.canvasWidth);
                    panel.sliderInt("Height", &p.rh, 1, ctx.canvasHeight);
                    panel.sliderInt("Thickness", &p.thick, 1, 12);
                    panel.check("Filled", &p.filled);
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
                .line => std.fmt.bufPrint(
                    buf,
                    "raylib.drawLineEx(.{{ .x = {d}, .y = {d} }}, .{{ .x = {d}, .y = {d} }}, {d}, Color.init({d}, {d}, {d}, {d}));",
                    .{ i(p.x1), i(p.y1), i(p.x2), i(p.y2), i(p.thick), c.r, c.g, c.b, c.a },
                ) catch buf,
                .circle => std.fmt.bufPrint(
                    buf,
                    "raylib.drawCircleV(.{{ .x = {d}, .y = {d} }}, {d}, Color.init({d}, {d}, {d}, {d}));",
                    .{ i(p.cx), i(p.cy), i(p.radius), c.r, c.g, c.b, c.a },
                ) catch buf,
                .rectangle => std.fmt.bufPrint(
                    buf,
                    "raylib.drawRectangleRec(Rectangle.init({d}, {d}, {d}, {d}), Color.init({d}, {d}, {d}, {d}));",
                    .{ i(p.rx), i(p.ry), i(p.rw), i(p.rh), c.r, c.g, c.b, c.a },
                ) catch buf,
            };
        }

        /// f32 参数四舍五入成 i32，用于显示像素值
        fn i(v: f32) i32 {
            return @intFromFloat(v + 0.5);
        }
    };

    return .{
        .name = switch (kind) {
            .line => "drawLineEx",
            .circle => "drawCircleV",
            .rectangle => "drawRectangleRec",
        },
        .hint = switch (kind) {
            .line => "Draw a thick line between two Vector2 points.",
            .circle => "Draw a filled or outlined circle.",
            .rectangle => "Draw a filled or outlined rectangle.",
        },
        .draw = S.draw,
        .drawControls = S.controls,
        .reset = S.reset,
        .writeCode = S.writeCode,
    };
}

pub const lineDemo = makeDemo(.line);
pub const circleDemo = makeDemo(.circle);
pub const rectangleDemo = makeDemo(.rectangle);
