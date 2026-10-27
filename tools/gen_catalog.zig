// API 目录生成器：解析 raylib + raygui 官方头文件和 zig 绑定，生成 src/catalog.zig。
//
// 用法：
//   zig run tools/gen_catalog.zig -- <raylib.h> <raylib.zig> <输出>
//   zig run tools/gen_catalog.zig -- <raylib.h> <raylib.zig> <输出> [raygui.h] [raygui.zig]
// 或：
//   zig build catalog
const std = @import("std");

const Module = enum {
    core,
    shapes,
    textures,
    text,
    models,
    audio,
    gui,
    other,

    fn fromRaw(raw: []const u8) Module {
        if (std.mem.eql(u8, raw, "core")) return .core;
        if (std.mem.eql(u8, raw, "rgestures")) return .core;
        if (std.mem.eql(u8, raw, "rcamera")) return .core;
        if (std.mem.eql(u8, raw, "shapes")) return .shapes;
        if (std.mem.eql(u8, raw, "textures")) return .textures;
        if (std.mem.eql(u8, raw, "text")) return .text;
        if (std.mem.eql(u8, raw, "models")) return .models;
        if (std.mem.eql(u8, raw, "audio")) return .audio;
        return .other;
    }
};

const CApi = struct {
    c_name: []const u8,
    module: Module,
    section: []const u8,
    doc: []const u8,
    c_sig: []const u8, // C 原型（含参数类型），如 void DrawText(const char *text, ...)
};

const ZigApi = struct {
    name: []const u8,
    doc: []const u8,
    sig: []const u8, // zig 签名（含参数名与类型），如 drawText(text: [:0]const u8, ...) void
};

const Entry = struct {
    name: []const u8,
    c_name: []const u8,
    module: Module,
    section: []const u8,
    doc: []const u8,
    sig: []const u8,
    c_sig: []const u8,
};

fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r");
}

fn lowerFirst(name: []const u8, buf: []u8) []const u8 {
    if (name.len == 0) return name;
    @memcpy(buf[0..name.len], name);
    buf[0] = std.ascii.toLower(buf[0]);
    return buf[0..name.len];
}

/// 从 PascalCase C 名生成 zig 名：先去掉前缀（如 "Gui"），再 lowerFirst
fn zigNameFromC(c_name: []const u8, prefix: []const u8, buf: []u8) []const u8 {
    var rest = c_name;
    if (std.mem.startsWith(u8, c_name, prefix)) {
        rest = c_name[prefix.len..];
    }
    return lowerFirst(rest, buf);
}

/// 解析头文件：收集所有指定宏（RLAPI / RAYGUIAPI）的函数声明
/// - macro: 函数声明前的宏前缀
/// - fixedModule: 如果非 null，强制所有条目用此 module（raygui 固定 .gui）
/// - zigPrefix: C 函数名前缀需去掉才能匹配 zig 名（raygui 是 "Gui"，raylib 空串）
fn parseHeader(
    allocator: std.mem.Allocator,
    text: []const u8,
    macro: []const u8,
    fixedModule: ?Module,
) ![]CApi {
    var list: std.ArrayList(CApi) = .empty;

    var module: Module = fixedModule orelse .other;
    var section: []const u8 = "";

    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw_line| {
        const line = trim(raw_line);

        // raylib 模块标题：// ... Functions (Module: core)
        if (fixedModule == null) {
            if (std.mem.indexOf(u8, line, "(Module: ")) |start| {
                const begin = start + "(Module: ".len;
                if (std.mem.indexOfScalarPos(u8, line, begin, ')')) |end| {
                    module = Module.fromRaw(line[begin..end]);
                    // 子模块标题身兼分节名，例如：
                    //   // Gestures and Touch Handling Functions (Module: rgestures)
                    //   // Camera System Functions (Module: rcamera)
                    // 其后直接跟函数声明、没有独立分节注释，若不取前缀这些函数 section 为空。
                    // 大模块标题（如 core）后面紧跟分节注释行，会被覆盖，不受影响。
                    section = "";
                    if (std.mem.startsWith(u8, line, "//")) {
                        const head = trim(line[2..start]);
                        var lower_buf: [128]u8 = undefined;
                        if (head.len > 0 and head.len < lower_buf.len) {
                            const lower = std.ascii.lowerString(lower_buf[0..head.len], head);
                            if (std.mem.indexOf(u8, lower, "function") != null or
                                std.mem.indexOf(u8, lower, "control") != null)
                            {
                                section = try allocator.dupe(u8, head);
                            }
                        }
                    }
                }
                continue;
            }
        }

        // 函数声明（单行）
        if (std.mem.startsWith(u8, line, macro)) {
            const paren = std.mem.indexOfScalar(u8, line, '(') orelse continue;
            // '(' 之前形如 "RLAPI void InitWindow"，取最后一个标识符 = 函数名
            const before = trim(line[macro.len..paren]);
            var name_it = std.mem.tokenizeAny(u8, before, " \t*");
            var c_name: []const u8 = "";
            while (name_it.next()) |tok| c_name = tok;
            if (c_name.len == 0) continue;

            // 行尾注释即官方一句话说明
            var doc: []const u8 = "";
            var decl = line;
            if (std.mem.indexOf(u8, line, "//")) |comment| {
                doc = trim(line[comment + 2 ..]);
                decl = trim(line[0..comment]);
            }

            // C 原型：去掉宏前缀和尾部分号，保留完整的返回类型与参数列表
            var c_sig = trim(decl[macro.len..]);
            if (std.mem.endsWith(u8, c_sig, ";")) c_sig = trim(c_sig[0 .. c_sig.len - 1]);

            try list.append(allocator, .{
                .c_name = try allocator.dupe(u8, c_name),
                .module = module,
                .section = try allocator.dupe(u8, section),
                .doc = try allocator.dupe(u8, doc),
                .c_sig = try allocator.dupe(u8, c_sig),
            });
            continue;
        }

        // 分节标题：以 "//" 开头，整句含 "function" 或 "control"（忽略大小写）
        if (std.mem.startsWith(u8, line, "//") and
            !std.mem.startsWith(u8, line, "//---") and
            !std.mem.startsWith(u8, line, "// NOTE") and
            !std.mem.startsWith(u8, line, "// WARNING") and
            line.len < 78)
        {
            const body = trim(line[2..]);
            var lower_buf: [128]u8 = undefined;
            if (body.len > 0 and body.len < lower_buf.len) {
                const lower = std.ascii.lowerString(lower_buf[0..body.len], body);
                if (std.mem.indexOf(u8, lower, "function") != null or
                    std.mem.indexOf(u8, lower, "control") != null)
                {
                    section = try allocator.dupe(u8, body);
                }
            }
        }
    }
    return list.toOwnedSlice(allocator);
}

