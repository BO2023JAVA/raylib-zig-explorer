// 教学实验场框架：Demo 接口、课程注册表、右侧参数面板的通用控件。
// main.zig 只依赖这个文件里的接口，不关心每节课的具体内容。
// 新增课程 = 新建一个实现 Demo 接口的文件，并注册到 demos 数组。
const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");
const shapes = @import("demos/shapes.zig");
const more_shapes = @import("demos/more_shapes.zig");
const text_demos = @import("demos/text.zig");
const input = @import("demos/input.zig");
const texture = @import("demos/texture.zig");
const motion = @import("demos/motion.zig");
const game = @import("demos/game.zig");
const audio = @import("demos/audio.zig");
const models3d = @import("demos/models3d.zig");
pub const catalog = @import("catalog.zig");
pub const zh = @import("zh.zig");
const dt = @import("demo_types.zig");
const auto_demo = @import("auto_demo.zig");

pub const Demo = dt.Demo;
pub const ControlsCtx = dt.ControlsCtx;
pub const Panel = dt.Panel;

/// 应用当前使用的 UI 字体（main.zig 加载后写入，供各 demo 的叠加文字使用）
pub var uiFont: raylib.Font = undefined;

/// 文档页"复制签名"按钮的已复制反馈截止时间（getTime 秒）
var docCopyFlashUntil: f64 = 0;

/// 课程注册表：先手写的教学 demo（按难度顺序），再把目录里所有可自动演示的
/// API 用自动引擎批量生成 demo 追加在后。列表里的 * 由 main.zig 用 findDemo 判断。
pub const demos = blk: {
    @setEvalBranchQuota(1_000_000);
    const hand = [_]dt.Demo{
        // 第 1 级：基础图元
        shapes.lineDemo,
        shapes.circleDemo,
        shapes.rectangleDemo,
        more_shapes.triangleDemo,
        more_shapes.ringDemo,
        more_shapes.roundedDemo,
        // 第 2 级：文字 + 输入
        text_demos.drawTextDemo,
        text_demos.drawTextExDemo,
        input.isKeyDownDemo,
        input.getMousePositionDemo,
        // 第 3 级：纹理 / 动画 / 碰撞
        texture.genImageColorDemo,
        motion.getFrameTimeDemo,
        motion.checkCollisionRecsDemo,
        // 第 4 级：随机 / 音频
        motion.getRandomValueDemo,
        audio.initAudioDeviceDemo,
        // 第 5 级：3D
        models3d.drawCubeDemo,
        // 第 6 级：整合成小游戏
        game.drawRectangleGame,
    };
    const auto_count = auto_demo.AUTO;
    const total = hand.len + auto_count;
    var out: [total]dt.Demo = undefined;
    for (hand, 0..) |d, i| out[i] = d;
    var idx = hand.len;
    for (catalog.entries, 0..) |e, gi| {
        if (auto_demo.autoDemoFor(e, gi)) |d| {
            out[idx] = d;
            idx += 1;
        }
    }
    break :blk out;
};

// ── 全量 API 目录与交互 demo 的桥接 ──────────────────────────────────────────

/// 按 API 名查交互 demo；没做成交互 demo 的函数返回 null（走文档视图）
pub fn findDemo(name: []const u8) ?Demo {
    for (demos) |demo| {
        if (std.mem.eql(u8, demo.name, name)) return demo;
    }
    return null;
}

