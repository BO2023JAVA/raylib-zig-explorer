// 综合演示：一个用 drawRectangle 画出来的"接方块"小游戏。
// 综合了键盘输入、碰撞检测、随机下落、计分与重开 —— 对应难度路线图的第 6 级"整合成小游戏"。
const std = @import("std");
const raylib = @import("raylib");
const pg = @import("../playground.zig");

const CANVAS_W: f32 = 736;
const CANVAS_H: f32 = 618;

const ItemCount = 8;
const Item = struct { x: f32, y: f32, size: f32, speed: f32, color: raylib.Color };

const Params = struct {
    fall_speed: f32 = 90,
    player_speed: f32 = 420,
    player_color: raylib.Color = raylib.Color.sky_blue,
};

const S = struct {
    var p: Params = .{};
    var px: f32 = 300; // 玩家方块中心 X（画布局部）
    var score: i32 = 0;
    var items: [ItemCount]Item = undefined;
    var inited = false;

    const pw: f32 = 90;
    const ph: f32 = 18;

    fn spawn() Item {
        return .{
            .x = @floatFromInt(raylib.getRandomValue(10, @intFromFloat(CANVAS_W - 60))),
            .y = -@as(f32, @floatFromInt(raylib.getRandomValue(30, 120))),
            .size = @floatFromInt(raylib.getRandomValue(18, 34)),
            .speed = p.fall_speed + @as(f32, @floatFromInt(raylib.getRandomValue(0, 70))),
            .color = randColor(),
        };
    }

    fn randColor() raylib.Color {
        const palette = [_]raylib.Color{
            raylib.Color.orange,
            raylib.Color.magenta,
            raylib.Color.sky_blue,
            raylib.Color.lime,
            raylib.Color.purple,
            raylib.Color.gold,
        };
        return palette[@intCast(@mod(raylib.getRandomValue(0, @as(i32, palette.len) - 1), @as(i32, palette.len)))];
    }

    fn update() void {
        const dt = raylib.getFrameTime();
        if (!inited) {
            inited = true;
            score = 0;
            for (&items) |*it| it.* = spawn();
        }
        // 玩家左右移动
        if (raylib.isKeyDown(.left) or raylib.isKeyDown(.a)) px -= p.player_speed * dt;
        if (raylib.isKeyDown(.right) or raylib.isKeyDown(.d)) px += p.player_speed * dt;
        px = std.math.clamp(px, 0, CANVAS_W - pw);
        const player = raylib.Rectangle.init(px, CANVAS_H - ph - 14, pw, ph);
        // 方块下落 + 判定
        for (&items) |*it| {
            it.y += it.speed * dt;
            const rec = raylib.Rectangle.init(it.x, it.y, it.size, it.size);
            if (raylib.checkCollisionRecs(rec, player)) {
                score += 1;
                it.* = spawn();
            } else if (it.y > CANVAS_H) {
                it.* = spawn();
            }
        }
    }

    fn draw(canvas: raylib.Rectangle) void {
        raylib.drawRectangle(i(canvas.x + px), i(canvas.y + CANVAS_H - ph - 14), i(pw), i(ph), p.player_color);
        for (items) |it| {
            raylib.drawRectangle(i(canvas.x + it.x), i(canvas.y + it.y), i(it.size), i(it.size), it.color);
        }
        var buf: [64]u8 = undefined;
        const s = std.fmt.bufPrint(buf[0..], "Score: {d}", .{score}) catch unreachable;
        buf[s.len] = 0;
        raylib.drawTextEx(pg.uiFont, buf[0..s.len:0], .{ .x = canvas.x + 12, .y = canvas.y + 12 }, 26, 1, raylib.Color.light_gray);
        raylib.drawTextEx(pg.uiFont, "Arrows / A D to move, catch the blocks", .{ .x = canvas.x + 12, .y = canvas.y + 44 }, 18, 1, raylib.Color.gray);
    }

    fn controls(ctx: pg.ControlsCtx) void {
        const panel = ctx.panel;
        panel.sliderInt("Fall speed", &p.fall_speed, 20, 300);
        panel.sliderInt("Player speed", &p.player_speed, 100, 800);
        panel.gap(4);
        panel.colorPicker("Player color", &p.player_color);
        if (panel.button("Reset game")) {
            score = 0;
            inited = false;
        }
    }

    fn reset() void {
        p = .{};
        px = 300;
        score = 0;
        inited = false;
    }

    fn writeCode(buf: []u8) []const u8 {
        return std.fmt.bufPrint(
            buf,
            "raylib.drawRectangle(x, y, {d}, {d}, color); // a filled rectangle",
            .{i(pw), i(ph)},
        ) catch buf;
    }

    fn i(v: f32) i32 {
        return @intFromFloat(v + 0.5);
    }
};

pub const drawRectangleGame: pg.Demo = .{
    .name = "drawRectangle",
    .hint = "Mini game: move the paddle and catch falling blocks.",
    .update = S.update,
    .draw = S.draw,
    .drawControls = S.controls,
    .reset = S.reset,
    .writeCode = S.writeCode,
};
