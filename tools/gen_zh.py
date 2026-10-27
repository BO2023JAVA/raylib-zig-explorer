# -*- coding: utf-8 -*-
# 由官方中文速查表(cheatsheet_zh 的 zh/raylib_*.c) + 项目绑定 catalog.zig 生成 src/zh.zig。
# 以项目绑定(catalog)的命名为准，按 C 原名(c_name)匹配中文描述；未命中的回退到 catalog 的英文 doc。
import os, re, io

ROOT = r"C:\Users\one\Desktop\myworld"
ZH_DIR = os.path.join(ROOT, "tools", "zh")
CATALOG = os.path.join(ROOT, "src", "catalog.zig")
OUT = os.path.join(ROOT, "src", "zh.zig")

mods = ["core", "shapes", "textures", "text", "models", "audio"]

# 每行：  <返回类型> <FuncName>(args); //中文描述   或   无注释
line_re = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\s*\([^;]*?\)\s*;\s*(?://\s*(.*))?$")

zh = {}
for m in mods:
    p = os.path.join(ZH_DIR, "raylib_%s.c" % m)
    with open(p, encoding="utf-8") as f:
        for line in f:
            s = line.rstrip("\n")
            if not s.strip():
                continue
            ls = s.lstrip()
            if ls.startswith("//") or ls.startswith("/*") or ls.startswith("*"):
                continue
            mt = line_re.search(s.strip())
            if not mt:
                continue
            name = mt.group(1)
            desc = (mt.group(2) or "").strip()
            # 去掉结尾行注释分隔
            zh[name] = desc

# 解析 catalog：每条 .name/.c_name/.module/.section/.doc
cat_re = re.compile(
    r"\.name\s*=\s*\"([^\"]+)\",\s*\.c_name\s*=\s*\"([^\"]+)\",\s*"
    r"\.module\s*=\s*\.[a-z_]+,\s*\.section\s*=\s*\"([^\"]*)\",\s*"
    r"\.doc\s*=\s*\"([^\"]*)\""
)

entries = []
with open(CATALOG, encoding="utf-8") as f:
    for line in f:
        mt = cat_re.search(line)
        if mt:
            entries.append((mt.group(1), mt.group(2), mt.group(4)))

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

# 需要真正手译的英文(速查表未翻)或缺失项：这里预置人工中文，优先于速查表
manual = {
    # --- core ---
    "SetWindowIcons": "设置窗口图标（多张图像，RGBA 32位，仅桌面平台）",
    "LoadRandomSequence": "加载随机值序列，序列内无重复值",
    "ComputeCRC32": "计算 CRC32 哈希",
    "ComputeMD5": "计算 MD5 哈希，返回静态 int[4]（16字节）",
    "ComputeSHA1": "计算 SHA1 哈希，返回静态 int[5]（20字节）",
    "ComputeSHA256": "计算 SHA256 哈希，返回静态 int[8]（32字节）",
    "ToggleBorderlessWindowed": "切换窗口为无边框窗口模式，窗口自动调整为显示器分辨率",
    "SetWindowMaxSize": "设置窗口最大尺寸（用于 FLAG_WINDOW_RESIZABLE）",
    "SetWindowFocused": "将窗口设为获得焦点",
    "GetClipboardImage": "获取剪贴板图像内容",
    "IsShaderValid": "检查着色器是否有效（已加载到 GPU）",
    "GetScreenToWorldRayEx": "从屏幕坐标获取世界空间射线（如鼠标位置），在指定视口内",
    "UnloadRandomSequence": "卸载随机值序列",
    "FileRename": "重命名文件（如果存在）",
    "FileRemove": "删除文件（如果存在）",
    "FileCopy": "把文件从路径 A 复制到路径 B，目标路径不存在则创建",
    "FileMove": "把文件从目录 A 移动到目录 B，目标路径不存在则创建",
    "FileTextReplace": "替换已有文件中的文本",
    "FileTextFindIndex": "在已有文件中查找文本",
    "IsFileHidden": "检查文件路径（文件或目录）是否被系统隐藏",
    "MakeDirectory": "创建目录（含完整请求路径），成功返回 0",
    "IsPathDirectory": "检查给定路径是否指向目录",
    "IsPathAbsolute": "检查给定路径是否为绝对路径",
    "IsFileNameValid": "检查文件名在当前平台/系统上是否合法",
    "GetDirectoryFileCount": "获取目录中的文件数量",
    "GetDirectoryFileCountEx": "获取目录文件数量（支持扩展名过滤和递归扫描），过滤串中可用 'DIR' 包含子目录",
    "LoadAutomationEventList": "从文件加载自动化事件列表，NULL 表示空列表，容量 = MAX_AUTOMATION_EVENTS",
    "UnloadAutomationEventList": "卸载自动化事件列表",
    "ExportAutomationEventList": "把自动化事件列表导出为文本文件",
    "SetAutomationEventList": "设置要录制到的自动化事件列表",
    "SetAutomationEventBaseFrame": "设置自动化事件的内部基准帧以开始录制",
    "StartAutomationEventRecording": "开始录制自动化事件（必须先设置事件列表）",
    "StopAutomationEventRecording": "停止录制自动化事件",
    "PlayAutomationEvent": "回放一条已录制的自动化事件",
    "IsKeyPressedRepeat": "检查按键是否被重复按下（按住连发）",
    "GetKeyName": "获取当前键盘布局下某键的名称（例如 AZERTY 键盘上 KEY_A 返回 'q'）",
    "SetGamepadVibration": "设置手柄两个马达的振动（时长以秒为单位）",
    # --- shapes ---
    "GetShapesTexture": "获取用于形状绘制的纹理",
    "GetShapesTextureRectangle": "获取用于形状绘制的纹理源矩形",
    "DrawLineDashed": "绘制虚线",
    "DrawTriangleGradient": "绘制带插值颜色的三角形（逆时针顶点/颜色顺序）",
    "DrawTriangleLinesEx": "绘制三角形轮廓（指定线宽，逆时针顶点顺序）",
    "DrawRectangleRoundedLinesEx": "绘制圆角矩形轮廓（指定线宽）",
    "DrawCircleSectorLinesEx": "绘制圆扇形轮廓（指定线宽）",
    "DrawCircleLinesV": "绘制圆轮廓（矢量版本）",
    "DrawCircleLinesEx": "绘制圆轮廓（指定线宽）",
    "DrawEllipseV": "绘制椭圆（矢量版本）",
    "DrawEllipseLinesV": "绘制椭圆轮廓（矢量版本）",
    "DrawEllipseLinesEx": "绘制椭圆轮廓（指定线宽）",
    "DrawRingLinesEx": "绘制环形轮廓（指定线宽）",
    "DrawSplineSegmentLinear": "绘制样条线段：线性，2 个点",
    "DrawSplineSegmentBasis": "绘制样条线段：B 样条，4 个点",
    "DrawSplineSegmentCatmullRom": "绘制样条线段：Catmull-Rom，4 个点",
    "DrawSplineSegmentBezierQuadratic": "绘制样条线段：二次贝塞尔，2 个点、1 个控制点",
    "DrawSplineSegmentBezierCubic": "绘制样条线段：三次贝塞尔，2 个点、2 个控制点",
    "GetSplinePointLinear": "求样条点：线性",
    "GetSplinePointBasis": "求样条点：B 样条",
    "GetSplinePointCatmullRom": "求样条点：Catmull-Rom",
    "GetSplinePointBezierQuadratic": "求样条点：二次贝塞尔",
    "GetSplinePointBezierCubic": "求样条点：三次贝塞尔",
    "CheckCollisionCircleLine": "检查圆是否与两点 [p1]、[p2] 之间的线段碰撞",
    "CheckCollisionPointPoly": "检查点是否在多边形（顶点数组描述）内部",
    "DrawSplineLinear": "绘制样条：线性，至少 2 个点",
    "DrawSplineBasis": "绘制样条：B 样条，至少 4 个点",
    "DrawSplineCatmullRom": "绘制样条：Catmull-Rom，至少 4 个点",
    "DrawSplineBezierQuadratic": "绘制样条：二次贝塞尔，至少 3 个点（1 个控制点）",
    "DrawSplineBezierCubic": "绘制样条：三次贝塞尔，至少 4 个点（2 个控制点）",
    # --- textures ---
    "LoadImageAnimFromMemory": "从内存缓冲区加载图像序列",
    "IsImageValid": "检查图像是否有效（数据和参数）",
    "ExportImageToMemory": "把图像导出到内存缓冲区，内存需用 MemFree() 释放",
    "GenImageGradientLinear": "生成图像：线性渐变，方向为角度 [0..360]，0 表示垂直渐变",
    "GenImageGradientSquare": "生成图像：方形渐变",
    "GenImagePerlinNoise": "生成图像：柏林噪声",
    "GenImageText": "生成图像：由文本数据生成的灰度图",
    "ImageFromChannel": "从另一张图像的某个通道创建图像（灰度）",
    "ImageBlurGaussian": "用盒式模糊近似应用高斯模糊",
    "ImageRotate": "按给定角度（-359 到 359）旋转图像",
    "ImageDrawLineEx": "在图像内绘制指定线宽的线",
    "ImageDrawLineStrip": "在图像内绘制折线序列",
    "ImageDrawTriangle": "在图像内绘制三角形",
    "ImageDrawTriangleGradient": "在图像内绘制带插值颜色的三角形",
    "ImageDrawTriangleLines": "在图像内绘制三角形轮廓",
    "ImageDrawTriangleFan": "在图像内绘制三角形扇形（首个顶点为圆心）",
    "ImageDrawTriangleStrip": "在图像内绘制三角形带",
    "ImageDrawRectanglePro": "在图像内绘制带 pro 参数的实心矩形",
    "ImageDrawRectangleLinesEx": "在图像内绘制指定线宽的矩形轮廓",
    "ImageDrawRectangleGradientEx": "在图像内绘制渐变矩形（逆时针颜色顺序）",
    "ImageDrawCircleLines": "在图像内绘制圆轮廓",
    "ImageDrawCircleLinesV": "在图像内绘制圆轮廓（矢量版本）",
    "ImageDrawCircleGradient": "在图像内绘制渐变填充圆",
    "ImageDrawImage": "在图像内绘制另一张图像",
    "ImageDrawImageEx": "在图像内绘制带缩放和旋转的图像",
    "ImageDrawImageRec": "在图像内绘制由矩形定义的部分图像",
    "ImageDrawImagePro": "在图像内把矩形定义的部分绘制到目标矩形，带缩放和旋转",
    "ImageDrawTextPro": "用字体和 pro 参数（旋转）在图像内绘制文本",
    "LoadRenderTextureEx": "加载用于渲染的纹理（帧缓冲），指定格式",
    "IsTextureValid": "检查纹理是否有效（已加载到 GPU）",
    "IsRenderTextureValid": "检查渲染纹理是否有效（已加载到 GPU）",
    "ColorIsEqual": "检查两个颜色是否相等",
    "ColorTint": "把颜色与另一颜色相乘（着色）",
    "ColorBrightness": "获取亮度校正后的颜色，亮度因子范围 -1.0 到 1.0",
    "ColorContrast": "获取对比度校正后的颜色，对比度取值 -1.0 到 1.0",
    "ColorLerp": "获取两颜色间线性插值（混合）的颜色，因子 [0.0..1.0]",
    "ImageKernelConvolution": "对图像应用自定义方形卷积核",
    "LoadTextLines": "把文本加载为独立行（'\\n' 分隔）",
    "UnloadTextLines": "卸载文本行",
    # --- text ---
    "IsFontValid": "检查字体是否有效（字体数据已加载，不检查 GPU 纹理）",
    "SetTextLineSpacing": "设置带换行绘制时的垂直行距",
    "MeasureTextCodepoints": "为字体的码点数组测量字符串尺寸",
    "UnloadUTF8": "卸载由码点数组编码得到的 UTF-8 文本",
    "GetCodepointNext": "获取 UTF-8 字符串中的下一个码点，失败返回 0x3f('?')",
    "GetCodepointPrevious": "获取 UTF-8 字符串中的上一个码点，失败返回 0x3f('?')",
    "TextRemoveSpaces": "移除文本中的空格，拼接单词",
    "GetTextBetween": "获取两个字符串之间的文本",
    "TextReplaceAlloc": "用新字符串替换文本串，内存需用 MemFree() 释放",
    "TextReplaceBetween": "替换两个指定字符串之间的文本",
    "TextReplaceBetweenAlloc": "替换两个指定字符串之间的文本，内存需用 MemFree() 释放",
    "TextInsertAlloc": "在指定字节位置插入文本，内存需用 MemFree() 释放",
    "TextToSnake": "把字符串转为蛇形命名（下划线分隔）",
    "TextToCamel": "把字符串转为驼峰命名",
    "TextToFloat": "从文本获取浮点值",
    # --- models ---
    "DrawCapsule": "绘制胶囊体，其球形端面中心在 startPos 和 endPos",
    "DrawCapsuleWires": "绘制胶囊体线框，其球形端面中心在 startPos 和 endPos",
    "IsModelValid": "检查模型是否有效（已加载到 GPU，VAO/VBOs）",
    "ExportMeshAsCode": "把网格导出为代码文件（.h），定义多组顶点属性数组",
    "IsMaterialValid": "检查材质是否有效（已指定着色器、贴图已加载到 GPU）",
    "UpdateModelAnimationEx": "更新模型动画姿态，混合两个动画",
    # --- audio ---
    "GetMasterVolume": "获取主音量（监听器）",
    "IsWaveValid": "检查波形数据是否有效（数据和参数已加载）",
    "LoadSoundAlias": "创建共享源声音采样数据的新声音，不拥有声音数据",
    "IsSoundValid": "检查声音是否有效（数据已加载且缓冲区已初始化）",
    "UnloadSoundAlias": "卸载声音别名（不释放采样数据）",
    "IsMusicValid": "检查音乐流是否有效（上下文和缓冲区已初始化）",
    "IsAudioStreamValid": "检查音频流是否有效（缓冲区已初始化）",
    "AttachAudioMixedProcessor": "把音频流处理器附加到整个音频管线，接收 'float'（立体声）的帧×2 采样",
    "DetachAudioMixedProcessor": "从整个音频管线分离音频流处理器",
}

matched_cn = 0   # 速查表提供且为中文(含非 ASCII)
matched_en = 0   # 速查表只有英文注释
missing = 0      # 速查表完全没有
lines = []
lines.append("// 由 tools/gen_zh.py 从 raylib 官方中文速查表(cheatsheet_zh)生成，请勿手工编辑。")
lines.append("// 以项目绑定库(catalog)命名为准，按 C 原名(c_name)匹配；未在速查表命中的回退英文 doc。")
lines.append("const std = @import(\"std\");")
lines.append("")
lines.append("const pairs = [_]struct { c: [:0]const u8, d: [:0]const u8 }{")
for name, cname, doc in entries:
    d = manual.get(cname)
    if d:
        matched_cn += 1
    else:
        d = zh.get(cname, "").strip()
        if d:
            has_cjk = any('\u4e00' <= ch <= '\u9fff' for ch in d)
            if has_cjk:
                matched_cn += 1
            else:
                matched_en += 1
        else:
            d = doc  # 缺中文则回退英文 doc
            missing += 1
    lines.append('    .{ .c = "%s", .d = "%s" },' % (esc(cname), esc(d)))
lines.append("};")
lines.append("")
lines.append("/// 按 C 原名取 API 中文描述；未命中返回空串。")
lines.append("pub fn desc(c: [:0]const u8) [:0]const u8 {")
lines.append("    for (pairs) |p| {")
lines.append("        if (std.mem.eql(u8, p.c, c)) return p.d;")
lines.append("    }")
lines.append('    return "";')
lines.append("}")

out = "\n".join(lines) + "\n"
with open(OUT, "w", encoding="utf-8") as f:
    f.write(out)

print("total catalog entries:", len(entries))
print("cheatsheet Chinese desc:", matched_cn)
print("cheatsheet English-only:", matched_en)
print("fallback/missing (English doc):", missing)
print("written:", OUT, os.path.getsize(OUT), "bytes")
