# 配置档 Schema（`profile.json`）

> 权威定义在 `app/config/schema.py`（Pydantic v2）。本文件是给创作者与插件作者的字段速查；两者冲突时以代码为准。

## 1. 存储布局

```
%APPDATA%/BirthdayStudio/profiles/<profile-id>/
  profile.json      # 唯一数据源
  meta.json         # 精简元数据镜像（列表加速）
  assets/           # 媒体资源（按 sha256 内容去重）
  snapshots/        # snap-YYYYMMDD-HHMMSS.json，滚动保留 10 份
  preview.png       # 卡片缩略图
  journal.jsonl     # 崩溃检测日志
```

`.bbp` 是去掉 journal/snapshots 的 zip 包；导入时若 id 冲突会自动加后缀。

## 2. 顶层

```jsonc
{
  "schema_version": 1,
  "id": "12 位十六进制",
  "meta": { ... },
  "global": { ... },          // Python 字段名 global_，JSON 键为 global
  "acts": { ... },
  "assets": [ ... ],
  "token_overrides": { ... }, // 设计令牌 delta
  "plugins": ["aurora-glass"] // 导出时内嵌
}
```

### meta

| 字段 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `name` | str 1..80 | 未命名祝福 | 配置档显示名 |
| `honoree` | str 1..40 | 你 | 寿星名，支持 `{honoree}` 占位符 |
| `author` | str ≤80 | SrQingChen | 作者 |
| `theme` | str | glass-celebration | 主题 id（`resources/themes/` 或插件） |
| `description` | str ≤500 | "" | 编辑器内描述 |
| `created_at` / `modified_at` | ISO str | now | 时间戳 |
| `cover` | str | "" | 预留封面 |

## 3. global

```jsonc
"global": {
  "audio": {
    "master_volume_pct": 50,          // 0..100，>50 会产生警告
    "bgm": { "path": "audio/bgm_celebration.wav", "volume_pct": 50, "loop": true,
             "fade_in_ms": 600, "fade_out_ms": 800 },
    "sfx_volume_pct": 60,
    "ducking_enabled": true
  },
  "motion": { "reduced_motion": "auto", "speed_scale": 1.0 },   // auto|on|off；0.25..2
  "environment": { "mode": "dark", "ambient_brightness": 1.0 }, // dark|light|auto
  "accessibility": { "high_contrast": false, "reduced_transparency": false,
                     "always_show_audio_bar": true },
  "skip": { "enabled": true, "show_button": true },
  "stage": { "aspect": "16:9", "background": "theme",
             "background_color": "#140c1a", "vignette": true }
}
```

资源路径规则：`assets/...` → 配置档目录；`audio/...`、`textures/...` → 内置资源；绝对路径直接使用。

## 4. acts

七个幕固定顺序：`intro → wax → popups → confirm → dissolve → cake → finale`。每幕都继承：

| 字段 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `enabled` | bool | true | 关闭后该幕被跳过 |
| `enter` | `after-prev` / `on-tap` / `auto:<ms>` / `user-advance` | after-prev | 进入条件 |
| `exit` | `on-tap:<target>` / `auto:<ms>` / `auto:candles` / `user-advance` | on-tap | 退出条件 |
| `skippable` | bool | true | 是否允许全局跳过 |

### intro（幕 1 · 开场）

| 字段 | 类型 | 默认 |
|---|---|---|
| `hint` | str | 轻触信封，开启祝福 |
| `hint_size` | int 14..44 | 22 |
| `hint_color` | hex / "" | ""（跟随主题） |
| `envelope.paper_color` | hex | #f3e7d6 |
| `envelope.flap_color` | hex | #e8d8c3 |
| `envelope.seal_color` / `seal_highlight` | hex | #b3393f / #d9575c |
| `envelope.ribbon_color` / `thread_color` | hex | #e9c46a / #7a2a2f |
| `envelope_scale` | 0.6..1.4 | 1.0 |
| `gate` | bool | true（1.1.0 起：暗色幕布 + 开启按钮，点击后才亮出信封；false 还原 1.0 行为） |
| `gate_text` | str ≤16 | 开启这份祝福 |
| `gate_subtext` | str ≤30 | 一份心意，正在等你点开 |

### wax（幕 2 · 火漆与信纸）

| 字段 | 类型 | 默认 |
|---|---|---|
| `letter_mode` | `animated` / `none` | animated |
| `press_scale` | 0.88..0.99 | 0.94 |
| `crack_ms` | 100..800 | 260 |
| `letter.paper_color` / `ink_color` / `accent_color` | hex | 见默认 |
| `letter.font_family` | `han` / `hanSerif` | hanSerif |
| `letter.font_size_px` | 12..36 | 21 |
| `letter.line_height` | 1.2..2.2 | 1.75 |
| `letter.text` | str | 默认祝福信，支持 `{honoree}` `{author}` |
| `letter.presentation` | `static` / `typewriter` / `lines` | typewriter |
| `letter.chars_per_second` | 6..60 | 24 |
| `letter.line_stagger_ms` | 60..2000 | 450 |
| `letter.advance` | `auto` / `click` | click |

