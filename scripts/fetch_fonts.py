"""Download OFL Chinese fonts into resources/fonts/ (optional, offline builds).

The app already falls back to system Chinese fonts.  Bundling these makes the
player safe on machines without a CJK font installed.  Fonts remain under
SIL OFL 1.1; see resources/fonts/OFL.txt.
"""

from __future__ import annotations

import sys
import urllib.request
from pathlib import Path

FONTS = {
    "NotoSansSC[wght].ttf": "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf",
    "NotoSerifSC[wght].ttf": "https://raw.githubusercontent.com/google/fonts/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf",
}
OFL = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt"


def download(url: str, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    print(f"→ {target.name}")
    with urllib.request.urlopen(url, timeout=60) as resp, open(target, "wb") as out:
        out.write(resp.read())
    print(f"  {target.stat().st_size / 1024 / 1024:.1f} MiB")


def main() -> int:
    root = Path(__file__).resolve().parent.parent / "resources" / "fonts"
    try:
        for name, url in FONTS.items():
            download(url, root / name)
        download(OFL, root / "OFL.txt")
    except Exception as exc:  # noqa: BLE001
        print(f"下载失败：{exc}\n可以手动放入 resources/fonts/；应用会自动回退系统字体。")
        return 1
    print("完成。重新启动应用即可自动注册。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
