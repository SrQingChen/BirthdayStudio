# 插件 SDK · Stable Slots API v1

> 插件是 **QML / JS + 着色器 + 资产**，不执行任意 Python，也不具备磁盘/网络能力。宿主在启动时扫描 `plugins/<plugin-id>/`，校验 manifest 后注册。插件通过 `components/<Slot>.qml` 覆写稳定槽位。

## 1. 安全边界

1. 宿主只读取 `manifest.json`、`tokens.json`、`components/*.qml`、`assets/*`，**从不 import 插件 Python**。
2. 插件加载时执行与本体内置组件完全相同的健康 lint（光敏、对比度、目标尺寸、默认音量）。
3. 导出包自动内嵌所用插件；收礼人无需另装。
4. 插件同受三条健康红线约束。
5. 许可证：本体 GPL-3.0，但 Stable Slots 插件是独立作品，可任意选择许可证（含闭源），见 `LICENSE` 的 GPLv3 §7 附加许可。

## 2. 插件包结构

```
plugins/<plugin-id>/
  manifest.json
  tokens.json          # 可选：设计令牌 delta（深合并）
  components/
    PopupCard.qml      # 槽位组件（文件名必须与槽位同名）
    Background.qml
    ...
  assets/              # 贴图/粒子/字体/示例 BGM
  preview.png          # 主题卡片缩略图（可选）
```

### manifest.json

```json
{
  "id": "aurora-glass",
  "name": "极光玻璃（示例插件）",
  "version": "1.0.0",
  "apiVersion": 1,
  "host": ">=1.0.0 <2.0.0",
  "author": "SrQingChen",
  "description": "为轨迹弹窗提供极光带外观。",
  "slots": ["PopupCard"],
  "permissions": ["read-assets"],
  "license": "GPL-3.0-or-later OR proprietary (plugin exception)"
}
```

- `apiVersion` 必须为 `1`。
- `host` 使用简化的 semver range：`>=` `<=` `>` `<` `=` `^` `~`，空格表示 AND，`||` 表示 OR。
- 兼容性不满足时，编辑器显示可读提示且拒绝启用；导出包不会携带不兼容插件。

### tokens.json

与 `resources/design-tokens.json` 同构的 **delta**，例如：

```json
{
  "color": { "palette": { "tertiary": "#7ee0d0" } },
  "background": { "bokeh": ["#7ee0d0", "#a78bfa", "#ffb08a"] },
  "glass": { "borderAlpha": [0.42, 0.62] }
}
```

深合并规则：dict 递归合并；list 整体替换。插件令牌不能修改 `schema_version` 或宿主路径。

## 3. 八个稳定槽位

| 槽位 | 宿主位置 | 职责 | 输入属性 / 信号 |
|---|---|---|---|
| `PopupCard` | 轨迹弹窗 | 单只祝福卡外观 | `card`、`tokens`、`cardWidth`、`cardHeight`、`accentColor`、`displayStyle`、`highContrast`、`reducedMotion` |
| `WaxSeal` | 信封火漆 | 火漆视觉与按压 | `sealColor`、`sealHighlight`、`pressScale`；`signal activated()` |
| `LetterPaper` | 信纸 | 信纸材质/纹理底 | `paperColor`、`inkColor`、`accentColor` |
| `ConfirmButton` | 「收下祝福」按钮 | 按钮材质 | `text`、`tokens`、`displayStyle`、`pressScale`、`pressed` |
| `DissolveEffect` | 中心消融 | 消融叠加层（装饰） | `progress`（0..1）、`active` |
| `Background` | 演出背景 | 背景层 | `tokens`、`variant`（paper/cake）、`reducedMotion`、`highContrast` |
| `CakeDecor` | 3D 蛋糕 | 蛋糕上方 2D 装饰层 | `profile`、`tokens`、`active` |
| `FinaleFX` | 终幕 | 彩带/庆祝粒子 | `config`、`reducedMotion`、`active` |

