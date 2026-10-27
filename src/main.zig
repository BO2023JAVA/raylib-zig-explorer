// raylib 可视化实验室 —— 框架文件（布局 + 主循环）。
// 这个文件只负责筛选 / 展示全量 API 目录（src/catalog.zig，自动生成），
// 有交互 demo 的 API 走实验视图，其余显示文档页，具体教学内容在 demos/ 里。
//
// 布局（像 VB / 属性编辑器）：
//   左侧 220px : 搜索框 + 模块过滤 + API 列表（带 * 的是已做成交互 demo 的）
//   中间       : 实时画布 / 文档页
//   右侧 300px : 参数面板（交互 demo）或 API 参考信息（文档页）
//   底部 32px  : 当前参数生成的 Zig 代码 / 提示
const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");
const pg = @import("playground.zig");
const catalog = pg.catalog;
const dt = @import("demo_types.zig");

const screenWidth: i32 = 1600;
const screenHeight: i32 = 900;

const listWidth = 240;
const panelWidth = 300;
const statusHeight = 32;
const fontSize: f32 = 24;

// ── 深色主题配色（VS Code 风格）────────────────────────────
const Theme = struct {
    const canvas = raylib.Color.init(30, 30, 30, 255); // 画布/窗口背景 #1E1E1E
    const panel = raylib.Color.init(37, 37, 38, 255); // 面板背景 #252526
    const border = raylib.Color.init(60, 60, 60, 255); // 边框 #3C3C3C
    const control = raylib.Color.init(51, 51, 51, 255); // 控件底色
    const text = raylib.Color.init(212, 212, 212, 255); // 主文字 #D4D4D4
    const text_dim = raylib.Color.init(156, 156, 156, 255); // 次要文字
    const text_disabled = raylib.Color.init(110, 110, 110, 255);
    const accent = raylib.Color.init(40, 115, 180, 255); // 选中/焦点
    const accent_bright = raylib.Color.init(70, 150, 210, 255);
};

/// 给单个 raygui 控件套深色（控件都接受 ControlProperty 的颜色属性）
fn styleControl(comptime ctrl: raygui.Control) void {
    raygui.setStyle(ctrl, .text_color_normal, raylib.colorToInt(Theme.text));
    raygui.setStyle(ctrl, .text_color_focused, raylib.colorToInt(Theme.text));
    raygui.setStyle(ctrl, .text_color_pressed, raylib.colorToInt(Theme.text));
    raygui.setStyle(ctrl, .text_color_disabled, raylib.colorToInt(Theme.text_disabled));
    raygui.setStyle(ctrl, .base_color_normal, raylib.colorToInt(Theme.control));
    raygui.setStyle(ctrl, .base_color_focused, raylib.colorToInt(Theme.accent));
    raygui.setStyle(ctrl, .base_color_pressed, raylib.colorToInt(Theme.accent_bright));
    raygui.setStyle(ctrl, .base_color_disabled, raylib.colorToInt(Theme.panel));
    raygui.setStyle(ctrl, .border_color_normal, raylib.colorToInt(Theme.border));
    raygui.setStyle(ctrl, .border_color_focused, raylib.colorToInt(Theme.accent));
    raygui.setStyle(ctrl, .border_color_pressed, raylib.colorToInt(Theme.accent_bright));
    raygui.setStyle(ctrl, .border_color_disabled, raylib.colorToInt(Theme.border));
}

/// 给所有 raygui 控件统一套深色（每个控件都接受 ControlProperty 的颜色属性）
fn applyDarkTheme() void {
    raygui.setStyle(.default, .background_color, raylib.colorToInt(Theme.panel));
    raygui.setStyle(.default, .line_color, raylib.colorToInt(Theme.border));
    styleControl(.label);
    styleControl(.button);
    styleControl(.toggle);
    styleControl(.slider);
    styleControl(.progressbar);
    styleControl(.checkbox);
    styleControl(.combobox);
    styleControl(.dropdownbox);
    styleControl(.textbox);
    styleControl(.valuebox);
    styleControl(.tabbar);
    styleControl(.listview);
    styleControl(.colorpicker);
    styleControl(.scrollbar);
    styleControl(.statusbar);
}

/// 收藏夹持久化：favorites.txt，每行一个 API 名
fn saveFavs(io: std.Io, favs: *const [catalog.entries.len]bool) void {
    var buf: [64 * 1024]u8 = undefined;
    var len: usize = 0;
    for (catalog.entries, 0..) |e, gi| {
        if (favs[gi]) {
            if (len + e.name.len + 1 > buf.len) break;
            @memcpy(buf[len .. len + e.name.len], e.name);
            len += e.name.len;
            buf[len] = '\n';
            len += 1;
        }
    }
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = "favorites.txt", .data = buf[0..len] }) catch {};
}

