# 性能预算与验收

## 1. 预算

| 层 | 目标 | 实现要点 |
|---|---|---|
| 2D 演出层 | 60fps 目标 / 30fps 下限 | 全屏 Canvas 背景只画一次；bokeh 用预渲染 PNG 做慢速位移；弹窗用 Repeater + Behavior，不做逐帧 JS 重排 |
| 毛玻璃 | 同屏弹窗 ≤12，blur 16/24/30 三档 | 自绘 tint + 内部光斑 + 2% 噪点 + 1–2px 边框；不使用全屏实时模糊 |
| 3D 层 | 帧预算 ≤8ms | 基本体（Cylinder/Sphere/Cone/Rectangle）；阴影只对蛋糕层/蜡烛开启；无外部模型；粒子用 sprite 面片 |
| 粒子 | confetti ≤420；火焰 5 个 sprite | confetti 上限 `max_particles`；低动效降为单次 28 粒 |
| 播放器启动 | 冷启动 ≤3s（SSD） | onefile 需解包，实测约 5–8s；onedir/Nuitka 可达标 |
| 内存 | 播放器 ≤600MB / 编辑器 ≤1GB | PySide6 + QtQuick3D 常驻约 200–400MB；未做长时间压力测试 |
| 自动保存 | 写盘 ≤50ms，不阻塞 UI | 原子写、800ms 防抖；预览图最多 20s 重绘一次 |

## 2. 运行时降级矩阵

| 故障 | 行为 |
|---|---|
| BGM/音效缺失或解码失败 | 静默跳过 + 日志；编辑器资源页标红 |
| 视频背景解码失败 | 当前版本未使用视频背景；回退静态渐变 |
| 3D 初始化失败（驱动/无 GPU） | **已实现**：ShowStage 用 Loader 加载 Cake3DStage，加载失败或 `BIRTHDAY_STUDIO_FORCE_2D=1` 时切换 Cake2DStage（预渲染 2.5D 蛋糕，点击吹蜡烛仍可用） |
| 连续掉帧 | 未实现自动降级探测；低动效/高对比/关闭 3D 阴影可手动降载 |
| 字体缺失 | QML 字体栈回退系统中文；可安装 `resources/fonts/` |
| 配置字段非法 | Pydantic 回退 + 校验中心提示，不崩溃 |
| 麦克风不可用/拒绝 | 自动回退点击吹蜡烛，提示原因 |
| 插件缺失/不兼容 | 宿主用内置槽位组件；编辑器给出可读提示 |
| 资源路径损坏 | 校验中心报错并阻止导出；预览跳过该资源 |

## 3. 验收指标

| # | 指标 | 状态 / 验证方式 |
|---|---|---|
| 1 | 七幕链路 1080p/1440p/4K@150% 全程丢帧 <1% | 已做截图与交互走查；未做逐帧统计 |
| 2 | 编辑器审计在两套出厂主题零错误零警告 | `python -m unittest discover -s tests` → `test_default_profiles_pass` |
| 3 | kill 进程模拟崩溃 ×10，恢复成功率 100% | 单元测试覆盖 journal 判定 + 恢复；UI 恢复对话框已跑通 |
| 4 | 导出包在无 Python 的干净 Win10/11 完整演出 | PyInstaller onefile 在空 `BIRTHDAY_STUDIO_HOME` 下启动并输出 intro/cake 截图（3D 正常） |
| 5 | 播放器 exe ≤60MB | **未达标**：PyInstaller onefile 实测 177 MiB（185 MB）；Nuitka 构建脚本已提供，需安装工具链后复测 |
| 6 | 点击反馈 ≤100ms | 按压动画 120ms 完成下压，首帧立即开始；未用高速摄影测量 |

## 4. 已实现的无障碍/安全约束

- 所有闪烁类效果频率 ≤3Hz；无全屏白爆闪；无规律红闪。
- 默认音量 50%；常驻静音/暂停/音量；所有启停 10–20ms 斜坡；交叉淡化 300–1000ms。
- 低动效：系统检测 + 应用开关 + 每幕降级（位移→淡入、粒子减量、浮动关闭）。
- 高对比：毛玻璃回退不透明面板、1–3px 边框、投影关闭、焦点环 3px。
- 目标尺寸：主按钮 ≥44px；弹窗/卡片 ≥24px；火漆热区 128px。
- 文字对比：信纸墨色/主题角色对在 validator 中强制 4.5:1。

## 5. 已知性能/实现注意

1. **3D bloom**：策划案要求 `ExtendedSceneEnvironment` 后处理。在本次 Qt 6.11.1 + Windows D3D11 环境实测中，该环境会把整个 3D 场景渲染为黑色；因此当前使用 plain `SceneEnvironment` + 发光火焰 sprite + 2D 光晕/暗角替代。后续可在确认 RHI 行为后加能力开关恢复 bloom。
2. **3D 回退**：已加入 2.5D 预渲染蛋糕（`Cake2DStage`）+ Loader 自动回退；可用 `BIRTHDAY_STUDIO_FORCE_2D=1` 强制验证。2.5D 视觉细节弱于 3D，但吹蜡烛/许愿流程一致。
3. **onefile 启动**：PyInstaller onefile 首次启动需解包到 `_MEIPASS`，冷启动约 5–8s；正式发布建议 Nuitka standalone 或 PyInstaller onedir。
4. **图片体积**：docs/images 为验收截图，发布时可裁剪/压缩。
