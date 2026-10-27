// 演示接口的公共类型：Demo 契约、右侧参数面板、当前 UI 字体。
// 独立成文件是为了让 playground（课程注册表）和 auto_demo（自动演示引擎）
// 都能引用这些类型，避免两者互相 import 造成循环依赖。
const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

/// 全局 UI 字体（main.zig 加载后写入；playground 与各 demo 共用，保证字体统一）
pub var uiFont: raylib.Font = undefined;

/// 每一节"实验课"都实现这个接口
pub const Demo = struct {
    /// 左侧列表与画布标题中显示的 API 名称（ASCII，默认字体不支持中文）
    name: [:0]const u8,
    /// 一句话说明这个 API 做什么
    hint: [:0]const u8,
    /// 每帧更新逻辑（动画、输入），静态场景可省略
    update: ?*const fn () void = null,
    /// 把当前参数画到左侧画布，坐标相对于 canvas 的左上角
    draw: *const fn (canvas: raylib.Rectangle) void,
    /// 在右侧面板构建本场景的控件
    drawControls: *const fn (ctx: ControlsCtx) void,
    /// 恢复默认参数
    reset: *const fn () void,
    /// 生成当前参数对应的一行 Zig 代码，写入 buf 并返回实际切片
    writeCode: *const fn (buf: []u8) []const u8,
};

/// 传给 drawControls 的上下文
pub const ControlsCtx = struct {
    panel: *Panel,
    canvasWidth: f32,
    canvasHeight: f32,
};

/// 右侧面板：一个从上往下排列控件的简易垂直布局器（VB 属性窗口的感觉）
pub const Panel = struct {
    x: f32,
    y: f32,
    w: f32,
    cursor: f32 = 12,
    scroll: f32 = 0, // 内容滚动偏移（像素），参数多于一屏时由外部按滚轮维护

    pub fn init(bounds: raylib.Rectangle) Panel {
        return .{ .x = bounds.x + 12, .y = bounds.y + 12, .w = bounds.width - 24 };
    }

    /// 申请下一行区域并把光标下移
    pub fn row(self: *Panel, height: f32) raylib.Rectangle {
        const r = raylib.Rectangle.init(self.x, self.y + self.cursor - self.scroll, self.w, height);
        self.cursor += height + 8;
        return r;
    }

    pub fn gap(self: *Panel, px: f32) void {
        self.cursor += px;
    }

    pub fn title(self: *Panel, text: [:0]const u8) void {
        _ = raygui.label(self.row(28), text);
    }

    /// 一行"标签 + 滑块 + 当前值"，值按整数显示（像素、半径这类参数）
    pub fn sliderInt(self: *Panel, text: [:0]const u8, value: *f32, min: f32, max: f32) void {
        _ = raygui.label(self.row(26), text);
        const r = self.row(28);
        _ = raygui.sliderBar(
            raylib.Rectangle.init(r.x, r.y, r.width - 60, r.height),
            "",
            "",
            value,
            min,
            max,
        );
        var numBuf: [32:0]u8 = undefined;
        const numText = std.fmt.bufPrint(numBuf[0..32], "{d}", .{@as(i32, @intFromFloat(value.* + 0.5))}) catch unreachable;
        numBuf[numText.len] = 0;
        _ = raygui.label(raylib.Rectangle.init(r.x + r.width - 54, r.y, 54, r.height), numBuf[0..numText.len:0]);
    }

    pub fn check(self: *Panel, text: [:0]const u8, checked: *bool) void {
        _ = raygui.checkBox(self.row(28), text, checked);
    }

    pub fn colorPicker(self: *Panel, text: [:0]const u8, color: *raylib.Color) void {
        _ = raygui.label(self.row(26), text);
        _ = raygui.colorPicker(self.row(168), "", color);
    }

    pub fn button(self: *Panel, text: [:0]const u8) bool {
        return raygui.button(self.row(34), text);
    }
};
