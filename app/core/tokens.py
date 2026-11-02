"""Design-token resolution: base tokens + theme delta + plugin deltas + profile overrides."""

from __future__ import annotations

import copy
import json
from typing import Any

from ..config.defaults import deep_merge, load_theme_tokens
from .paths import TOKENS_PATH


def load_base_tokens() -> dict[str, Any]:
    with open(TOKENS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


class TokenResolver:
    def __init__(self) -> None:
        self._base = load_base_tokens()

    @property
    def base(self) -> dict[str, Any]:
        return copy.deepcopy(self._base)

    def resolve(
        self,
        theme_id: str,
        plugin_deltas: list[dict[str, Any]] | None = None,
        overrides: dict[str, Any] | None = None,
        *,
        high_contrast: bool = False,
        reduced_transparency: bool = False,
    ) -> dict[str, Any]:
        tokens = self.base
        theme_tokens = load_theme_tokens(theme_id)
        if theme_tokens:
            tokens = deep_merge(tokens, theme_tokens)
        for delta in plugin_deltas or []:
            if isinstance(delta, dict):
                tokens = deep_merge(tokens, delta)
        if overrides:
            tokens = deep_merge(tokens, overrides)
        if reduced_transparency or high_contrast:
            tokens = self._opaque(tokens, high_contrast)
        return tokens

    @staticmethod
    def _opaque(tokens: dict[str, Any], high_contrast: bool) -> dict[str, Any]:
        t = copy.deepcopy(tokens)
        glass = t.setdefault("glass", {})
        glass["tintAlpha"] = [0.94, 0.98]
        glass["cardTintAlpha"] = 0.97
        glass["borderAlpha"] = [0.85, 1.0]
        glass["noiseOpacity"] = 0.0
        glass["fallbackActive"] = True
        if high_contrast:
            glass["borderPx"] = [2, 2]
            elev = t.setdefault("elevation", {})
            for key in ("card", "flyout", "dialog"):
                if key in elev:
                    elev[key]["alpha"] = 0.0
            t.setdefault("focus", {})["ringWidthPx"] = 3
        return t

    def palette(self, tokens: dict[str, Any]) -> dict[str, str]:
        return dict(tokens.get("color", {}).get("palette", {}))

    def fonts(self, tokens: dict[str, Any]) -> dict[str, list[str]]:
        stack = tokens.get("type", {}).get("stack", {})
        return {
            "han": list(stack.get("han", [])),
            "hanSerif": list(stack.get("hanSerif", [])),
            "latin": list(stack.get("latin", [])),
        }
