// 自动演示引擎：编译期扫描 catalog 与 raylib 绑定，对"可安全自动调用"的函数
// 自动生成交互 Demo（参数面板 + 画布调用 + 代码行 + 重置）。
//
// 一条函数能被自动演示，须满足：
//   - 是 raylib 绑定里的顶层 pub fn（类型方法 / 类型常量自动跳过）；
//   - 参数与返回值都是"简单类型"：f32/整数/bool/Color/Vector2/Vector3/Rectangle/
//     字符串切片/枚举 —— 这样引擎能为每个参数自动生成控件；
//   - 不属于 models/audio 模块，且不是生命周期 / 资源加载 / 控制流函数
//     （这些函数要么需要外部素材、要么每帧调用会破坏渲染循环，一律走文档页）。
const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");
const dt = @import("demo_types.zig");
const catalog = @import("catalog.zig");

pub const MAX_PARAMS = 8;

/// 每个自动 demo 的参数状态池。下标即参数的序号（0..params.len-1），
/// 每种类型独立存储，调用/控件/代码都按参数序号取。
pub const Pool = struct {
    f: [8]f32 = @splat(60), // f32 与整数（整数按 f32 存，调用时转回）
    b: [8]bool = @splat(false),
    c: [8]raylib.Color = undefined, // 默认色在 buildStates 里按序填亮色
    v2: [8]raylib.Vector2 = @splat(raylib.Vector2.init(300, 250)),
    v3: [8]raylib.Vector3 = @splat(raylib.Vector3.init(60, 60, 60)),
    r: [8]raylib.Rectangle = @splat(raylib.Rectangle.init(60, 60, 120, 90)),
    s: [8][64:0]u8 = std.mem.zeroes([8][64:0]u8), // 字符串参数（固定缓冲）
    sLen: [8]usize = @splat(0),
    e: [8]i32 = @splat(0), // 枚举参数（存 tag 的整数值，固定不可改）
    focus: [8]bool = @splat(false), // 字符串输入框的编辑焦点
};

const COLOR_PALETTE = [_]raylib.Color{
    raylib.Color.orange,
    raylib.Color.sky_blue,
    raylib.Color.red,
    raylib.Color.green,
    raylib.Color.gold,
    raylib.Color.violet,
    raylib.Color.pink,
    raylib.Color.maroon,
};

fn isInt(comptime T: type) bool {
    return @typeInfo(T) == .int;
}

const Kind = enum { f, b, color, v2, v3, rect, str, e };

fn paramKind(comptime T: type) ?Kind {
    const info = @typeInfo(T);
    return switch (info) {
        .float => if (T == f32 or T == f64) .f else null,
        .int => .f,
        .bool => .b,
        .@"enum" => .e,
        .pointer => if (info.pointer.size == .slice and info.pointer.child == u8) .str else null,
        else => switch (T) {
            raylib.Color => .color,
            raylib.Vector2 => .v2,
            raylib.Vector3 => .v3,
            raylib.Rectangle => .rect,
            else => null,
        },
    };
}

fn returnOk(comptime T: ?type) bool {
    const t = T orelse return false;
    if (t == void or t == bool) return true;
    if (isInt(t) or t == f32 or t == f64) return true;
    const info = @typeInfo(t);
    if (info == .@"enum") return true;
    // 字符串返回值一律不自动演示：绑定层用 std.mem.span 转换，C 侧返回 NULL 时
    // （如 getFileExtension/getEnvironmentVar/textReplaceBetweenAlloc 等）直接 panic，
    // 且字符串参数在面板里可编辑，无法靠默认值规避。
    return t == raylib.Color or t == raylib.Vector2 or t == raylib.Vector3 or t == raylib.Rectangle;
}

