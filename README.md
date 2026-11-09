<p align="center">
  <img src="docs/images/readme-hero.png" alt="BirthdayStudio — 七幕生贺演出终端">
</p>

<p align="center">
  <a href="https://github.com/SrQingChen/BirthdayStudio/releases/tag/v1.1.2"><img src="docs/images/badges/release.svg" alt="Release v1.1.2" height="28"></a>
  <a href="https://github.com/SrQingChen/BirthdayStudio/blob/main/LICENSE"><img src="docs/images/badges/license.svg" alt="GPL-3.0" height="28"></a>
  <img src="docs/images/badges/stack.svg" alt="PySide6 · QML · Qt 3D" height="28">
  <img src="docs/images/badges/platform.svg" alt="Windows 10 / 11" height="28">
  <a href="https://github.com/SrQingChen/BirthdayStudio/actions"><img src="docs/images/badges/tests.svg" alt="Tests 20/20 passing" height="28"></a>
</p>

<p align="center">
  <strong>配置驱动的交互式生贺演出终端</strong><br>
  把一句「生日快乐」，做成一场会自己展开的七幕仪式。
</p>

**BirthdayStudio** 用 PySide6 + QML + Qt Quick 3D 构建：**编辑器**负责编排与实时预览，**播放器**负责在干净 Windows 上零配置演出。同一套引擎、同一套设计令牌、同一份配置档。

> **下载**：[Windows x64 免安装包](https://github.com/SrQingChen/BirthdayStudio/releases/latest) · [GitHub Release](https://github.com/SrQingChen/BirthdayStudio/releases/tag/v1.1.2) · 源码 tag `v1.1.2`

<p align="center">
  <strong>开场</strong> → 火漆 · 信纸 → 轨迹祝福 → 收下祝福 → 中心消融 → <strong>蛋糕 · 许愿</strong> → <strong>终幕</strong>
</p>

| 配置编辑器 | 开场信封 | 3D 蛋糕 |
| :---: | :---: | :---: |
| ![编辑器](docs/images/editor.png) | ![开场信封](docs/images/envelope.png) | ![3D 蛋糕](docs/images/cake.png) |

## 为什么值得

- **七幕仪式，不是幻灯片**：火漆蓄力碎裂、信纸打字机、弹窗沿轨迹飞出、按压缩放、逐根吹蜡烛、confetti 终幕——每一幕都有一个参与点。
- **预览即引擎**：编辑器里看到的就是收礼人看到的，改动即时生效，零保真度损失。
- **数据安全底座**：800ms 防抖自动保存、原子写、journal 崩溃恢复、10 份滚动快照、30 天回收站。
- **两套主题 + 插件生态**：毛玻璃庆典 / 卡通立体出厂即用；八个 Stable Slots 稳定接口，插件可闭源分发。
- **健康红线做进工具**：闪烁、音量、低动效、对比度、目标尺寸全部 lint 强制，而不是靠创作者自觉。

## 快速开始

```bash
pip install -e .
python -m app                 # 编辑器
python -m app --play <配置>   # 播放器（id / profile 目录 / .bbp）
```

Windows 用户可直接下载 [免安装包](https://github.com/SrQingChen/BirthdayStudio/releases/latest)，双击「启动示例.bat」或「打开编辑器.bat」。

构建播放器：`scripts\build_player.bat`（PyInstaller onefile；设置 `USE_NUITKA=1` 可切换 Nuitka）。

## 技术栈

| 层 | 实现 |
|---|---|
| 演出 | QML ShowStage + Qt Quick 3D + 自绘 Canvas / MultiEffect |
| 编辑 | PySide6 + QML 三栏、实时预览、时间轴、校验中心 |
| 数据 | Pydantic schema、原子写、journal、快照、`.bbp` 配置包 |
| 音频 | QMediaPlayer + QSoundEffect + 双台交叉淡化 / ducking / 防爆音 |

## 文档

- [配置档 Schema](docs/theme-schema.md) · [编辑器规范](docs/editor-spec.md) · [插件 SDK](docs/plugin-sdk.md)
- [性能与验收](docs/performance-budget.md) · [导出与分发](docs/distribution-guide.md) · [第三方许可](docs/THIRD-PARTY.md)
- [贡献政策（DCO）](CONTRIBUTING.md)

## 项目结构

```
app/        引擎 / 编辑器 / 播放器 / Python 桥接
resources/  设计令牌 / 主题 / 合成音频 / 纹理
plugins/    示例插件（aurora-glass）
docs/       规范 / SDK / 验收 / 分发
tests/      单元测试 + QML 冒烟
scripts/    构建 / 素材生成 / README 资产
```

<details>
<summary><strong>已知边界与说明</strong></summary>

- PyInstaller onefile 约 177 MiB、启动 5–8s；Nuitka ≤60 MB 目标需安装工具链后复测。
- 单文件 exe 选项当前退回「播放器 + 配置包」形态。
- 3D 不可用时自动回退 2.5D 预渲染蛋糕；Qt 6.11 + D3D11 下 3D bloom 以 2D 光晕替代。
- 自定义视频背景 / 逐幕多段配乐尚未暴露到 schema。
- 字体使用系统回退；`scripts/fetch_fonts.py` 可下载 OFL 字体。
</details>

## 许可

本体以 **GPL-3.0-or-later** 发布，并附带 **GNU GPLv3 第 7 条附加许可——Stable Slots 插件接口例外**：通过稳定槽位 API 加载的主题插件是独立作品，可自由选择许可证（含闭源）。完整条款见 [LICENSE](LICENSE)。

导出包会自动附带 `LICENSES/`、第三方许可与源码获取说明；用户的祝福文字、媒体与配置档归创作者所有。

---

<p align="center">
  <sub><strong>BirthdayStudio 1.1.2</strong> · 作者 <a href="https://github.com/SrQingChen">SrQingChen</a> · 用一场仪式，认真地说一句生日快乐。</sub>
</p>
