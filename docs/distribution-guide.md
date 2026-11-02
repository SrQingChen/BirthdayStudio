# 导出与分发

## 1. 两种导出形态

| 形态 | 说明 | 体积/启动 | 状态 |
|---|---|---|---|
| **播放器 + 配置包（默认）** | 通用 `Player.exe` + `profile/` + `启动演出.bat` → 文件夹与 zip | 小、导出秒级 | 已验证 |
| 单文件 exe（可选） | profile 打进 exe 资源，一个文件 | 大、启动慢 | 当前会退回默认形态；真正单文件需要专用构建 |

导出向导路径：顶栏「导出」→ 检查（错误门禁）→ 目录/名称 → 版权确认 → 形态 → 导出。

导出内容：

```
给XX的生日礼物/
  BirthdayStudioPlayer.exe     # 检测到 dist 构建产物时复制；否则开发启动器
  启动演出.bat
  README.txt
  profile/                     # profile.json、assets、preview、meta
  profile.bbp                  # 可选，便于再次编辑
  plugins/                     # 当前启用的插件（自动内嵌）
  LICENSES/
    GPL-3.0.txt                # 本体许可证全文 + 插件例外
    SOURCE.txt                 # 源码获取地址（GPLv3 §6）
    THIRD-PARTY.md             # Qt/PySide6/Pydantic/字体
    PROFILE-CONTENT.txt        # 用户创作内容不因打包变 GPL
    ASSET-LICENSES.md          # 版权确认清单（若填写）
```

## 2. 构建播放器

### PyInstaller（本机默认）

```bat
scripts\build_player.bat
```

- 生成 `dist\BirthdayStudioPlayer.exe`（onefile、windowed）。
- 实测体积 **177 MiB（185 MB）**，冷启动 5–8s；包含 Qt Quick 3D/PySide6/QML 模块。
- 首次运行会解包到 `%TEMP%\_MEIxxxx`；`BIRTHDAY_STUDIO_HOME` 仍指向 `%APPDATA%/BirthdayStudio`。

### Nuitka（推荐发布路径）

安装 Nuitka 与 C 编译器后：

```bat
set USE_NUITKA=1
scripts\build_player.bat
```

- 目标是 ≤60MB、启动更快；本次未安装工具链，未验证。
- 数据目录需随 exe 一起分发（`resources/`、`app/qml/`、`plugins/`、`LICENSE`）。

## 3. 干净机器验收（X-05）

1. 新建 Windows 10/11 虚拟机（无 Python、无 PySide6、无环境变量）。
2. 解压导出包或复制 `dist\BirthdayStudioPlayer.exe` + `profile/`。
3. 双击 `启动演出.bat`（或 `Player.exe --play profile`）。
4. 检查：音乐、七幕、3D 蛋糕、吹蜡烛、终幕彩带、跳过、静音/暂停、Esc 退出。
5. 本机已用空 `BIRTHDAY_STUDIO_HOME` 验证 onefile 启动、信封与蛋糕截图；仍建议在真机 VM 复测。

## 4. 个性化（X-03）

- 导出向导可设置文件名（默认「给 XX 的生日礼物」）。
- 图标与版本信息需要在构建时写入 exe（PyInstaller `--icon`、Nuitka `--windows-icon-from-ico`）；当前导出只改文件名。
- 单文件 exe 的图标/版本需在专用构建脚本中配置。

## 5. GPL 合规（X-06）

- 分发 `Player.exe` 属于 GPL 意义上的分发：必须提供对应源码获取方式。
- 导出包自动包含 `LICENSES/GPL-3.0.txt` 与 `SOURCE.txt`（指向 GitHub tag）。
- 插件接口例外：Stable Slots 插件是独立作品，可闭源；例外条款随 `LICENSE` 一并分发。
- 用户祝福文字、图片、音乐与配置档归创作者所有，不被 GPL 覆盖（`PROFILE-CONTENT.txt`）。
- 第三方组件：Qt/PySide6 LGPLv3（动态链接）、Pydantic MIT、内置合成音效 GPL、字体 OFL（若随包）。

## 6. 故障排查

| 现象 | 处理 |
|---|---|
| 双击 exe 无反应 | 查看 `%APPDATA%/BirthdayStudio/logs/app.log`；确认 exe 未被杀软隔离 |
| 只有声音没有画面 | 显卡驱动/Qt RHI 问题；尝试更新驱动，或设置 `BIRTHDAY_STUDIO_FORCE_2D=1` 强制使用 2.5D 蛋糕 |
| 音乐不响 | 导出包 `profile/assets` 是否完整；系统音频设备；播放器音量条 |
| 字体是方块 | 安装中文字体，或运行 `scripts/fetch_fonts.py` 后重新导出 |
| 导出后没有 exe | 先运行 `scripts/build_player.bat`；否则会生成开发启动器（需 Python） |
| 插件不生效 | manifest host 区间/ apiVersion / 文件是否在 `plugins/<id>/`；查看编辑器插件页提示 |
