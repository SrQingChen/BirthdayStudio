# 第三方依赖与许可

| 组件 | 版本/来源 | 许可证 | 分发注意事项 |
|---|---|---|---|
| Qt 6 / PySide6 | 6.11.1（官方 wheel） | LGPLv3（Qt 双许可，项目使用 LGPL 分支） | 动态链接分发；随包附 LGPLv3 与 Qt 许可声明；不静态链接 |
| Pydantic | 2.x | MIT | 附 MIT 声明 |
| Python | 3.10+ | PSF License | 运行时/打包产物附 PSF 声明 |
| PyInstaller | 构建期 | GPL-2.0 + 启动器例外 | 仅构建工具；产物不受 GPL 影响（bootloader 例外） |
| Nuitka | 构建期（可选） | Apache-2.0 | 仅构建工具 |
| Pillow | 开发脚本 | HPND | 不进运行时包；用于生成纹理/截图工具 |
| 内置字体（可选） | Noto Sans SC / Noto Serif SC | SIL OFL 1.1 | 若随包分发，附 OFL 全文；字体的 Reserved Font Name 不修改 |
| 内置音频 | `scripts/generate_audio.py` 合成 | 随本体 GPL-3.0 | 无第三方采样 |
| 内置纹理 | 由脚本绘制/生成 | 随本体 GPL-3.0 | 无第三方素材 |

## 用户创作内容

配置档中的祝福文字、图片、音乐、视频、字体属于创作者自己的内容，**不因随 GPL 程序打包而变成 GPL 覆盖作品**。导出包中的 `LICENSES/PROFILE-CONTENT.txt` 明确这一点。

## 插件

通过 Stable Slots API 加载的主题插件是独立作品，可任意选择许可证（含闭源），受 GPLv3 §7 插件接口例外保护。插件不得包含 GPL 不兼容的代码与素材；插件作者自行负责其资产授权。

## 本仓库许可证

- 本体：`GPL-3.0-or-later`（`LICENSE` 内含 GPLv3 全文 + 插件接口例外）。
- 导出包：自动附带 `LICENSES/GPL-3.0.txt`、`SOURCE.txt`、`THIRD-PARTY.md`。
