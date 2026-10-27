"""收集 zh.zig 中所有唯一 Unicode 码点（.d 描述 + .zh 分类名 + 树形符号）
+ ASCII 可打印字符，重新生成 pub const glyphs 数组覆盖到 zh.zig 末尾。"""
import re

with open('src/zh.zig', 'r', encoding='utf-8') as f:
    content = f.read()

# 移除旧的 glyphs 数组
content = re.sub(r'\n// 需要加载到字体里的所有 Unicode 码点.*?pub const glyphs = \[_]i32\{[^}]*\};\n?', '\n', content, flags=re.DOTALL)

chars = set()
# .d = "..." API 描述
for d in re.findall(r'\.d = "([^"]*)"', content):
    chars.update(ord(ch) for ch in d)
# .zh = "..." 分类名
for d in re.findall(r'\.zh = "([^"]*)"', content):
    chars.update(ord(ch) for ch in d)
# module_names 数组里的中文
mm = re.search(r'module_names = \[_\]\[:0\]const u8\{(.*?)\};', content, re.DOTALL)
if mm:
    for d in re.findall(r'"([^"]*)"', mm.group(1)):
        chars.update(ord(ch) for ch in d)

# 树形 UI 符号
for ch in '·—':
    chars.add(ord(ch))

# main.zig / playground.zig 里硬编码的中文字符串（状态栏、标签等）
import glob
for src in glob.glob('src/**/*.zig', recursive=True):
    with open(src, 'r', encoding='utf-8') as f:
        for ch in f.read():
            if ord(ch) > 127:
                chars.add(ord(ch))

# ASCII 可打印
chars |= set(range(32, 127))
combined = sorted(chars)

zig_lines = [
    "// 需要加载到字体里的所有 Unicode 码点（ASCII + 描述/分类名中的 CJK 字符 + UI 符号）",
    f"// 共 {len(combined)} 个 glyphs，由 tools/update_glyphs.py 生成",
    "pub const glyphs = [_]i32{",
]
for cp in combined:
    zig_lines.append(f"    {cp},")
zig_lines.append("};")

new_content = content.rstrip() + "\n" + "\n".join(zig_lines) + "\n"
with open('src/zh.zig', 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f"glyphs regenerated: {len(combined)} codepoints")