### popups（幕 3 · 轨迹弹窗）

```jsonc
"trajectory": {
  "preset": "heart",            // heart|circle|wave|diagonal|arc|spiral|custom
  "custom_points": [[x,y], ...],// 0..1 归一化
  "duration_ms": 1600, "easing": "outCubic", "span": 0.72
},
"sequence": {
  "stagger_ms": 60, "start_delay_ms": 260,
  "total_duration_override_ms": null,
  "max_living": 7,              // 1..12
  "lifetime_ms": 8000, "fade_ms": 220, "opacity_final": 0.0,
  "appear_from": "letter",      // letter|trajectory|center
  "size_vary_pct": 6, "hold_after_ms": 3800, "float_amplitude": 6
},
"color_strategy": {
  "mode": "harmony",            // harmony|palette|single
  "harmony": "analogous",       // analogous|triadic|complementary
  "base_hue": 14,
  "saturation_bucket": [0.45, 0.70],
  "lightness_bucket": [0.62, 0.78],
  "palette": [], "single_color": "#ffb08a"
},
"swarm": {                       // 1.1.0 起：蜂群便签（沿轨迹连成曲线）
  "enabled": true,
  "count": 320,                  // 40..400 硬上限
  "note_size": 44,               // 20..90 px，便签宽度
  "note_aspect": "1:1",          // 1:1|4:3|3:4|16:9，所有便签统一比例
  "overlap_pct": 90,             // 50..98，相邻便签重叠度
  "stagger_ms": 14,              // 4..60，低动效模式自动放缓到 ≥30
  "fade_in_ms": 120,             // 40..600
  "jitter_px": 6,                // 0..30，位置/旋转抖动去机器感
  "cards_delay_after": true,     // 曲线成形后可读卡再出场
  "text_block": "生日快乐
愿你快乐
岁岁平安
心想事成",  // 便签文字，每行一条，沿曲线循环
  "text_size": 11,               // 6..22 px
  "text_every": 6                // 1..40：每隔几枚便签显示下一条文字
},
"style": "glass",               // glass|cartoon
"cards_enabled": true,          // false：蜂群之后不再飞入可读卡
"cards_limit": 0,               // 0=全部；1..24=只播放列表前 N 只
"auto_advance": true,           // false：播放完停留，轻触画面继续
"cards": [
  { "title": "...", "body": "...", "emoji": "✨",
    "width": 400, "height": 236, "accent": "", "style": "", "image": "" }
]
```

- 卡片宽 240..640，高 140..480；最多 24 只。
- `total_duration_override_ms` 非空时，stagger 由总时长反算。
- 同屏存活上限 12 是硬上限；超过 7 会给认知负荷警告。
- 蜂群便签是轨迹描线特效（与终幕 confetti 同级），不占用「同屏玻璃卡」预算；`count ≤ 400` 为硬上限。
- 蜂群会把轨迹自动收缩到刚好画满整条曲线（相邻步长 = `min(便签宽, 便签高) × (1 − overlap_pct/100)`），所以心形带总在内侧、可读卡环在外侧。`note_aspect` 决定便签高 = 宽 ÷ 比例，整条带共用同一个形状。
- 蜂群颜色由独立的**糖果淡彩（candy pastel）**机制生成，不再继承可读卡色板：色相只在粉红/兰紫/长春花蓝/粉蓝/薄荷等锚点之间平滑行走，整体固定在 PCCS pale/light 淡色调（HSL 明度约 0.82–0.86、彩度 0.6–0.87），因此不会出现棕、灰、橄榄等低明度/低彩度色块（跨文化颜色偏好研究中排名最低的一段）。`base_hue` 选择色族（暖=粉→蓝、春=薄荷→粉、天=粉蓝→粉、紫=丁香→粉），`harmony` 选择跨度（邻近=单一色族 5–6 段、三角=粉/杏/柠檬/薄荷/蓝/紫、互补=粉蓝交替）。色带仍以轨迹垂直轴镜像，相邻便签色差 <3°，左右两瓣同色。`mode=single` 仍按指定单色渲染；`mode=palette` 只影响可读卡，不参与蜂群（若把自定义色板直接传给 `swarmRamp`，每个颜色也会被拉回淡彩带）。主题的 `tertiary` 作为约 4% 的强调色点缀（60/30/10 的 10% 原则），同样会被压回淡彩带。
- 可读卡在窗口小于设计基准时会自动等比缩小，保留 ≥18px 的间距（含浮动幅度），避免窄屏/小窗口上相邻祝福卡重叠；大屏保持原尺寸。
- `cards_limit` 只截取列表前缀，不会删除后面的卡片；`cards_enabled=false` 时列表仍会保存，随时可以重新打开。
- `sequence.hold_after_ms` 只在 `auto_advance=true` 时生效；手动模式下播放完会停住，等待轻触（或空格 / 全局跳过键）。