/// 自动换行绘制（兼容中英混排），返回最后一行下方的 y 坐标。
/// raylib 没有 kerning，整串宽度 = 单码点宽度之和，
/// 所以逐码点测宽累加即可，超 maxWidth 换行。
pub fn drawWrapped(
    font: raylib.Font,
    text: []const u8,
    x: f32,
    startY: f32,
    maxWidth: f32,
    size: f32,
    color: raylib.Color,
) f32 {
    var y = startY;
    var line: [1024:0]u8 = undefined;
    var lineLen: usize = 0;
    var lineW: f32 = 0;
    const lineHeight = size + 7;

    // 逐 UTF-8 码点遍历，按累计像素宽度判断换行
    var i: usize = 0;
    while (i < text.len) {
        const cp_len = utf8CharLen(text[i]);
        if (cp_len == 0 or lineLen + cp_len > 1022) {
            i += 1;
            continue;
        }
        var cpBuf: [8:0]u8 = undefined;
        @memcpy(cpBuf[0..cp_len], text[i .. i + cp_len]);
        cpBuf[cp_len] = 0;
        const cpW = raylib.measureTextEx(font, cpBuf[0..cp_len:0], size, 1).x;

        if (lineW + cpW > maxWidth and lineLen > 0) {
            line[lineLen] = 0;
            raylib.drawTextEx(font, line[0..lineLen:0], .{ .x = x, .y = y }, size, 1, color);
            y += lineHeight;
            lineLen = 0;
            lineW = 0;
        }
        @memcpy(line[lineLen .. lineLen + cp_len], text[i .. i + cp_len]);
        lineLen += cp_len;
        lineW += cpW;
        i += cp_len;
    }
    if (lineLen > 0) {
        line[lineLen] = 0;
        raylib.drawTextEx(font, line[0..lineLen:0], .{ .x = x, .y = y }, size, 1, color);
        y += lineHeight;
    }
    return y;
}

/// 返回 UTF-8 码点的字节长度；非法字节返回 0
fn utf8CharLen(b: u8) usize {
    if (b < 0x80) return 1;
    if ((b & 0xE0) == 0xC0) return 2;
    if ((b & 0xF0) == 0xE0) return 3;
    if ((b & 0xF8) == 0xF0) return 4;
    return 0; // continuation byte，跳过
}

/// 没有交互 demo 的函数：在画布区显示 API 文档页（名字 / 调用方法 / 说明）
pub fn drawDocPage(font: raylib.Font, bounds: raylib.Rectangle, e: catalog.Entry) void {
    var y = bounds.y + 6;

    // Zig 调用名（大标题）
    raylib.drawTextEx(font, e.name, .{ .x = bounds.x, .y = y }, 32, 1, raylib.Color.light_gray);
    y += 50;

    // 调用方法：完整 zig 签名（函数名 + 参数名/类型 + 返回类型）
    raylib.drawTextEx(font, "调用方法", .{ .x = bounds.x, .y = y }, 18, 1, raylib.Color.gray);
    y += 26;
    var sBuf: [400:0]u8 = undefined;
    const prefix: []const u8 = if (e.module == .gui) "raygui." else "raylib.";
    const sigLine = std.fmt.bufPrint(sBuf[0..400], "{s}{s}", .{ prefix, e.sig }) catch unreachable;
    sBuf[sigLine.len] = 0;

    // 右上角"复制签名"按钮：把完整调用行复制到剪贴板，方便直接粘进自己的工程
    {
        const now = raylib.getTime();
        const label: [:0]const u8 = if (now < docCopyFlashUntil) "已复制" else "复制签名";
        const btnRect = raylib.Rectangle.init(bounds.x + bounds.width - 110, bounds.y + 4, 104, 26);
        if (raygui.button(btnRect, label)) {
            docCopyFlashUntil = now + 1.2;
            raylib.setClipboardText(sBuf[0..sigLine.len:0]);
        }
    }

    y = drawWrapped(font, sBuf[0..sigLine.len], bounds.x + 8, y, bounds.width - 8, 20, raylib.Color.sky_blue);
    y += 16;

    // 中文说明（优先）；无中文翻译时回退英文 doc
    const cn = zh.desc(e.c_name);
    const docText = if (cn.len > 0) cn else e.doc;
    _ = drawWrapped(font, docText, bounds.x, y, bounds.width, fontSizeDoc, raylib.Color.light_gray);
}

const fontSizeDoc: f32 = 22;