/// 解析 zig 绑定：收集所有顶层 pub fn（跳过 struct 内缩进方法）
fn parseBinding(allocator: std.mem.Allocator, text: []const u8) ![]ZigApi {
    var list: std.ArrayList(ZigApi) = .empty;
    var doc_lines: std.ArrayList([]const u8) = .empty;
    defer doc_lines.deinit(allocator);

    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw_line| {
        if (std.mem.startsWith(u8, raw_line, "///")) {
            try doc_lines.append(allocator, trim(raw_line[3..]));
            continue;
        }

        if (std.mem.startsWith(u8, raw_line, "pub fn ")) {
            const rest = raw_line["pub fn ".len..];
            const paren = std.mem.indexOfScalar(u8, rest, '(') orelse {
                doc_lines.clearRetainingCapacity();
                continue;
            };
            const name = rest[0..paren];

            // zig 签名：从函数名到行尾 '{' 为止（用 lastIndexOf 避免 error{...} 里的 '{'）
            var sig = trim(rest);
            if (std.mem.lastIndexOfScalar(u8, sig, '{')) |brace| sig = trim(sig[0..brace]);

            var buf: std.ArrayList(u8) = .empty;
            for (doc_lines.items, 0..) |d, i| {
                if (i > 0) try buf.append(allocator, ' ');
                try buf.appendSlice(allocator, d);
            }
            try list.append(allocator, .{
                .name = try allocator.dupe(u8, name),
                .doc = try buf.toOwnedSlice(allocator),
                .sig = try allocator.dupe(u8, sig),
            });
            doc_lines.clearRetainingCapacity();
            continue;
        }

        const line = trim(raw_line);
        if (line.len != 0 and !std.mem.startsWith(u8, line, "//")) {
            doc_lines.clearRetainingCapacity();
        }
    }
    return list.toOwnedSlice(allocator);
}

/// 把任意文本转义成可安全放进 "" 的 ASCII 字符串内容
fn writeEscaped(out: *std.ArrayList(u8), allocator: std.mem.Allocator, s: []const u8) !void {
    for (s) |ch| {
        switch (ch) {
            '"' => try out.appendSlice(allocator, "\\\""),
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '\n', '\r', '\t' => try out.append(allocator, ' '),
            else => {
                if (ch < 0x20) continue;
                if (ch >= 0x7f) continue;
                try out.append(allocator, ch);
            },
        }
    }
}

/// 大标题 "Basic Shapes Drawing Functions (Module: shapes)" 与紧随其后的分节
/// "Basic shapes drawing functions" 只差大小写，归并避免树里出现两个相邻同义组
fn normalizeSection(s: []const u8) []const u8 {
    if (std.mem.eql(u8, s, "Basic Shapes Drawing Functions")) return "Basic shapes drawing functions";
    return s;
}