### confirm（幕 4 · 收下祝福）

`text`、`subtext`、`style`（glass|cartoon）、`width` 320..820（默认 560）、`height` 160..480（默认 280）、`press_scale` 0.90..0.99（默认 0.96）。

### dissolve（幕 5 · 中心消融）

`duration_ms` 300..900（默认 560）、`noise_scale` 4..80、`edge_glow` 0..1。

实现：把纸面世界冻结为纹理，用 Qt Quick `MultiEffect` 的遮罩阈值从中心向外揭开 3D；低动效模式退化为透明度溶解。

### cake（幕 6 · 蛋糕与许愿）

```jsonc
"camera": { "pitch": 26, "yaw": -16, "distance": 980 },
"cake": {
  "layers": [ { "radius": 200, "height": 92, "color": "#f6d3c3",
                "frosting": "#fff4ec", "roughness": 0.62 } ],   // 1..5 层
  "plate_color": "#e9e2d6", "roughness": 0.55, "metalness": 0.02,
  "decorations": ["namePlague", "fruit", "piping", "sprinkles"]
},
"candles": {
  "count": 5, "arrangement": "arc",     // arc|circle|line
  "spacing": 36, "height": 54, "radius": 6,
  "colors": ["#f2a7b8", ...],           // 循环取色
  "flame_intensity": 1.0,
  "mic_enabled": false, "mic_threshold": 0.22
},
"wish": { "darken_ms": 520, "silence_ms": 2400,
          "reveal_text": "生日快乐", "reveal_duration_ms": 900 },
"jelly": { "spring": 4.2, "damping": 0.42 },
"hint": "点亮蜡烛后，逐根点击吹灭",
"interaction_hint": "拖动可旋转蛋糕 · 点击蛋糕会弹起来"   // ≤40 字；留空隐藏
```

相机由 pitch（俯仰）与 distance 决定；蛋糕层从下到上排布，半径/高度单位是 QML 3D 世界单位。

1.1.0 起：拖动可自由旋转蛋糕（±180° 回绕、带惯性、不自动回正）；点击蛋糕触发果冻弹跳，动画期间再点会叠加能量。`jelly.spring` / `jelly.damping` 映射到阻尼振子的 k/c。
1.1.1 起：**只保留水平旋转**，竖向拖动不再改变俯仰角；便签支持文字（`swarm.text_block`），弹窗与便签统一为高亮琉璃质感。

### finale（幕 7 · 终幕）

```jsonc
"headline": "生日快乐",
"subline": "{honoree} · 今天的主角",
"confetti": {
  "bursts": 3,                    // 1..3
  "particles_per_burst": 110,
  "colors": ["#ff8fab", ...],
  "gravity": 900, "drag": 0.992,
  "origin_x": 0.5, "origin_y": 0.58,
  "spread": 68, "max_particles": 420
},
"buttons": { "replay": "再看一次", "close": "合上贺卡" }
```

## 5. assets

```jsonc
{ "id": "sha16", "kind": "audio|image|video|font|other",
  "filename": "9f2c1a3b4c_bgm.wav", "sha256": "...",
  "license": "unknown|CC0|OFL|自有|...", "source": "原文件名" }
```

导入时自动按内容 hash 去重；`license` 会汇总进导出确认清单。

## 6. schema_version 与迁移

- 当前版本：`1`。
- 加载时经过 `app/config/migrations.py`；高于当前版本会给出可读错误。
- 没有版本号的旧 V0.1 `theme.json` 会尽力迁移（music/letter/popups/cake）。
- 导出前会强制跑完整 Pydantic 校验；错误阻止导出，警告放行。

## 7. 主题模板与令牌

主题 = **出厂 profile 模板**（`resources/themes/<id>/template.json`）+ **设计令牌 delta**（`tokens.json`）。

- 新配置档 = schema 默认值 deep-merge 主题模板。
- 令牌解析顺序：`design-tokens.json` → 主题 tokens → 已启用插件 tokens → `profile.token_overrides`。
- 切换主题时，编辑器默认只替换 `meta.theme`（保留用户内容）；勾选「套用主题默认配色」才会用模板覆盖信封/蛋糕/彩带等配色。