/// 生命周期 / 资源加载 / 控制流 / 输入消耗类函数：即使参数简单也不自动演示。
fn blockedName(comptime name: [:0]const u8) bool {
    const prefixes = [_][]const u8{
        "load", "unload", "init", "close", "open", "save", "export", "import",
        "start", "stop", "begin", "end", "gen", "update", "attach", "detach",
        "set", "trace", "clear", "swap", "take", "push", "pop", "translate",
        "rotate", "scale", "enable", "disable", "hide", "show", "request",
        // 阻塞 / 窗口状态切换 / 输入事件消耗：每帧调用会破坏渲染循环
        "wait", "toggle", "poll", "focus",
    };
    for (prefixes) |p| {
        if (name.len >= p.len and std.mem.eql(u8, name[0..p.len], p)) return true;
    }
    // 子串黑名单：需要特定硬件状态 / 运行条件，自动默认参数必炸
    const contains = [_][]const u8{
        "Monitor",  // getMonitor* 默认 monitor=60，GLFW 找不到 → 疯狂警告
        "Gamepad",  // 同理 gamepad index 越界
        "Touch",    // touch index 越界
        "Gesture",  // 触摸板手势
    };
    for (contains) |c| {
        if (std.mem.indexOf(u8, name, c) != null) return true;
    }
    // 精确黑名单：
    // - 窗口状态操作（maximize/minimize/restore 每帧调用会把窗口搞死）
    // - 名字查询（传越界 id 返回 NULL，绑定层解引用即闪退）
    const exact = [_][]const u8{
        "maximizeWindow",
        "minimizeWindow",
        "restoreWindow",
        "getMonitorName",
        "getGamepadName",
        "getKeyName",
        "getClipboardText",
        // 字符串查询，C 侧可能返回 NULL，绑定层 span(NULL) 直接 panic：
        // getFileExtension 在无扩展名时返回 NULL；getEnvironmentVar 在变量不存在时返回 NULL
        "getFileExtension",
        "getEnvironmentVar",
        // 数值域非法：saturation/value 要求 [0,1]，默认 60 会让 C 侧 float→uchar 转换 panic
        "colorFromHSV",
    };
    for (exact) |n| {
        if (std.mem.eql(u8, name, n)) return true;
    }
    return false;
}

fn supported(comptime F: anytype, comptime mod: catalog.Module) bool {
    const info = @typeInfo(@TypeOf(F));
    if (info != .@"fn") return false;
    const f = info.@"fn";
    if (f.is_generic or f.attrs.varargs) return false;
    if (mod == .models or mod == .audio) return false;
    if (!returnOk(f.return_type)) return false;
    if (f.param_types.len > MAX_PARAMS) return false;
    for (f.param_types) |pt| {
        const t = pt orelse return false;
        if (paramKind(t) == null) return false;
    }
    return true;
}

fn isAuto(comptime e: catalog.Entry) bool {
    if (blockedName(e.name)) return false;
    if (!@hasDecl(raylib, e.name)) return false;
    return supported(@field(raylib, e.name), e.module);
}

fn autoMap() [catalog.entries.len]?usize {
    return comptime blk: {
        @setEvalBranchQuota(2_000_000);
        var map: [catalog.entries.len]?usize = undefined;
        var k: usize = 0;
        for (catalog.entries, 0..) |e, gi| {
            if (isAuto(e)) {
                map[gi] = k;
                k = k + 1;
            } else {
                map[gi] = null;
            }
        }
        break :blk map;
    };
}
/// 目录条目下标 gi → 它在自动演示里的序号 K（不可自动演示的为 null）。
/// 一次性在编译期算好，避免每个 demo 重复扫描。
const AUTO_MAP = autoMap();

pub const AUTO = blk: {
    @setEvalBranchQuota(2_000_000);
    var n: usize = 0;
    for (AUTO_MAP) |v| {
        if (v != null) {
            n = n + 1;
        }
    }
    break :blk n;
};

pub var states: [AUTO]Pool = buildStates();

fn buildStates() [AUTO]Pool {
    return comptime blk: {
        @setEvalBranchQuota(2_000_000);
        var arr: [AUTO]Pool = undefined;
        for (catalog.entries, 0..) |e, gi| {
            if (AUTO_MAP[gi]) |k| {
                arr[k] = defaultsFor(@field(raylib, e.name));
            }
        }
        break :blk arr;
    };
}

fn enumDefaultName(comptime T: type) [:0]const u8 {
    if (@typeInfo(T) != .@"enum") return "?";
    return @typeInfo(T).@"enum".field_names[0];
}