fn loadFavs(io: std.Io, favs: *[catalog.entries.len]bool) void {
    var buf: [64 * 1024]u8 = undefined;
    const data = std.Io.Dir.cwd().readFile(io, "favorites.txt", &buf) catch return;
    var it = std.mem.tokenizeScalar(u8, data, '\n');
    while (it.next()) |line| {
        const name = std.mem.trim(u8, line, " \r\t");
        for (catalog.entries, 0..) |e, gi| {
            if (std.mem.eql(u8, e.name, name)) favs[gi] = true;
        }
    }
}

/// 把当前 demo 导出为可独立编译运行的 zig 文件（拷贝到有 raylib 依赖的工程里即可跑）
fn exportDemo(io: std.Io, name: [:0]const u8, code: []const u8) void {
    var pathBuf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(pathBuf[0..], "export_{s}.zig", .{name}) catch return;
    var contentBuf: [2048]u8 = undefined;
    const content = std.fmt.bufPrint(contentBuf[0..],
        \\const raylib = @import("raylib");
        \\
        \\pub fn main() !void {{
        \\    raylib.initWindow(800, 600, "{s} - exported demo");
        \\    defer raylib.closeWindow();
        \\    raylib.setTargetFPS(120);
        \\    while (!raylib.windowShouldClose()) {{
        \\        raylib.beginDrawing();
        \\        defer raylib.endDrawing();
        \\        raylib.clearBackground(raylib.Color.black);
        \\        {s}
        \\    }}
        \\}}
        \\
    , .{ name, code }) catch return;
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = content }) catch {};
}

/// 把 Unicode 码点编码为 UTF-8，返回字节数
fn encodeUtf8(cp: i32, out: *[4]u8) usize {
    const c: u21 = @intCast(@min(@max(cp, 0), 0x10FFFF));
    if (c < 0x80) {
        out[0] = @intCast(c);
        return 1;
    } else if (c < 0x800) {
        out[0] = 0xC0 | @as(u8, @intCast(c >> 6));
        out[1] = 0x80 | @as(u8, @intCast(c & 0x3F));
        return 2;
    } else if (c < 0x10000) {
        out[0] = 0xE0 | @as(u8, @intCast(c >> 12));
        out[1] = 0x80 | @as(u8, @intCast((c >> 6) & 0x3F));
        out[2] = 0x80 | @as(u8, @intCast(c & 0x3F));
        return 3;
    } else {
        out[0] = 0xF0 | @as(u8, @intCast(c >> 18));
        out[1] = 0x80 | @as(u8, @intCast((c >> 12) & 0x3F));
        out[2] = 0x80 | @as(u8, @intCast((c >> 6) & 0x3F));
        out[3] = 0x80 | @as(u8, @intCast(c & 0x3F));
        return 4;
    }
}

/// 搜索框自绘自管输入。不用 raygui textBox：它每帧只调用一次 GetCharPressed，
/// 而 raylib 每帧开头清空字符队列，中文输入法词组一次上屏多个字时只剩第一个字。
/// 返回是否处于编辑态（点击框外/回车/Esc 退出）。
fn searchInput(buf: *[64:0]u8, bounds: raylib.Rectangle, font: raylib.Font, editing: bool) bool {
    var edit = editing;
    if (raylib.isMouseButtonPressed(.left)) {
        edit = raylib.checkCollisionPointRec(raylib.getMousePosition(), bounds);
    }
    if (edit) {
        // 读完本帧全部输入字符（IME 词组上屏一次多个）
        while (true) {
            const cp = raylib.getCharPressed();
            if (cp <= 0) break;
            if (cp >= 32) {
                var enc: [4]u8 = undefined;
                const n = encodeUtf8(cp, &enc);
                const cur = std.mem.sliceTo(buf[0..], 0).len;
                if (cur + n < 63) {
                    @memcpy(buf[cur .. cur + n], enc[0..n]);
                    buf[cur + n] = 0;
                }
            }
        }
        // 退格：从尾部删一个完整 UTF-8 码点
        if (raylib.isKeyPressed(.backspace) or raylib.isKeyPressedRepeat(.backspace)) {
            var cur = std.mem.sliceTo(buf[0..], 0).len;
            while (cur > 0) {
                cur -= 1;
                if ((buf[cur] & 0xC0) != 0x80) break; // 跳过 UTF-8 continuation byte
            }
            buf[cur] = 0;
        }
        if (raylib.isKeyPressed(.enter) or raylib.isKeyPressed(.escape)) edit = false;
    }
    raylib.drawRectangleRec(bounds, Theme.control);
    raylib.drawRectangleLinesEx(bounds, 1, if (edit) Theme.accent else Theme.border);
    const len = std.mem.sliceTo(buf[0..], 0).len;
    raylib.drawTextEx(font, buf[0..len:0], .{ .x = bounds.x + 6, .y = bounds.y + 2 }, 22, 1, Theme.text);
    // 光标闪烁
    if (edit and @mod(raylib.getTime() * 2, 2) < 1) {
        const tw = raylib.measureTextEx(font, buf[0..len:0], 22, 1).x;
        raylib.drawRectangle(@intFromFloat(bounds.x + 7 + tw), @intFromFloat(bounds.y + 4), 2, 20, Theme.text);
    }
    return edit;
}

