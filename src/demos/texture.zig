// textures 模块：genImageColor（运行时生成纯色图）+ drawTexture（绘制纹理）。
// 全部在内存里生成图片，不需要外部图片资源。
const std = @import("std");
const raylib = @import("raylib");
const pg = @import("../playground.zig");

const Params = struct {
    color: raylib.Color = raylib.Color.blue,
    scale: f32 = 100, // 相对画布的填充百分比
    x: f32 = 0, y: f32 = 0,
};

const S = struct {
    var p: Params = .{};
    var tex: ?raylib.Texture2D = null;
    var applied: raylib.Color = raylib.Color.init(0, 0, 0, 0);
    var texW: i32 = 0;
    var texH: i32 = 0;

    fn colorEq(a: raylib.Color, b: raylib.Color) bool {
        return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
    }

    fn ensure(canvas: raylib.Rectangle) void {
        const w: i32 = @intFromFloat(canvas.width);
        const h: i32 = @intFromFloat(canvas.height);
        if (tex != null and colorEq(applied, p.color) and texW == w and texH == h) return;
        const img = raylib.genImageColor(w, h, p.color);
        const t = raylib.loadTextureFromImage(img) catch return;
        raylib.unloadImage(img);
        if (tex) |old| raylib.unloadTexture(old);
        tex = t;
        applied = p.color;
        texW = w;
        texH = h;
    }

    fn draw(canvas: raylib.Rectangle) void {
        ensure(canvas);
        if (tex) |t| {
            const fw: f32 = @floatFromInt(t.width);
            const dw = fw * p.scale / 100.0;
            raylib.drawTextureEx(t, .{ .x = canvas.x + p.x, .y = canvas.y + p.y }, 0, dw / fw, raylib.Color.white);
        }
    }

    fn controls(ctx: pg.ControlsCtx) void {
        const panel = ctx.panel;
        panel.sliderInt("X", &p.x, 0, ctx.canvasWidth);
        panel.sliderInt("Y", &p.y, 0, ctx.canvasHeight);
        panel.sliderInt("Scale %", &p.scale, 10, 100);
        panel.gap(4);
        panel.colorPicker("Color", &p.color);
    }

    fn reset() void {
        if (tex) |t| raylib.unloadTexture(t);
        tex = null;
        p = .{};
    }

    fn writeCode(buf: []u8) []const u8 {
        const c = p.color;
        return std.fmt.bufPrint(
            buf,
            "const img = raylib.genImageColor({d}, {d}, Color.init({d}, {d}, {d}, {d})); const tex = raylib.loadTextureFromImage(img) catch unreachable;",
            .{ texW, texH, c.r, c.g, c.b, c.a },
        ) catch buf;
    }
};

pub const genImageColorDemo: pg.Demo = .{
    .name = "genImageColor",
    .hint = "Generate a solid-color image at runtime and draw it as a texture.",
    .draw = S.draw,
    .drawControls = S.controls,
    .reset = S.reset,
    .writeCode = S.writeCode,
};