/// 每个自动 demo 的默认参数（画布无关的"看起来像样"的初值）。
fn defaultsFor(comptime F: anytype) Pool {
    var st = Pool{};
    var ci: usize = 0; // 颜色序号（决定默认色）
    const Fi = @typeInfo(@TypeOf(F)).@"fn";
    inline for (0..Fi.param_types.len) |pi| {
        const T = Fi.param_types[pi].?;
        switch (paramKind(T).?) {
            .f => st.f[pi] = 60,
            .b => st.b[pi] = false,
            .color => {
                st.c[pi] = COLOR_PALETTE[ci % COLOR_PALETTE.len];
                ci += 1;
            },
            .v2 => st.v2[pi] = raylib.Vector2.init(300, 250),
            .v3 => st.v3[pi] = raylib.Vector3.init(60, 60, 60),
            .rect => st.r[pi] = raylib.Rectangle.init(60, 60, 120, 90),
            .str => {
                const d = "Hello, raylib!";
                st.sLen[pi] = d.len;
                @memcpy(st.s[pi][0..d.len], d);
            },
            .e => {
                if (comptime @typeInfo(T) == .@"enum") {
                    const nm = @typeInfo(T).@"enum".field_names[0];
                    const val = @field(T, nm);
                    st.e[pi] = @intFromEnum(val);
                } else {
                    st.e[pi] = 0;
                }
            },
        }
    }
    return st;
}

// ── 把当前参数拼成对函数的调用 ────────────────────────────────────────────

fn Rt(comptime F: anytype) type {
    return @typeInfo(@TypeOf(F)).@"fn".return_type.?;
}

fn argFor(comptime T: type, st: *const Pool, i: usize) T {
    const kind = comptime paramKind(T).?;
    if (kind == .f) {
        if (comptime @typeInfo(T) == .float) return @floatCast(st.f[i]);
        return @intFromFloat(st.f[i]);
    } else if (kind == .b) {
        return st.b[i];
    } else if (kind == .color) {
        return st.c[i];
    } else if (kind == .v2) {
        return st.v2[i];
    } else if (kind == .v3) {
        return st.v3[i];
    } else if (kind == .rect) {
        return st.r[i];
    } else if (kind == .str) {
        const len = st.sLen[i];
        return st.s[i][0..len:0];
    } else {
        if (comptime @typeInfo(T) == .@"enum") return @enumFromInt(st.e[i]);
        return @as(T, undefined);
    }
}

/// 由函数的参数类型列表生成对应的元组类型（供 @call 传参）。
fn ArgsType(comptime F: anytype) type {
    const Fi = @typeInfo(@TypeOf(F)).@"fn";
    comptime var types: [Fi.param_types.len]type = undefined;
    comptime var i: usize = 0;
    while (i < Fi.param_types.len) : (i += 1) {
        types[i] = Fi.param_types[i].?;
    }
    return @Tuple(&types);
}

/// 用运行时 Pool 填满参数元组。
fn buildArgs(comptime F: anytype, st: *const Pool) ArgsType(F) {
    const Fi = @typeInfo(@TypeOf(F)).@"fn";
    var args: ArgsType(F) = undefined;
    inline for (0..Fi.param_types.len) |i| {
        args[i] = argFor(Fi.param_types[i].?, st, i);
    }
    return args;
}

// ── 画布绘制 + 返回值展示 ────────────────────────────────────────────────

fn fmtReturn(comptime T: type, v: T, buf: *[128:0]u8) [:0]const u8 {
    const t = comptime @typeInfo(T);
    // 注意：所有分支必须把文本写进 buf，下方统一从 buf 返回；
    // 直接返回字符串字面量会导致 buf 里的未初始化内存被当成结果显示（曾出现一片问号）
    const s: []const u8 = if (t == .float)
        std.fmt.bufPrint(buf[0..128], "returns: {d:.2}", .{v}) catch buf[0..0]
    else if (t == .int)
        std.fmt.bufPrint(buf[0..128], "returns: {d}", .{v}) catch buf[0..0]
    else if (t == .bool)
        std.fmt.bufPrint(buf[0..128], "returns: {s}", .{if (v) "true" else "false"}) catch buf[0..0]
    else if (t == .@"enum")
        std.fmt.bufPrint(buf[0..128], "returns: {s}", .{@tagName(v)}) catch buf[0..0]
    else if (t == .pointer)
        std.fmt.bufPrint(buf[0..128], "returns: \"{s}\"", .{v}) catch buf[0..0]
    else if (T == raylib.Color)
        std.fmt.bufPrint(buf[0..128], "returns: Color({d},{d},{d},{d})", .{ v.r, v.g, v.b, v.a }) catch buf[0..0]
    else if (T == raylib.Vector2)
        std.fmt.bufPrint(buf[0..128], "returns: ({d:.1},{d:.1})", .{ v.x, v.y }) catch buf[0..0]
    else if (T == raylib.Vector3)
        std.fmt.bufPrint(buf[0..128], "returns: ({d:.1},{d:.1},{d:.1})", .{ v.x, v.y, v.z }) catch buf[0..0]
    else if (T == raylib.Rectangle)
        std.fmt.bufPrint(buf[0..128], "returns: ({d:.0},{d:.0},{d:.0},{d:.0})", .{ v.x, v.y, v.width, v.height }) catch buf[0..0]
    else
        std.fmt.bufPrint(buf[0..128], "returns: ?", .{}) catch buf[0..0];
    buf[s.len] = 0;
    return buf[0..s.len:0];
}

