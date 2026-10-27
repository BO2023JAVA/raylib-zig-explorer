// 文字模块：drawText（默认字体）和 drawTextEx（指定字体 + 间距）。
// drawText 用 raylib 内置默认字体；drawTextEx 用 getFontDefault() 取默认字体。
const std = @import("std");
const raylib = @import("raylib");
const pg = @import("../playground.zig");

const Kind = enum { drawText, drawTextEx };

const Params = struct {
    // drawText：整数像素坐标 / 字号
    x: f32 = 100, y: f32 = 120,
    size: f32 = 40,
    // drawTextEx：f32 坐标 + 间距
    exX: f32 = 100, exY: f32 = 120,
    exSize: f32 = 36, spacing: f32 = 1.5,
    color: raylib.Color = raylib.Color.light_gray,
};

const TEXT = "Hello raylib!";

fn makeDemo(comptime kind: Kind) pg.Demo {
    const S = struct {
        var p: Params = .{};

        fn draw(canvas: raylib.Rectangle) void {
            const c = p.color;
            switch (kind) {
                .drawText => raylib.drawText(
                    TEXT,
                    i(canvas.x + p.x),
                    i(canvas.y + p.y),
                    i(p.size),
                    c,
                ),
                .drawTextEx => raylib.drawTextEx(
                    pg.uiFont,
                    TEXT,
                    .{ .x = canvas.x + p.exX, .y = canvas.y + p.exY },
                    p.exSize,
                    p.spacing,
                    c,
                ),
            }
        }

        fn controls(ctx: pg.ControlsCtx) void {
            const panel = ctx.panel;
            switch (kind) {
                .drawText => {
                    panel.sliderInt("X", &p.x, 0, ctx.canvasWidth);
                    panel.sliderInt("Y", &p.y, 0, ctx.canvasHeight);
                    panel.sliderInt("Font size", &p.size, 8, 96);
                },
                .drawTextEx => {
                    panel.sliderInt("X", &p.exX, 0, ctx.canvasWidth);
                    panel.sliderInt("Y", &p.exY, 0, ctx.canvasHeight);
                    panel.sliderInt("Font size", &p.exSize, 8, 96);
                    panel.sliderInt("Spacing", &p.spacing, 0, 20);
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
                .drawText => std.fmt.bufPrint(
                    buf,
                    "raylib.drawText(\"{s}\", {d}, {d}, {d}, Color.init({d}, {d}, {d}, {d}));",
                    .{ TEXT, i(p.x), i(p.y), i(p.size), c.r, c.g, c.b, c.a },
                ) catch buf,
                .drawTextEx => std.fmt.bufPrint(
                    buf,
                    "raylib.drawTextEx(raylib.getFontDefault() catch unreachable, \"{s}\", .{{ .x = {d}, .y = {d} }}, {d}, {d:.1}, Color.init({d}, {d}, {d}, {d}));",
                    .{ TEXT, i(p.exX), i(p.exY), i(p.exSize), p.spacing, c.r, c.g, c.b, c.a },
                ) catch buf,
            };
        }

        fn i(v: f32) i32 {
            return @intFromFloat(v + 0.5);
        }
    };

    return .{
        .name = switch (kind) {
            .drawText => "drawText",
            .drawTextEx => "drawTextEx",
        },
        .hint = switch (kind) {
            .drawText => "Draw text using the built-in default font.",
            .drawTextEx => "Draw text with font, size and spacing.",
        },
        .draw = S.draw,
        .drawControls = S.controls,
        .reset = S.reset,
        .writeCode = S.writeCode,
    };
}

pub const drawTextDemo = makeDemo(.drawText);
pub const drawTextExDemo = makeDemo(.drawTextEx);