/// 大小写不敏感的子串匹配（API 名都是 ASCII）
fn containsCI(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var match = true;
        for (needle, 0..) |nc, j| {
            if (std.ascii.toLower(haystack[i + j]) != std.ascii.toLower(nc)) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

/// 树形列表行：section 分节标题行（entry = 组首 catalog 索引，兼作展开状态键）
/// 或 func 函数行（entry = 该函数的 catalog 索引）
const Row = struct {
    is_section: bool,
    entry: usize,
};

/// 启动主页：项目名与关键词 + 特性简介；点击或按键进入 API 浏览器
fn drawHome(font: raylib.Font, titleFont: raylib.Font) void {
    const cx: f32 = @as(f32, @floatFromInt(raylib.getScreenWidth())) / 2;

    // 大标题：raylib × Zig（品牌关键词）
    const title = "raylib × Zig";
    const tSize: f32 = 48;
    const tw = raylib.measureTextEx(titleFont, title, tSize, 1).x;
    raylib.drawTextEx(titleFont, title, .{ .x = cx - tw / 2, .y = 130 }, tSize, 1, raylib.Color.sky_blue);

    const title2 = "可视化 API 实验室";
    const t2Size: f32 = 42;
    const t2w = raylib.measureTextEx(titleFont, title2, t2Size, 1).x;
    raylib.drawTextEx(titleFont, title2, .{ .x = cx - t2w / 2, .y = 200 }, t2Size, 1, raylib.Color.light_gray);

    const tagline = "基于 raylib 6.0 与 Zig 0.17 的交互式学习与演示工具";
    const gw = raylib.measureTextEx(font, tagline, fontSize, 1).x;
    raylib.drawTextEx(font, tagline, .{ .x = cx - gw / 2, .y = 282 }, fontSize, 1, Theme.text_dim);

    raylib.drawLineEx(.{ .x = cx - 260, .y = 332 }, .{ .x = cx + 260, .y = 332 }, 1, Theme.border);

    // 三条特性
    const feats = [_][:0]const u8{
        "· 679 个 API 全收录（raylib 618 + raygui 61）",
        "· 带 * 号的 API 有交互演示，右侧参数面板实时调节",
        "· 每个 API 附中文说明与完整 Zig 调用签名",
    };
    var fy: f32 = 366;
    for (feats) |f| {
        const fw = raylib.measureTextEx(font, f, fontSize, 1).x;
        raylib.drawTextEx(font, f, .{ .x = cx - fw / 2, .y = fy }, fontSize, 1, Theme.text);
        fy += 40;
    }

    // 底部闪烁提示
    const hint = "点击鼠标或按回车进入";
    const hw = raylib.measureTextEx(font, hint, fontSize, 1).x;
    const a: u8 = @intFromFloat((@sin(raylib.getTime() * 3) * 0.5 + 0.5) * 200 + 55);
    raylib.drawTextEx(font, hint, .{ .x = cx - hw / 2, .y = 590 }, fontSize, 1, raylib.Color.init(Theme.text_dim.r, Theme.text_dim.g, Theme.text_dim.b, a));
}

pub fn main(init: std.process.Init) !void {
    // 自动遍历测试模式：--audit 时每 3 帧切下一个 API，stderr 记录进度
    // 卡住/闪退时日志最后一行即问题 API
    var auditMode = false;
    var auditIdx: usize = 0;
    var auditFrames: u32 = 0;
    {
        const args = try init.minimal.args.toSlice(std.heap.page_allocator);
        for (args) |a| {
            if (std.mem.eql(u8, a, "--audit")) auditMode = true;
        }
    }

    raylib.initWindow(screenWidth, screenHeight, "raylib playground");
    // 允许拉伸窗口（布局每帧按当前尺寸重算），限制最小尺寸避免控件挤没
    raylib.setWindowState(.{ .window_resizable = true });
    raylib.setWindowMinSize(900, 560);
    defer raylib.closeWindow();
    raylib.setWindowPosition(100, 60);
    raylib.setTargetFPS(120);

    // 加载字体：优先用 SimHei（黑体）覆盖中英文，回退 Consolas（等宽），
    // 再回退项目里的 PixelOperator，最后退回 raylib 内置默认字体。
    // 同时传入 zh.zig 中出现的所有字符码点，确保 CJK 字形被加载。
    // 用线性过滤平滑文字，像 VS Code 一样清晰。
    const glyphList = pg.zh.glyphs[0..];
    var uiFont = raylib.getFontDefault() catch unreachable;
    var customFont = false;
    if (raylib.loadFontEx("C:/Windows/Fonts/simhei.ttf", @intFromFloat(fontSize), glyphList)) |f| {
        uiFont = f;
        customFont = true;
    } else |_| {
        if (raylib.loadFontEx("C:/Windows/Fonts/consola.ttf", @intFromFloat(fontSize), glyphList)) |f| {
            uiFont = f;
            customFont = true;
        } else |_| {
            if (raylib.loadFontEx("resources/fonts/PixelOperator.ttf", @intFromFloat(fontSize), glyphList)) |f| {
                uiFont = f;
                customFont = true;
            } else |_| {}
        }
    }
    raylib.setTextureFilter(uiFont.texture, .bilinear);
    defer if (customFont) raylib.unloadFont(uiFont);

    // 主页大标题单独光栅化一份 48px 字体，避免 22px 直接放大两倍发虚
    var titleFont = uiFont;
    var ownTitleFont = false;
    if (customFont) {
        if (raylib.loadFontEx("C:/Windows/Fonts/simhei.ttf", 48, glyphList)) |f| {
            titleFont = f;
            ownTitleFont = true;
        } else |_| {}
    }
    raylib.setTextureFilter(titleFont.texture, .bilinear);
    defer if (ownTitleFont) raylib.unloadFont(titleFont);

    // 启动时先显示主页（audit 模式跳过）
    var showHome = !auditMode;
    raygui.setFont(uiFont);
    pg.uiFont = uiFont;
    dt.uiFont = uiFont;
    applyDarkTheme();

    // raygui 文本尺寸 = 字体原生尺寸，保证 1:1 渲染不缩放
    raygui.setStyle(.default, .text_size, @intFromFloat(fontSize));
    raygui.setStyle(.listview, .list_items_height, 28);

    // ── 左侧过滤器状态 ────────────────────────────────────────────────
    var searchBuf = std.mem.zeroes([64:0]u8);
    var searchEdit = false;
    var moduleEdit = false;
    var moduleSel: i32 = 0; // 0=全部，1=收藏，之后按 核心/图形/... 顺序
    var globalSel: usize = 0; // catalog.entries 的全局下标
    var codeBuf: [320:0]u8 = undefined;
    // "复制代码"按钮的已复制反馈截止时间（getTime 秒）
    var copyFlashUntil: f64 = 0;
    // "导出为 .zig"按钮的已导出反馈截止时间
    var exportFlashUntil: f64 = 0;

    // 树形列表：行缓冲 + 分节展开状态（键 = 组首 entry 索引）+ 滚动
    var rows: [760]Row = undefined;
    var expanded: [catalog.entries.len]bool = @splat(true);
    var treeScroll: f32 = 0;
    var panelScroll: f32 = 0; // 右侧参数面板滚动偏移
    // 收藏夹：启动时从 favorites.txt 恢复
    var favs: [catalog.entries.len]bool = @splat(false);
    loadFavs(init.io, &favs);

    const moduleNames = [_]catalog.Module{ .core, .shapes, .textures, .text, .models, .audio, .gui };

    // 下拉框区域（闭合态）与展开区域：展开高度与 raygui 内部 boundsOpen 算法一致，
    // height = (itemCount + 1) * (h + DROPDOWN_ITEMS_SPACING)，默认 spacing = 2
    const ddBounds = raylib.Rectangle.init(12, 62, listWidth - 24, 28);
    const ddOpenBounds = raylib.Rectangle.init(12, 62, listWidth - 24, 10 * 30);

    while (!raylib.windowShouldClose()) {
        // 启动主页：点击鼠标或按回车/空格进入 API 浏览器
        if (showHome) {
            if (raylib.isMouseButtonPressed(.left) or
                raylib.isKeyPressed(.enter) or
                raylib.isKeyPressed(.space)) showHome = false;
            raylib.beginDrawing();
            raylib.clearBackground(Theme.canvas);
            drawHome(uiFont, titleFont);
            raylib.endDrawing();
            continue;
        }

        // ── 0. 手动管理下拉开合 ───────────────────────────────────────
        // raygui 返回值语义（1=按下 / 2=变更）在自动化注入的跨帧点击下会误翻转，
        // 改为自己做命中测试：闭合时点盒子展开；展开时点盒子或点展开区域外收起；
        // 点列表项交给 raygui 选中（见帧末，选中后收起）。
        if (raylib.isMouseButtonPressed(.left)) {
            const mp = raylib.getMousePosition();
            if (moduleEdit) {
                if (raylib.checkCollisionPointRec(mp, ddBounds) or
                    !raylib.checkCollisionPointRec(mp, ddOpenBounds)) moduleEdit = false;
            } else if (raylib.checkCollisionPointRec(mp, ddBounds)) {
                moduleEdit = true;
            }
        }
        // 展开时锁住其他控件，避免点击菜单穿透到下面的 API 列表
        if (moduleEdit) raygui.lock() else raygui.unlock();

        // ── 1. 构建树形行列表（模块过滤 + 分节折叠 + 搜索）────────────
        const query = std.mem.sliceTo(searchBuf[0..], 0);
        const searching = query.len > 0;
        var rowCount: usize = 0;
        if (searching) {
            // 搜索模式：扁平函数行，匹配 英文名 / C 名 / 中文描述
            for (catalog.entries, 0..) |e, gi| {
                if (moduleSel == 1) {
                    if (!favs[gi]) continue; // 收藏夹：只看收藏
                } else if (moduleSel > 1 and e.module != moduleNames[@intCast(moduleSel - 2)]) continue;
                const cn = pg.zh.desc(e.c_name);
                if (!containsCI(e.name, query) and !containsCI(e.c_name, query) and !containsCI(cn, query)) continue;
                rows[rowCount] = .{ .is_section = false, .entry = gi };
                rowCount += 1;
            }
        } else {
            // 树形模式：两段式分组（zig 绑定函数顺序有模块交叉，不能依赖相邻合并）
            // 第一遍：按出现顺序收集去重的 (module, section) 组首
            var groupHeads: [64]usize = undefined;
            var groupCount: usize = 0;
            for (catalog.entries, 0..) |e, gi| {
                if (moduleSel == 1) {
                    if (!favs[gi]) continue;
                } else if (moduleSel > 1 and e.module != moduleNames[@intCast(moduleSel - 2)]) continue;
                var found = false;
                for (groupHeads[0..groupCount]) |h| {
                    const he = catalog.entries[h];
                    if (he.module == e.module and std.mem.eql(u8, he.section, e.section)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    groupHeads[groupCount] = gi;
                    groupCount += 1;
                }
            }
            // 第二遍：按组输出（折叠的组跳过函数行）
            for (groupHeads[0..groupCount]) |h| {
                rows[rowCount] = .{ .is_section = true, .entry = h };
                rowCount += 1;
                if (!expanded[h]) continue;
                const he = catalog.entries[h];
                for (catalog.entries, 0..) |e, gi| {
                    if (moduleSel == 1) {
                        if (!favs[gi]) continue;
                    } else if (moduleSel > 1 and e.module != moduleNames[@intCast(moduleSel - 2)]) continue;
                    if (e.module == he.module and std.mem.eql(u8, e.section, he.section)) {
                        rows[rowCount] = .{ .is_section = false, .entry = gi };
                        rowCount += 1;
                    }
                }
            }
        }

        // 若当前选中项不在可见函数行中，回退到第一个可见函数
        var selVisible = false;
        var firstFunc: ?usize = null;
        for (rows[0..rowCount]) |r| {
            if (!r.is_section) {
                if (firstFunc == null) firstFunc = r.entry;
                if (r.entry == globalSel) selVisible = true;
            }
        }
        if (!selVisible) {
            if (firstFunc) |fi| globalSel = fi;
        }
        if (globalSel >= catalog.entries.len) globalSel = 0;

        // audit 模式：强制逐个切换选中项
        if (auditMode) {
            if (auditFrames == 0) {
                std.debug.print("[{d}/{d}] {s}\n", .{ auditIdx + 1, catalog.entries.len, catalog.entries[auditIdx].name });
            }
            globalSel = auditIdx;
            auditFrames += 1;
            if (auditFrames >= 3) {
                auditFrames = 0;
                auditIdx += 1;
                if (auditIdx >= catalog.entries.len) {
                    std.debug.print("AUDIT COMPLETE - all {d} entries rendered OK\n", .{catalog.entries.len});
                    break;
                }
            }
        }

        const entry = catalog.entries[globalSel];
        const demo = pg.findDemo(entry.name);

        // ── 3. 计算各区域（窗口可拉伸，每帧按当前尺寸布局）─────────────
        const sw = raylib.getScreenWidth();
        const sh = raylib.getScreenHeight();
        // 无交互 demo 时不画右侧面板，画布/文档页占满剩余宽度
        const listRect = raylib.Rectangle.init(0, 0, listWidth, @floatFromInt(sh - statusHeight));
        const rightW: i32 = if (demo == null) 0 else panelWidth;
        const canvasPanel = raylib.Rectangle.init(
            listWidth,
            0,
            @as(f32, @floatFromInt(sw - listWidth - rightW)),
            @as(f32, @floatFromInt(sh - statusHeight)),
        );
        // 标题占掉顶部 58px，剩下的才是作图区域
        const content = raylib.Rectangle.init(canvasPanel.x + 12, 58, canvasPanel.width - 24, canvasPanel.height - 70);
        const controlsPanel = raylib.Rectangle.init(
            @floatFromInt(sw - panelWidth),
            0,
            panelWidth,
            @floatFromInt(sh - statusHeight),
        );
        const statusRect = raylib.Rectangle.init(0, @floatFromInt(sh - statusHeight), @floatFromInt(sw), statusHeight);

        // 交互 demo 的动画/输入更新
        if (demo) |d| {
            if (d.update) |update| update();
        }

        // ── 4. 绘制 ───────────────────────────────────────────────────
        raylib.beginDrawing();
        raylib.clearBackground(Theme.canvas);

        // 左侧：搜索框 + 模块下拉 + 中文分类树
        _ = raygui.panel(listRect, null);
        _ = raygui.label(raylib.Rectangle.init(12, 6, listWidth - 24, 22), "搜索 API（中文/英文）");
        searchEdit = searchInput(&searchBuf, raylib.Rectangle.init(12, 30, listWidth - 24, 28), uiFont, searchEdit);

        // ── 树形列表（自绘：滚轮滚动 + 分节折叠 + 点击选中）───────────
        const treeRect = raylib.Rectangle.init(6, 98, listWidth - 12, @floatFromInt(sh - statusHeight - 108));
        const mp = raylib.getMousePosition();
        // 滚轮滚动（下拉展开时不滚，避免穿透）
        if (raylib.checkCollisionPointRec(mp, treeRect) and !moduleEdit) {
            treeScroll -= raylib.getMouseWheelMove() * 40;
        }
        var totalH: f32 = 0;
        for (rows[0..rowCount]) |r| totalH += if (r.is_section) 32 else 30;
        treeScroll = std.math.clamp(treeScroll, 0, @max(0, totalH - treeRect.height));

        // 键盘 ↑↓ 在函数行间移动选中并滚动跟随（搜索框编辑时不抢按键）
        if (!searchEdit and !moduleEdit and rowCount > 0) {
            const dir: i32 = if (raylib.isKeyPressed(.down) or raylib.isKeyPressedRepeat(.down)) 1 else if (raylib.isKeyPressed(.up) or raylib.isKeyPressedRepeat(.up)) -1 else 0;
            if (dir != 0) {
                var cur: ?usize = null;
                for (rows[0..rowCount], 0..) |r, i| {
                    if (!r.is_section and r.entry == globalSel) {
                        cur = i;
                        break;
                    }
                }
                const last: i32 = @intCast(rowCount);
                var i: i32 = @intCast(cur orelse 0);
                while (true) {
                    i += dir;
                    if (i < 0 or i >= last) break;
                    const r = rows[@intCast(i)];
                    if (!r.is_section) {
                        globalSel = r.entry;
                        break;
                    }
                }
                // 滚动跟随：保证选中行可见
                var ly: f32 = 0;
                for (rows[0..rowCount]) |r| {
                    const rh2: f32 = if (r.is_section) 32 else 30;
                    if (!r.is_section and r.entry == globalSel) {
                        const top = treeRect.y + ly - treeScroll;
                        if (top < treeRect.y) treeScroll -= treeRect.y - top;
                        const bottom = top + rh2;
                        if (bottom > treeRect.y + treeRect.height) treeScroll += bottom - treeRect.y - treeRect.height;
                        break;
                    }
                    ly += rh2;
                }
            }
        }

        const clicked = raylib.isMouseButtonPressed(.left) and !moduleEdit;
        const scX: i32 = @intFromFloat(treeRect.x);
        const scY: i32 = @intFromFloat(treeRect.y);
        raylib.beginScissorMode(scX, scY, @intFromFloat(treeRect.width), @intFromFloat(treeRect.height));
        var ry = treeRect.y - treeScroll;
        for (rows[0..rowCount]) |r| {
            const rh: f32 = if (r.is_section) 32 else 30;
            const rowRect = raylib.Rectangle.init(treeRect.x, ry, treeRect.width, rh);
            const onScreen = ry + rh > treeRect.y and ry < treeRect.y + treeRect.height;
            // 屏外行直接跳过：全展开约 736 行，每行两次绘制调用会拖垮帧率
            if (!onScreen) {
                ry += rh;
                continue;
            }
            const hovered = raylib.checkCollisionPointRec(mp, rowRect);
            const e = catalog.entries[r.entry];
            if (r.is_section) {
                raylib.drawRectangleRec(rowRect, Theme.control);
                const zhName = pg.zh.sectionZh(e.section);
                var sbuf: [96:0]u8 = undefined;
                const st = std.fmt.bufPrint(sbuf[0..96], "{s} {s}", .{
                    if (expanded[r.entry]) "v" else ">",
                    if (zhName.len > 0) zhName else e.section,
                }) catch unreachable;
                sbuf[st.len] = 0;
                raylib.drawTextEx(uiFont, sbuf[0..st.len:0], .{ .x = rowRect.x + 6, .y = ry + 4 }, fontSize, 1, raylib.Color.orange);
                if (hovered and clicked) expanded[r.entry] = !expanded[r.entry];
            } else {
                if (r.entry == globalSel) {
                    raylib.drawRectangleRec(rowRect, Theme.accent);
                } else if (hovered) {
                    raylib.drawRectangleRec(rowRect, Theme.control);
                }
                var fbuf: [64:0]u8 = undefined;
                const ft = std.fmt.bufPrint(fbuf[0..64], "{s}{s}", .{
                    if (pg.findDemo(e.name) != null) "* " else "",
                    e.name,
                }) catch unreachable;
                fbuf[ft.len] = 0;
                raylib.drawTextEx(uiFont, fbuf[0..ft.len:0], .{ .x = rowRect.x + 18, .y = ry + 3 }, fontSize, 1, Theme.text);
                // 行尾收藏星标：hover 显示，已收藏常显；点击切换并落盘
                const isFav = favs[r.entry];
                const starX = rowRect.x + rowRect.width - 26;
                if (isFav or hovered) {
                    raylib.drawTextEx(uiFont, if (isFav) "★" else "☆", .{ .x = starX, .y = ry + 3 }, 20, 1, if (isFav) raylib.Color.gold else raylib.Color.gray);
                }
                if (hovered and clicked) {
                    if (mp.x >= starX - 4) {
                        favs[r.entry] = !favs[r.entry];
                        saveFavs(init.io, &favs);
                    } else {
                        globalSel = r.entry;
                    }
                }
            }
            ry += rh;
        }
        raylib.endScissorMode();

        // 中间：交互 demo 画布，或 API 文档页
        _ = raygui.panel(canvasPanel, null);
        if (demo) |d| {
            raylib.drawTextEx(
                uiFont,
                d.name,
                .{ .x = content.x, .y = 6 },
                fontSize,
                1,
                raylib.Color.light_gray,
            );
            // hint 优先中文翻译，超长按画布宽度截断
            {
                const cn = pg.zh.desc(catalog.entries[globalSel].c_name);
                const src: []const u8 = if (cn.len > 0) cn else d.hint;
                var hbuf: [256:0]u8 = undefined;
                var hlen: usize = @min(src.len, 255);
                @memcpy(hbuf[0..hlen], src[0..hlen]);
                hbuf[hlen] = 0;
                const hintSize: f32 = fontSize - 4;
                while (hlen > 0 and raylib.measureTextEx(uiFont, hbuf[0..hlen:0], hintSize, 1).x > content.width - 8) {
                    hlen -= 1;
                    while (hlen > 0 and (hbuf[hlen] & 0xC0) == 0x80) hlen -= 1; // 退完整 UTF-8 码点
                    hbuf[hlen] = 0;
                }
                raylib.drawTextEx(uiFont, hbuf[0..hlen:0], .{ .x = content.x, .y = 36 }, hintSize, 1, raylib.Color.gray);
            }
            d.draw(content);
        } else {
            pg.drawDocPage(uiFont, content, entry);
        }

        // demo 调用代码提前生成一次：右侧面板"复制代码"按钮和底部状态栏共用
        var codeLen: usize = 0;
        if (demo) |d| {
            const code = d.writeCode(codeBuf[0..320]);
            codeLen = code.len;
            codeBuf[codeLen] = 0;
        }

        // 右侧：仅交互 demo 有参数面板；文档页时画布已占满，不画面板
        if (demo) |d| {
            _ = raygui.panel(controlsPanel, null);
            // 参数多于一屏时滚轮滚动（鼠标在面板区域内才生效）
            if (raylib.checkCollisionPointRec(mp, controlsPanel)) {
                panelScroll -= raylib.getMouseWheelMove() * 40;
            }
            var panel = pg.Panel.init(controlsPanel);
            panel.scroll = panelScroll;
            // 裁剪在面板范围内，防止控件画到状态栏/画布上
            raylib.beginScissorMode(
                @intFromFloat(controlsPanel.x),
                @intFromFloat(controlsPanel.y),
                @intFromFloat(controlsPanel.width),
                @intFromFloat(controlsPanel.height),
            );
            panel.title("参数");
            d.drawControls(.{
                .panel = &panel,
                .canvasWidth = content.width,
                .canvasHeight = content.height,
            });
            panel.gap(8);
            if (panel.button("重置参数")) d.reset();
            // 一键复制当前调用代码到剪贴板，方便直接粘进自己的工程
            const copyLabel: [:0]const u8 = if (raylib.getTime() < copyFlashUntil) "已复制" else "复制代码";
            if (panel.button(copyLabel)) {
                copyFlashUntil = raylib.getTime() + 1.2;
                raylib.setClipboardText(codeBuf[0..codeLen:0]);
            }
            // 导出为可独立编译运行的 .zig 文件（拷到有 raylib 依赖的工程即可跑）
            const exportLabel: [:0]const u8 = if (raylib.getTime() < exportFlashUntil) "已导出" else "导出为 .zig";
            if (panel.button(exportLabel)) {
                exportFlashUntil = raylib.getTime() + 1.5;
                exportDemo(init.io, d.name, codeBuf[0..codeLen]);
            }
            raylib.endScissorMode();
            // 帧末按内容总高钳制滚动量（供下一帧使用）
            panelScroll = std.math.clamp(panelScroll, 0, @max(0, panel.cursor - controlsPanel.height));
        }

        // 底部：demo 显示实时生成的代码，文档页显示目录提示
        _ = raygui.statusBar(statusRect, "");
        if (demo != null) {
            raylib.drawTextEx(
                uiFont,
                codeBuf[0..codeLen:0],
                .{ .x = 12, .y = @floatFromInt(sh - statusHeight + 3) },
                fontSize,
                1,
                raylib.Color.light_gray,
            );
        } else {
            var hintBuf: [96:0]u8 = undefined;
            const hint = std.fmt.bufPrint(
                hintBuf[0..96],
                "共 {d} 个 API  -  * 号 = 有交互演示",
                .{catalog.entries.len},
            ) catch unreachable;
            hintBuf[hint.len] = 0;
            raylib.drawTextEx(
                uiFont,
                hintBuf[0..hint.len:0],
                .{ .x = 12, .y = @floatFromInt(sh - statusHeight + 3) },
                fontSize,
                1,
                raylib.Color.gray,
            );
        }
        var fpsBuf: [16:0]u8 = undefined;
        const fps = std.fmt.bufPrint(fpsBuf[0..16], "{d} FPS", .{raylib.getFPS()}) catch unreachable;
        fpsBuf[fps.len] = 0;
        raylib.drawTextEx(
            uiFont,
            fpsBuf[0..fps.len:0],
            .{ .x = @floatFromInt(sw - 90), .y = @floatFromInt(sh - statusHeight + 3) },
            fontSize,
            1,
            raylib.Color.gray,
        );

        // 下拉框放到帧末调用：raygui 是立即模式，展开菜单会被后续控件遮挡。
        // 开合在帧首手动管理，这里只检测"选中了某项"，选中后收起。
        const prevModuleSel = moduleSel;
        _ = raygui.dropdownBox(
            ddBounds,
            "全部;★ 收藏;核心;图形;纹理;文本;模型;音频;界面",
            &moduleSel,
            moduleEdit,
        );
        if (moduleSel != prevModuleSel) moduleEdit = false;

        raylib.endDrawing();
    }
}
