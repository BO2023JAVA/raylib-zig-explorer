# -*- coding: utf-8 -*-
import re
src = open(r"C:\Users\one\Desktop\myworld\src\zh.zig", encoding="utf-8").read()
pat = re.compile(r'\.\{ "([^"]+)", "((?:[^"\\]|\\.)*)" \},')
out = []
for c, d in pat.findall(src):
    if not any('\u4e00' <= ch <= '\u9fff' for ch in d):
        out.append((c, d))
print(len(out))
for c, d in out:
    print(c + " :: " + d)