/// 把一组 zig API 和 C API 对齐，生成 entries。
/// zigPrefix 是 C 函数名需去掉的前缀（raylib 为空 ""，raygui 为 "Gui"）
fn alignEntries(
    allocator: std.mem.Allocator,
    zig_apis: []const ZigApi,
    c_apis: []const CApi,
    zig_prefix: []const u8,
) !std.ArrayList(Entry) {
    var entries: std.ArrayList(Entry) = .empty;
    var name_buf: [128]u8 = undefined;

    for (zig_apis) |z| {
        var matched: ?CApi = null;
        for (c_apis) |c| {
            const expect = zigNameFromC(c.c_name, zig_prefix, &name_buf);
            if (std.mem.eql(u8, z.name, expect)) {
                matched = c;
                break;
            }
        }

        if (matched) |c| {
            try entries.append(allocator, .{
                .name = z.name,
                .c_name = c.c_name,
                .module = c.module,
                .section = normalizeSection(c.section),
                .doc = if (z.doc.len > 0) z.doc else c.doc,
                .sig = z.sig,
                .c_sig = c.c_sig,
            });
        } else {
            try entries.append(allocator, .{
                .name = z.name,
                .c_name = "",
                .module = .other,
                .section = "",
                .doc = z.doc,
                .sig = z.sig,
                .c_sig = "",
            });
        }
    }
    return entries;
}

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try init.minimal.args.toSlice(allocator);
    if (args.len < 4) {
        std.debug.print("usage: gen_catalog <raylib.h> <raylib.zig> <output> [raygui.h] [raygui.zig]\n", .{});
        std.process.exit(1);
    }

    const dir = std.Io.Dir.cwd();

    // ── raylib ──────────────────────────────────────────
    const header_text = try dir.readFileAlloc(init.io, args[1], allocator, .unlimited);
    const binding_text = try dir.readFileAlloc(init.io, args[2], allocator, .unlimited);
    const rl_c = try parseHeader(allocator, header_text, "RLAPI", null);
    const rl_z = try parseBinding(allocator, binding_text);
    var rl_entries = try alignEntries(allocator, rl_z, rl_c, "");

    // ── raygui（可选）────────────────────────────────────
    if (args.len >= 6) {
        const gui_header_text = try dir.readFileAlloc(init.io, args[4], allocator, .unlimited);
        const gui_binding_text = try dir.readFileAlloc(init.io, args[5], allocator, .unlimited);
        const gui_c = try parseHeader(allocator, gui_header_text, "RAYGUIAPI", .gui);
        const gui_z = try parseBinding(allocator, gui_binding_text);
        const gui_entries = try alignEntries(allocator, gui_z, gui_c, "Gui");

        // 合并 raylib + raygui
        const total = rl_entries.items.len + gui_entries.items.len;
        var all: std.ArrayList(Entry) = .empty;
        try all.ensureTotalCapacity(allocator, total);
        for (rl_entries.items) |e| try all.append(allocator, e);
        for (gui_entries.items) |e| try all.append(allocator, e);
        rl_entries = all;
    }

    // ── 输出 ─────────────────────────────────────────────
    var out: std.ArrayList(u8) = .empty;

    try out.appendSlice(allocator,
        \\// 本文件由 tools/gen_catalog.zig 自动生成，请勿手工编辑。
        \\// 数据来源：raylib + raygui 官方头文件和 zig 绑定。
        \\// 重新生成：zig build catalog
        \\
        \\pub const Module = enum(u8) {
        \\    core,
        \\    shapes,
        \\    textures,
        \\    text,
        \\    models,
        \\    audio,
        \\    gui,
        \\    other,
        \\};
        \\
        \\pub const Entry = struct {
        \\    name: [:0]const u8,
        \\    c_name: [:0]const u8,
        \\    module: Module,
        \\    section: [:0]const u8,
        \\    doc: [:0]const u8,
        \\    sig: [:0]const u8,
        \\    c_sig: [:0]const u8,
        \\};
        \\
        \\pub const entries = [_]Entry{
        \\
    );

    for (rl_entries.items) |e| {
        try out.appendSlice(allocator, "    .{ .name = \"");
        try writeEscaped(&out, allocator, e.name);
        try out.appendSlice(allocator, "\", .c_name = \"");
        try writeEscaped(&out, allocator, e.c_name);
        try out.appendSlice(allocator, "\", .module = .");
        try out.appendSlice(allocator, @tagName(e.module));
        try out.appendSlice(allocator, ", .section = \"");
        try writeEscaped(&out, allocator, e.section);
        try out.appendSlice(allocator, "\", .doc = \"");
        try writeEscaped(&out, allocator, e.doc);
        try out.appendSlice(allocator, "\", .sig = \"");
        try writeEscaped(&out, allocator, e.sig);
        try out.appendSlice(allocator, "\", .c_sig = \"");
        try writeEscaped(&out, allocator, e.c_sig);
        try out.appendSlice(allocator, "\" },\n");
    }
    try out.appendSlice(allocator, "};\n");

    try dir.writeFile(init.io, .{ .sub_path = args[3], .data = out.items });

    std.debug.print("catalog: {d} entries (raylib + raygui) -> {s}\n", .{
        rl_entries.items.len,
        args[3],
    });
}