### 契约约定

- 槽位组件是 **视觉层**：宿主负责交互与数据；插件不得修改 `profile` 或调用 `session`。
- 组件根建议 `Item`，由宿主 Loader 填满槽位尺寸；`implicitWidth/Height` 会被忽略。
- 所有属性在加载后由宿主赋值一次；需要动态更新的属性（如 `pressed`、`progress`、`active`）由宿主通过 `Qt.binding` 绑定。
- 必需属性缺失或赋值失败时，宿主回退到内置组件，不中断演出。
- 不提供 `component` 的槽位自动使用内置实现。
- 插件组件内不要创建 `Window`、`Popup` 或读取文件；使用 `tokens` 和 `assets`。

### PopupCard 最小示例

```qml
import QtQuick

Item {
    property var card: ({})
    property var tokens: ({})
    property real cardWidth: 400
    property real cardHeight: 236
    property color accentColor: "#ffb08a"
    property string displayStyle: "glass"
    property bool highContrast: false
    property bool reducedMotion: false

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: (tokens.ui && tokens.ui.mode === "light") ? "#fffdf7" : "#261b33"
        border.width: 1.5
        border.color: accentColor
        Text {
            anchors.centerIn: parent
            text: card.title || ""
            color: (tokens.color && tokens.color.palette) ? tokens.color.palette["on-surface"] : "#fff5ee"
        }
    }
}
```

完整示例见 `plugins/aurora-glass/components/PopupCard.qml`。

### WaxSeal 契约

```qml
Item {
    property color sealColor: "#b3393f"
    property color sealHighlight: "#d9575c"
    property real pressScale: 0.94
    signal activated()
    // 自己 96px 以上的点击热区；点击后 emit activated()
}
```

宿主会在收到 `activated()` 后执行原有的碎裂/开信流程；插件只负责视觉与点击。

### Background 契约

```qml
Item {
    property var tokens: ({})
    property string variant: "paper"   // paper | cake
    property bool reducedMotion: false
    property bool highContrast: false
}
```

### FinaleFX 契约

```qml
Item {
    property var config: ({})          // 与 profile.acts.finale.confetti 同构
    property bool reducedMotion: false
    property bool active: false
}
```

内置 `ConfettiCanvas` 的 `config` 字段可全部复用。

### CakeDecor 契约

2D 叠加层（不是 3D 模型）。适合星光、花瓣、彩纸、光晕；不要拦截鼠标。

### DissolveEffect 契约

叠加在宿主消融之上的装饰层；宿主仍负责真正的遮罩与纸面冻结。可根据 `progress` 绘制燃烧边、光晕、粒子。

## 4. 健康红线 lint

插件与本体使用同一套规则：

- 闪烁 ≤3 次/秒，单次亮度变化 <10%，禁止饱和红闪切与全屏白爆闪。
- 默认音量 ≤50%，常驻音频可控。
- 文字对比 4.5:1；一切可点目标 ≥24×24px。
- 导出前对插件动画参数与着色器参数执行相同 lint；不通过则阻止导出并给出可读错误。

## 5. 安装 / 启用 / 分发

- 编辑器「插件」页：安装（选择目录）→ 启用 → 写入当前配置档 → 预览立即生效。
- 插件状态保存在 `%APPDATA%/BirthdayStudio/settings.json` 的 `plugins.enabled`。
- 卸载只允许已安装插件；内置示例插件不可卸载。
- 导出包会复制所有启用插件的目录到 `plugins/`，并把 id 写入 `profile.json` 的 `plugins` 字段。
- 仓库不收录第三方插件；README 提供生态入口。

## 6. 版本演进

- Slot 组件签名在 1.x 内**向后兼容**：只能新增可选属性，不能修改/删除既有属性；必须破坏时升 major。
- 宿主按 manifest 的 `host` 区间拒绝不兼容插件，并提示所需/当前版本。
- `apiVersion` 变化代表槽位机制本身不兼容。