fn drawImpl(comptime F: anytype, comptime K: usize) *const fn (raylib.Rectangle) void {
    const W = struct {
        fn draw(canvas: raylib.Rectangle) void {
            const RtT = Rt(F);
            const isVoid = (RtT == void);
            // 用 2D 相机平移把画布原点挪到 canvas 左上角，这样所有坐标都相对画布。
            const cam = raylib.Camera2D{
                .offset = .{ .x = canvas.x, .y = canvas.y },
                .target = raylib.Vector2.init(0, 0),
                .rotation = 0,
                .zoom = 1,
            };
            raylib.beginMode2D(cam);
            defer raylib.endMode2D();
            if (isVoid) {
                _ = @call(.auto, F, buildArgs(F, &states[K]));
            } else {
                const ret = @call(.auto, F, buildArgs(F, &states[K]));
                var buf: [128:0]u8 = undefined;
                const s = fmtReturn(RtT, ret, &buf);
                // 统一 UI 字体（main 启动时写入 dt.uiFont）
                raylib.drawTextEx(dt.uiFont, s, .{ .x = 10, .y = 10 }, 20, 1, raylib.Color.light_gray);
            }
        }
    };
    return &W.draw;
}

// ── 参数面板控件 ─────────────────────────────────────────────────────────

/// 把 "p<序号><后缀>" 写入 buf，返回 [:0]const u8（仅控件显示，立即使用）
fn plabel(buf: *[24:0]u8, comptime i: usize, comptime suffix: []const u8) [:0]const u8 {
    const s = std.fmt.bufPrint(buf[0..24], "p{d}{s}", .{ i, suffix }) catch unreachable;
    buf[s.len] = 0;
    return buf[0..s.len:0];
}

fn controlsImpl(comptime F: anytype, comptime K: usize) *const fn (ctx: dt.ControlsCtx) void {
    const W = struct {
        fn controls(ctx: dt.ControlsCtx) void {
            const Fi = @typeInfo(@TypeOf(F)).@"fn";
            const panel = ctx.panel;
            const st = &states[K];
            var lbl: [24:0]u8 = undefined;
            panel.title("Parameters");
            inline for (0..Fi.param_types.len) |i| {
                const T = Fi.param_types[i].?;
                switch (paramKind(T).?) {
                    .f => panel.sliderInt(plabel(&lbl, i, ""), &st.f[i], 0, 600),
                    .b => panel.check(plabel(&lbl, i, ""), &st.b[i]),
                    .color => panel.colorPicker(plabel(&lbl, i, ""), &st.c[i]),
                    .v2 => {
                        panel.sliderInt(plabel(&lbl, i, ".x"), &st.v2[i].x, 0, 600);
                        panel.sliderInt(plabel(&lbl, i, ".y"), &st.v2[i].y, 0, 600);
                    },
                    .v3 => {
                        panel.sliderInt(plabel(&lbl, i, ".x"), &st.v3[i].x, 0, 600);
                        panel.sliderInt(plabel(&lbl, i, ".y"), &st.v3[i].y, 0, 600);
                        panel.sliderInt(plabel(&lbl, i, ".z"), &st.v3[i].z, 0, 600);
                    },
                    .rect => {
                        panel.sliderInt(plabel(&lbl, i, ".x"), &st.r[i].x, 0, 600);
                        panel.sliderInt(plabel(&lbl, i, ".y"), &st.r[i].y, 0, 600);
                        panel.sliderInt(plabel(&lbl, i, ".w"), &st.r[i].width, 0, 600);
                        panel.sliderInt(plabel(&lbl, i, ".h"), &st.r[i].height, 0, 600);
                    },
                    .str => {
                        _ = raygui.label(panel.row(20), plabel(&lbl, i, " (text)"));
                        _ = raygui.textBox(panel.row(26), st.s[i][0..64:0], st.focus[i]);
                    },
                    .e => {
                        _ = raygui.label(panel.row(22), plabel(&lbl, i, " (enum)"));
                        _ = raygui.label(panel.row(20), comptime enumDefaultName(T));
                    },
                }
            }
            panel.gap(4);
            _ = panel.button("Reset to defaults");
        }
    };
    return &W.controls;
}

