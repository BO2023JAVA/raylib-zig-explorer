// 输入模块：isKeyDown（持续按键）和 getMousePosition（鼠标位置 + 点击落点）。
// 坐标约定：画布是屏幕中央区域，左上角固定在 (CANVAS_X, CANVAS_Y)，尺寸固定。
const std = @import("std");
const raylib = @import("raylib");
const pg = @import("../playground.zig");

const CANVAS_X: f32 = 232;
const CANVAS_Y: f32 = 58;
const CANVAS_W: f32 = 736;
const CANVAS_H: f32 = 618;

const Kind = enum { keyboard, mouse };

const Params = struct {
    // 键盘演示：方块移动速度
    speed: f32 = 240,
    // 鼠标演示：落点半径 / 颜色
    markR: f32 = 8,
    color: raylib.Color = raylib.Color.orange,
};

/// 鼠标相对画布的坐标
fn localMouse() raylib.Vector2 {
    const m = raylib.getMousePosition();
    return .{ .x = m.x - CANVAS_X, .y = m.y - CANVAS_Y };
}

fn makeDemo(comptime kind: Kind) pg.Demo {
    const S = struct {
        var p: Params = .{};
        var sqX: f32 = 300;
        var sqY: f32 = 280; // 键盘方块位置（画布局部）
        var marks: [6]raylib.Vector2 = undefined; // 鼠标点击落点
        var markCount: usize = 0;

        fn update() void {
            const dt = raylib.getFrameTime();
            const s = p.speed * dt;
            if (raylib.isKeyDown(.w) or raylib.isKeyDown(.up)) sqY -= s;
            if (raylib.isKeyDown(.s) or raylib.isKeyDown(.down)) sqY += s;
            if (raylib.isKeyDown(.a) or raylib.isKeyDown(.left)) sqX -= s;
            if (raylib.isKeyDown(.d) or raylib.isKeyDown(.right)) sqX += s;
            const half: f32 = 30;
            sqX = std.math.clamp(sqX, 0, CANVAS_W - 2 * half);
            sqY = std.math.clamp(sqY, 0, CANVAS_H - 2 * half);
            if (raylib.isMouseButtonPressed(.left)) {
                const m = localMouse();
                if (markCount < marks.len) {
                    marks[markCount] = m;
                    markCount += 1;
                }
            }
        }

        fn draw(canvas: raylib.Rectangle) void {
            const c = p.color;
            switch (kind) {
                .keyboard => {
                    const half: f32 = 30;
                    raylib.drawRectangle(
                        i(canvas.x + sqX - half),
                        i(canvas.y + sqY - half),
                        60,
                        60,
                        c,
                    );
                    // 显示当前按下的方向键状态
                    var held: [64]u8 = undefined;
                    const h = std.fmt.bufPrint(held[0..], "held: {s}{s}{s}{s}", .{
                        if (raylib.isKeyDown(.up) or raylib.isKeyDown(.w)) "UP " else "",
                        if (raylib.isKeyDown(.down) or raylib.isKeyDown(.s)) "DOWN " else "",
                        if (raylib.isKeyDown(.left) or raylib.isKeyDown(.a)) "LEFT " else "",
                        if (raylib.isKeyDown(.right) or raylib.isKeyDown(.d)) "RIGHT " else "",
                    }) catch "held: ";
                    held[h.len] = 0;
                    raylib.drawTextEx(pg.uiFont, held[0..h.len:0], .{ .x = canvas.x + 12, .y = canvas.y + 12 }, 22, 1, raylib.Color.light_gray);
                    raylib.drawTextEx(pg.uiFont, "WASD / Arrows to move", .{ .x = canvas.x + 12, .y = canvas.y + 40 }, 18, 1, raylib.Color.gray);
                },
                .mouse => {
                    const m = localMouse();
                    const mx = canvas.x + m.x;
                    const my = canvas.y + m.y;
                    raylib.drawCircleLinesV(.{ .x = mx, .y = my }, p.markR, c);
                    raylib.drawLine(i(mx - p.markR - 6), i(my), i(mx + p.markR + 6), i(my), c);
                    raylib.drawLine(i(mx), i(my - p.markR - 6), i(mx), i(my + p.markR + 6), c);
                    var buf: [64]u8 = undefined;
                    const s = std.fmt.bufPrint(buf[0..], "mouse: ({d}, {d})", .{ i(mx), i(my) }) catch unreachable;
                    buf[s.len] = 0;
                    raylib.drawTextEx(pg.uiFont, buf[0..s.len:0], .{ .x = canvas.x + 12, .y = canvas.y + 12 }, 22, 1, raylib.Color.light_gray);
                    for (marks[0..markCount]) |mk| {
                        raylib.drawCircleV(.{ .x = canvas.x + mk.x, .y = canvas.y + mk.y }, p.markR, raylib.Color.blue);
                    }
                    raylib.drawTextEx(pg.uiFont, "Left-click to place markers", .{ .x = canvas.x + 12, .y = canvas.y + 40 }, 18, 1, raylib.Color.gray);
                },
            }
        }

        fn controls(ctx: pg.ControlsCtx) void {
            const panel = ctx.panel;
            switch (kind) {
                .keyboard => panel.sliderInt("Move speed", &p.speed, 40, 700),
                .mouse => {
                    panel.sliderInt("Marker size", &p.markR, 2, 30);
                    panel.gap(4);
                    panel.colorPicker("Cursor color", &p.color);
                    if (panel.button("Clear markers")) markCount = 0;
                },
            }
        }

        fn reset() void {
            p = .{};
            sqX = 300;
            sqY = 280;
            markCount = 0;
        }

        fn writeCode(buf: []u8) []const u8 {
            const c = p.color;
            return switch (kind) {
                .keyboard => std.fmt.bufPrint(
                    buf,
                    "if (raylib.isKeyDown(.w)) y -= {d} * raylib.getFrameTime();",
                    .{i(p.speed)},
                ) catch buf,
                .mouse => std.fmt.bufPrint(
                    buf,
                    "raylib.drawCircleV(raylib.getMousePosition(), {d}, Color.init({d}, {d}, {d}, {d}));",
                    .{ i(p.markR), c.r, c.g, c.b, c.a },
                ) catch buf,
            };
        }

        fn i(v: f32) i32 {
            return @intFromFloat(v + 0.5);
        }
    };

    return .{
        .name = switch (kind) {
            .keyboard => "isKeyDown",
            .mouse => "getMousePosition",
        },
        .hint = switch (kind) {
            .keyboard => "Move with WASD/arrows while the key is held (continuous).",
            .mouse => "Follow the mouse; left-click places markers.",
        },
        .update = S.update,
        .draw = S.draw,
        .drawControls = S.controls,
        .reset = S.reset,
        .writeCode = S.writeCode,
    };
}

pub const isKeyDownDemo = makeDemo(.keyboard);
pub const getMousePositionDemo = makeDemo(.mouse);
