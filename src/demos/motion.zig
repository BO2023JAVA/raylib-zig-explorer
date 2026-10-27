// 动态模块：getFrameTime（按帧时间做与帧率无关的动画）、checkCollisionRecs（矩形碰撞检测）、
// getRandomValue（随机粒子）。
const std = @import("std");
const raylib = @import("raylib");
const pg = @import("../playground.zig");

const CANVAS_W: f32 = 736;
const CANVAS_H: f32 = 618;

const Kind = enum { bounce, collision, particles };

const Params = struct {
    // 弹球：速度 / 半径
    speed: f32 = 180, radius: f32 = 24,
    // 碰撞：移动块速度 / 颜色
    cSpeed: f32 = 120,
    // 粒子：数量 / 速度
    count: f32 = 20, pSpeed: f32 = 100,
    color: raylib.Color = raylib.Color.orange,
};

fn makeDemo(comptime kind: Kind) pg.Demo {
    const S = struct {
        var p: Params = .{};

        // —— 弹球状态 ——
        var bx: f32 = 300;
        var by: f32 = 200;
        var dx: f32 = 1.0;
        var dy: f32 = 0.8;

        // —— 碰撞状态 ——
        var ax: f32 = 120;
        var dir: f32 = 1;

        // —— 粒子状态 ——
        const MaxParts = 40;
        const Part = struct { x: f32, y: f32, vx: f32, vy: f32, r: f32, c: raylib.Color };
        var parts: [MaxParts]Part = undefined;
        var partCount: usize = 0;
        var partInited = false;

        fn spawnPart() Part {
            return .{
                .x = @floatFromInt(raylib.getRandomValue(0, @intFromFloat(CANVAS_W))),
                .y = @floatFromInt(raylib.getRandomValue(0, @intFromFloat(CANVAS_H))),
                .vx = @floatFromInt(raylib.getRandomValue(-120, 120)),
                .vy = @floatFromInt(raylib.getRandomValue(-120, 120)),
                .r = @floatFromInt(raylib.getRandomValue(2, 10)),
                .c = randColor(),
            };
        }

        fn randColor() raylib.Color {
            const palette = [_]raylib.Color{
                raylib.Color.red,
                raylib.Color.orange,
                raylib.Color.yellow,
                raylib.Color.lime,
                raylib.Color.sky_blue,
                raylib.Color.blue,
                raylib.Color.purple,
                raylib.Color.pink,
            };
            return palette[@intCast(@mod(raylib.getRandomValue(0, @as(i32, palette.len) - 1), @as(i32, palette.len)))];
        }

        fn update() void {
            const dt = raylib.getFrameTime();
            switch (kind) {
                .bounce => {
                    bx += dx * p.speed * dt;
                    by += dy * p.speed * dt;
                    if (bx < p.radius or bx > CANVAS_W - p.radius) {
                        dx = -dx;
                        bx = std.math.clamp(bx, p.radius, CANVAS_W - p.radius);
                    }
                    if (by < p.radius or by > CANVAS_H - p.radius) {
                        dy = -dy;
                        by = std.math.clamp(by, p.radius, CANVAS_H - p.radius);
                    }
                },
                .collision => {
                    ax += dir * p.cSpeed * dt;
                    if (ax > CANVAS_W - 160) {
                        ax = CANVAS_W - 160;
                        dir = -1;
                    }
                    if (ax < 0) {
                        ax = 0;
                        dir = 1;
                    }
                },
                .particles => {
                    const want: usize = @intFromFloat(p.count);
                    if (!partInited or partCount != want) {
                        partInited = true;
                        partCount = @min(want, MaxParts);
                        for (0..partCount) |idx| parts[idx] = spawnPart();
                    }
                    for (0..partCount) |idx| {
                        var pt = &parts[idx];
                        pt.x += pt.vx * dt;
                        pt.y += pt.vy * dt;
                        if (pt.x < 0 or pt.x > CANVAS_W) pt.vx = -pt.vx;
                        if (pt.y < 0 or pt.y > CANVAS_H) pt.vy = -pt.vy;
                    }
                },
            }
        }

        fn draw(canvas: raylib.Rectangle) void {
            switch (kind) {
                .bounce => {
                    raylib.drawCircleV(.{ .x = canvas.x + bx, .y = canvas.y + by }, p.radius, p.color);
                    var buf: [64]u8 = undefined;
                    const s = std.fmt.bufPrint(buf[0..], "dt = {d:.3} s  (frame-independent)", .{raylib.getFrameTime()}) catch unreachable;
                    buf[s.len] = 0;
                    raylib.drawTextEx(pg.uiFont, buf[0..s.len:0], .{ .x = canvas.x + 12, .y = canvas.y + 12 }, 20, 1, raylib.Color.light_gray);
                },
                .collision => {
                    const a = raylib.Rectangle.init(canvas.x + ax, canvas.y + 200, 140, 120);
                    const b = raylib.Rectangle.init(canvas.x + (CANVAS_W - 160) / 2.0, canvas.y + 320, 160, 160);
                    const hit = raylib.checkCollisionRecs(a, b);
                    const hitColor = if (hit) raylib.Color.red else raylib.Color.light_gray;
                    raylib.drawRectangleRec(a, p.color);
                    raylib.drawRectangleRec(b, raylib.Color.blue);
                    raylib.drawRectangleLinesEx(a, 3, hitColor);
                    raylib.drawRectangleLinesEx(b, 3, hitColor);
                    const msg: [:0]const u8 = if (hit) "COLLISION!" else "no collision";
                    raylib.drawTextEx(pg.uiFont, msg, .{ .x = canvas.x + 12, .y = canvas.y + 12 }, 24, 1, hitColor);
                },
                .particles => {
                    for (0..partCount) |idx| {
                        const pt = parts[idx];
                        raylib.drawCircleV(.{ .x = canvas.x + pt.x, .y = canvas.y + pt.y }, pt.r, pt.c);
                    }
                    var buf: [64]u8 = undefined;
                    const s = std.fmt.bufPrint(buf[0..], "particles: {d}", .{partCount}) catch unreachable;
                    buf[s.len] = 0;
                    raylib.drawTextEx(pg.uiFont, buf[0..s.len:0], .{ .x = canvas.x + 12, .y = canvas.y + 12 }, 20, 1, raylib.Color.light_gray);
                },
            }
        }

        fn controls(ctx: pg.ControlsCtx) void {
            const panel = ctx.panel;
            switch (kind) {
                .bounce => {
                    panel.sliderInt("Speed", &p.speed, 40, 500);
                    panel.sliderInt("Radius", &p.radius, 6, 80);
                    panel.gap(4);
                    panel.colorPicker("Color", &p.color);
                },
                .collision => {
                    panel.sliderInt("Block speed", &p.cSpeed, 20, 400);
                    panel.gap(4);
                    panel.colorPicker("Block color", &p.color);
                },
                .particles => {
                    panel.sliderInt("Count", &p.count, 2, MaxParts);
                    panel.gap(4);
                    panel.colorPicker("Color", &p.color);
                },
            }
        }

        fn reset() void {
            p = .{};
            bx = 300;
            by = 200;
            dx = 1.0;
            dy = 0.8;
            ax = 120;
            dir = 1;
            partCount = 0;
            partInited = false;
        }

        fn writeCode(buf: []u8) []const u8 {
            return switch (kind) {
                .bounce => std.fmt.bufPrint(
                    buf,
                    "pos.x += vx * {d} * raylib.getFrameTime();",
                    .{i(p.speed)},
                ) catch buf,
                .collision => std.fmt.bufPrint(
                    buf,
                    "const hit = raylib.checkCollisionRecs(a, b); if (hit) drawRectangleRec(a, RED);",
                    .{},
                ) catch buf,
                .particles => std.fmt.bufPrint(
                    buf,
                    "const x = raylib.getRandomValue(0, 100); // random int in [min,max]",
                    .{},
                ) catch buf,
            };
        }

        fn i(v: f32) i32 {
            return @intFromFloat(v + 0.5);
        }
    };

    return .{
        .name = switch (kind) {
            .bounce => "getFrameTime",
            .collision => "checkCollisionRecs",
            .particles => "getRandomValue",
        },
        .hint = switch (kind) {
            .bounce => "Move by getFrameTime() so speed is frame-rate independent.",
            .collision => "Detect overlap between two rectangles.",
            .particles => "Spawn objects with random position/velocity/color.",
        },
        .update = S.update,
        .draw = S.draw,
        .drawControls = S.controls,
        .reset = S.reset,
        .writeCode = S.writeCode,
    };
}

pub const getFrameTimeDemo = makeDemo(.bounce);
pub const checkCollisionRecsDemo = makeDemo(.collision);
pub const getRandomValueDemo = makeDemo(.particles);
