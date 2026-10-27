// audio 模块：initAudioDevice —— 演示音频设备的初始化 / 关闭 / 状态查询。
// raylib 没有内置"生成音调"的函数，真正播放需要外部 .wav/.ogg 文件（放入 resources/），
// 所以这里只演示设备生命周期和 isAudioDeviceReady() 查询。
const std = @import("std");
const raylib = @import("raylib");
const pg = @import("../playground.zig");

const S = struct {
    var on = false;

    fn draw(canvas: raylib.Rectangle) void {
        const ready = raylib.isAudioDeviceReady();
        const state: []const u8 = if (ready) "READY" else "NOT READY";
        var buf: [96]u8 = undefined;
        const s = std.fmt.bufPrint(buf[0..], "Audio device: {s}", .{state}) catch unreachable;
        buf[s.len] = 0;
        raylib.drawTextEx(pg.uiFont, buf[0..s.len:0], .{ .x = canvas.x + 12, .y = canvas.y + 12 }, 24, 1, raylib.Color.light_gray);
        raylib.drawTextEx(pg.uiFont, "Use the button to init / close the audio device.", .{ .x = canvas.x + 12, .y = canvas.y + 44 }, 18, 1, raylib.Color.gray);
        raylib.drawTextEx(pg.uiFont, "Then LoadSound / PlaySound with a real audio file.", .{ .x = canvas.x + 12, .y = canvas.y + 68 }, 18, 1, raylib.Color.gray);
    }

    fn controls(ctx: pg.ControlsCtx) void {
        const panel = ctx.panel;
        if (panel.button(if (on) "Close audio device" else "Init audio device")) {
            if (on) {
                raylib.closeAudioDevice();
                on = false;
            } else {
                raylib.initAudioDevice();
                on = true;
            }
        }
        panel.gap(8);
        if (panel.button("Close on exit / Reset")) {
            if (on) raylib.closeAudioDevice();
            on = false;
        }
    }

    fn reset() void {
        if (on) raylib.closeAudioDevice();
        on = false;
    }

    fn writeCode(buf: []u8) []const u8 {
        return std.fmt.bufPrint(
            buf,
            "raylib.initAudioDevice(); const s = raylib.loadSound(\"resources/snd.wav\") catch unreachable;",
            .{},
        ) catch buf;
    }
};

pub const initAudioDeviceDemo: pg.Demo = .{
    .name = "initAudioDevice",
    .hint = "Init/close the audio device and query its ready state.",
    .draw = S.draw,
    .drawControls = S.controls,
    .reset = S.reset,
    .writeCode = S.writeCode,
};