// ── 重置 ──────────────────────────────────────────────────────────────────

fn resetImpl(comptime F: anytype, comptime K: usize) *const fn () void {
    const W = struct {
        fn reset() void {
            states[K] = defaultsFor(F);
        }
    };
    return &W.reset;
}

// ── 代码行 ────────────────────────────────────────────────────────────────

fn fmtArgInto(buf: []u8, comptime T: type, st: *const Pool, i: usize) []const u8 {
    const info = @typeInfo(T);
    switch (info) {
        .float => return std.fmt.bufPrint(buf, "{d:.1}", .{st.f[i]}) catch buf[0..0],
        .int => return std.fmt.bufPrint(buf, "{d}", .{@as(i32, @intFromFloat(st.f[i]))}) catch buf[0..0],
        .bool => return if (st.b[i]) "true" else "false",
        .@"enum" => return comptime enumDefaultName(T),
        .pointer => return std.fmt.bufPrint(buf, "\"{s}\"", .{st.s[i][0..st.sLen[i]]}) catch buf[0..0],
        else => switch (T) {
            raylib.Color => return std.fmt.bufPrint(buf, "raylib.Color.init({d},{d},{d},{d})", .{ st.c[i].r, st.c[i].g, st.c[i].b, st.c[i].a }) catch buf[0..0],
            raylib.Vector2 => return std.fmt.bufPrint(buf, "raylib.Vector2.init({d:.1},{d:.1})", .{ st.v2[i].x, st.v2[i].y }) catch buf[0..0],
            raylib.Vector3 => return std.fmt.bufPrint(buf, "raylib.Vector3.init({d:.1},{d:.1},{d:.1})", .{ st.v3[i].x, st.v3[i].y, st.v3[i].z }) catch buf[0..0],
            raylib.Rectangle => return std.fmt.bufPrint(buf, "raylib.Rectangle.init({d:.0},{d:.0},{d:.0},{d:.0})", .{ st.r[i].x, st.r[i].y, st.r[i].width, st.r[i].height }) catch buf[0..0],
            else => unreachable,
        },
    }
}

fn codeImpl(comptime F: anytype, comptime name: [:0]const u8, comptime K: usize) *const fn (buf: []u8) []const u8 {
    const W = struct {
        fn write(buf: []u8) []const u8 {
            const Fi = @typeInfo(@TypeOf(F)).@"fn";
            var pos: usize = 0;
            const pre = std.fmt.bufPrint(buf, "raylib.{s}(", .{name}) catch return buf[0..0];
            pos = pre.len;
            inline for (0..Fi.param_types.len) |i| {
                const T = Fi.param_types[i].?;
                if (i > 0) {
                    if (pos + 2 > buf.len) return buf[0..0];
                    buf[pos] = ',';
                    buf[pos + 1] = ' ';
                    pos += 2;
                }
                const seg = fmtArgInto(buf[pos..], T, &states[K], i);
                pos += seg.len;
            }
            if (pos + 2 > buf.len) return buf[0..0];
            buf[pos] = ')';
            buf[pos + 1] = ';';
            pos += 2;
            return buf[0..pos];
        }
    };
    return &W.write;
}

// ── 对外：根据目录条目生成（或跳过）一个自动 Demo ─────────────────────────

fn makeDemo(comptime F: anytype, comptime e: catalog.Entry, comptime K: usize) dt.Demo {
    return .{
        .name = e.name,
        .hint = e.doc,
        .update = null,
        .draw = drawImpl(F, K),
        .drawControls = controlsImpl(F, K),
        .reset = resetImpl(F, K),
        .writeCode = codeImpl(F, e.name, K),
    };
}

/// 返回目录条目对应的自动 Demo；不可自动演示的返回 null（走文档页）。
/// gi 是条目在 catalog.entries 里的下标，用来计算它在自动演示里的序号 K。
pub fn autoDemoFor(comptime e: catalog.Entry, comptime gi: usize) ?dt.Demo {
    const k = AUTO_MAP[gi] orelse return null;
    return makeDemo(@field(raylib, e.name), e, k);
}
