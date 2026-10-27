"""从 raygui.h 提取所有 RAYGUIAPI 函数的 C 名和英文 doc，
并生成对应的中文翻译 pairs，追加到 zh.zig。"""
import re, sys, os

raygui_h = "zig-pkg/raygui/src/raygui.h"
with open(raygui_h, 'r', encoding='utf-8') as f:
    text = f.read()

# 提取所有 RAYGUIAPI 行
entries = []
for line in text.split('\n'):
    line = line.strip()
    if line.startswith('RAYGUIAPI'):
        paren = line.find('(')
        if paren == -1:
            continue
        before = line[len('RAYGUIAPI'):paren].strip()
        # 去掉 '*' 和空格，取最后一个 token = 函数名
        parts = before.replace('*', '').split()
        if not parts:
            continue
        c_name = parts[-1]
        # 行尾注释
        comment = ''
        if '//' in line:
            comment = line[line.index('//') + 2:].strip()
        entries.append((c_name, comment))

print(f"Found {len(entries)} RAYGUIAPI functions")
for c, d in entries[:5]:
    print(f"  {c} -> {d}")
print("  ...")
for c, d in entries[-3:]:
    print(f"  {c} -> {d}")

# raygui 中文翻译字典（手工整理，先给通用翻译）
translations = {
    # Global state
    "GuiEnable": "启用 GUI 控件（全局状态）",
    "GuiDisable": "禁用 GUI 控件（全局状态）",
    "GuiLock": "锁定 GUI 控件（全局状态）",
    "GuiUnlock": "解锁 GUI 控件（全局状态）",
    "GuiIsLocked": "检查 GUI 是否被锁定（全局状态）",
    "GuiSetAlpha": "设置 GUI 控件透明度（0.0~1.0）",
    "GuiSetState": "设置 GUI 全局状态",
    "GuiGetState": "获取 GUI 全局状态",
    # Font
    "GuiSetFont": "设置 GUI 自定义字体（全局）",
    "GuiGetFont": "获取 GUI 当前字体",
    # Style
    "GuiSetStyle": "设置控件的单个样式属性",
    "GuiGetStyle": "获取控件的单个样式属性",
    # Style loading
    "GuiLoadStyle": "从 .rgs 文件加载样式覆盖全局样式",
    "GuiLoadStyleFromMemory": "从内存（二进制）加载样式覆盖全局样式",
    "GuiLoadStyleDefault": "加载默认样式覆盖全局样式",
    # Tooltip
    "GuiEnableTooltip": "启用 GUI 工具提示（全局）",
    "GuiDisableTooltip": "禁用 GUI 工具提示（全局）",
    "GuiSetTooltip": "设置工具提示字符串",
    # Icons
    "GuiIconText": "获取带图标 id 前缀的文本",
    "GuiSetIconScale": "设置默认图标绘制尺寸",
    "GuiGetIcons": "获取 raygui 图标数据指针",
    "GuiLoadIcons": "加载 .rgi 图标文件到内部数据",
    "GuiLoadIconsFromMemory": "从内存加载 .rgi 图标数据",
    "GuiDrawIcon": "使用指定像素尺寸和颜色绘制图标",
    # Utility
    "GuiGetTextWidth": "根据 GUI 样式和图标尺寸计算文本宽度",
    # Container controls
    "GuiWindowBox": "窗口盒控件（可关闭）",
    "GuiGroupBox": "分组盒控件（带标题文本）",
    "GuiLine": "分隔线控件（可含文本）",
    "GuiPanel": "面板容器",
    "GuiScrollPanel": "可滚动面板容器",
    # Basic controls
    "GuiLabel": "文本标签",
    "GuiButton": "按钮",
    "GuiLabelButton": "标签按钮（带可选图标）",
    "GuiToggle": "开关按钮（复选风格）",
    "GuiToggleGroup": "开关按钮组（单选风格）",
    "GuiToggleSlider": "滑动开关按钮",
    "GuiCheckBox": "复选框",
    "GuiComboBox": "下拉选择框（不可编辑）",
    "GuiDropdownBox": "下拉列表框（可展开编辑）",
    "GuiSpinner": "微调器（数值输入）",
    "GuiValueBox": "数值输入框（整数）",
    "GuiValueBoxFloat": "数值输入框（浮点数）",
    "GuiTextBox": "文本输入框",
    # Sliders/progress
    "GuiSlider": "滑动条（可选左右标签）",
    "GuiSliderBar": "水平滑动条（带颜色填充）",
    "GuiProgressBar": "进度条（可选左右标签）",
    # Status / info
    "GuiStatusBar": "状态栏",
    "GuiDummyRec": "占位矩形控件",
    "GuiGrid": "网格控件（返回鼠标所在格子坐标）",
    # Advanced / list
    "GuiListView": "列表视图（单项选择）",
    "GuiListViewEx": "扩展列表视图（带滚动索引和焦点）",
    "GuiTabBar": "标签栏（多标签页）",
    "GuiTabBarEx": "扩展标签栏（带滚动和焦点）",
    # Popups
    "GuiMessageBox": "消息对话框（带确定/取消按钮）",
    "GuiTextInputBox": "文本输入对话框",
    # Color controls
    "GuiColorPicker": "颜色选择器（整合 HSV/HSL）",
    "GuiColorPanel": "颜色面板（RGB 方块）",
    "GuiColorBarAlpha": "Alpha 滑动条",
    "GuiColorBarHue": "色相滑动条",
    "GuiColorPickerHSV": "HSV 颜色选择器",
    "GuiColorPanelHSV": "HSV 颜色面板",
}

# 生成 pairs 追加内容
zig_lines = []
for c_name, doc in entries:
    zh = translations.get(c_name, doc)  # 没匹配上的回退英文
    zig_lines.append(f'    .{{ .c = "{c_name}", .d = "{zh}" }},')

print(f"\nGenerated {len(zig_lines)} raygui pairs for zh.zig")
print("Sample:")
for l in zig_lines[:3]:
    print(f"  {l}")

# 写临时文件让主脚本读取
with open(os.path.join(os.path.dirname(__file__), '_raygui_pairs.txt'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(zig_lines))
