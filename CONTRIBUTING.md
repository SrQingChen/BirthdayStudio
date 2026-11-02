# 贡献政策（DCO）

感谢你愿意让这款生贺终端更好。

## 许可

- 本项目以 **GPL-3.0-or-later + GPLv3 §7 插件接口例外** 发布。
- 提交 PR 即表示你同意你的贡献按上述许可授权，并同意版权持有人 SrQingChen 在未来的版本中继续使用该贡献。
- 使用 **Developer Certificate of Origin (DCO)**：每个提交需包含 `Signed-off-by: 你的名字 <邮箱>`。

```
git commit -s -m "feat: ..."
```

## 代码与素材

- 不要提交来源不明、不可商用或与 GPL 不兼容的图片、音乐、字体、模型。
- 新增素材请附来源与许可证（`resources/.../README.md` 或 profile 的 `license` 字段）。
- 插件示例请放在 `plugins/` 下，确保仅使用 QML/JS/着色器/资产，不执行 Python。

## 开发约定

- 遵循 AGENTS.md 中的环境与工具约定；Windows GUI 操作优先使用 windows-mcp。
- 运行 `python -m unittest discover -s tests` 必须全绿。
- QML 变更需在离屏模式加载一次（`QT_QPA_PLATFORM=offscreen python -m app --screenshot ...`），避免类型/属性错误。
- 保持设计令牌驱动：不要在组件里硬编码颜色/时长/圆角；新增令牌写入 `resources/design-tokens.json`。
- 健康红线不可绕过：闪烁、音量、低动效、对比度、目标尺寸。

## 提交信息

使用 conventional commits：`feat:`、`fix:`、`docs:`、`refactor:`、`test:`、`build:`、`chore:`。

## 报告问题

请提供：Windows 版本、显卡/驱动、复现步骤、`%APPDATA%/BirthdayStudio/logs/app.log` 相关片段、配置档（可脱敏）。
