# 字体

应用启动时会扫描本目录下的 `.ttf/.otf/.ttc` 并注册。

- 默认字体栈：思源黑体 / 霞鹜文楷 / MiSans / 微软雅黑（系统回退）；衬线：思源宋体 / Noto Serif SC / 宋体。
- 想在没有中文字体的 Windows 上保证显示，可运行 `python scripts/fetch_fonts.py` 下载 Noto Sans SC / Noto Serif SC（SIL OFL 1.1），文件会落在本目录。
- 字体作为独立作品随包分发，受 OFL 约束；不要修改字体名中的 Reserved Font Name。
