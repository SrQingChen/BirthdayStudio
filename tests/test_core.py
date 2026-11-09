"""Core contract / storage / validation tests (stdlib unittest, no GUI)."""

from __future__ import annotations

import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path

HOME = tempfile.mkdtemp(prefix="birthday-studio-tests-")
os.environ["BIRTHDAY_STUDIO_HOME"] = HOME

from app.config import defaults  # noqa: E402
from app.config.migrations import migrate  # noqa: E402
from app.config.schema import AssetRef, Profile  # noqa: E402
from app.core import colors  # noqa: E402
from app.core.exporter import ExportOptions, Exporter  # noqa: E402
from app.core.plugin_manager import PluginManager, version_in_range  # noqa: E402
from app.core.profile_store import ProfileStore  # noqa: E402
from app.core.validator import validate_profile  # noqa: E402


class SchemaTests(unittest.TestCase):
    def test_themes_are_factory_templates(self):
        themes = defaults.list_themes()
        self.assertGreaterEqual(len(themes), 2)
        self.assertEqual(themes[0]["id"], "glass-celebration")
        for theme in themes:
            profile = defaults.create_profile(theme_id=theme["id"], honoree="测试")
            self.assertEqual(profile.meta.theme, theme["id"])
            self.assertEqual(len(profile.acts.popups.cards), 5)
            self.assertEqual(len(profile.acts.cake.cake.layers), 3)

    def test_v1_1_0_new_fields_defaults(self):
        profile = defaults.create_profile()
        # swarm (fix #5): on by default, bounded counts
        self.assertTrue(profile.acts.popups.swarm.enabled)
        self.assertEqual(profile.acts.popups.swarm.count, 320)
        self.assertTrue(profile.acts.popups.swarm.cards_delay_after)

    def test_voice_defaults(self):
        voice = defaults.create_profile().global_.audio.voice
        self.assertEqual(voice.path, "")
        self.assertEqual(voice.volume_pct, 85)

    def test_cartoon_theme_uses_warm_analogous_harmony(self):
        # The old triadic set (orange/green/blue-violet) fought the cream
        # stage; the factory template is warm-analogous with a teal accent.
        profile = defaults.create_profile(theme_id="cartoon-3d", honoree="测试")
        cs = profile.acts.popups.color_strategy
        self.assertEqual(cs.mode, "harmony")
        self.assertEqual(cs.harmony, "analogous")
        self.assertLessEqual(cs.base_hue, 30)
        self.assertLessEqual(cs.saturation_bucket[1], 0.70)
        # cake interaction hint (fix #4)
        self.assertEqual(profile.acts.cake.interaction_hint, "拖动可旋转蛋糕 · 点击蛋糕会弹起来")
        # intro gate (fix #6): on by default
        self.assertTrue(profile.acts.intro.gate)
        self.assertEqual(profile.acts.intro.gate_text, "开启这份祝福")
        # existing profiles pick the new defaults via schema validation
        data = profile.dump()
        loaded = Profile.model_validate(data)
        self.assertTrue(loaded.acts.popups.swarm.enabled)

    def test_v1_1_2_popup_layer_controls(self):
        profile = defaults.create_profile()
        popups = profile.acts.popups
        # one shared aspect ratio for every swarm note
        self.assertEqual(popups.swarm.note_aspect, "1:1")
        # readable cards have their own switch + visible-count cap
        self.assertTrue(popups.cards_enabled)
        self.assertEqual(popups.cards_limit, 0)
        # auto-advance is independent from the card sequence
        self.assertTrue(popups.auto_advance)

        data = profile.dump()
        data["acts"]["popups"]["swarm"]["note_aspect"] = "2:1"
        with self.assertRaises(Exception):
            Profile.model_validate(data)
        data["acts"]["popups"]["swarm"]["note_aspect"] = "4:3"
        data["acts"]["popups"]["cards_limit"] = 25
        with self.assertRaises(Exception):
            Profile.model_validate(data)
        data["acts"]["popups"]["cards_limit"] = 24
        data["acts"]["popups"]["auto_advance"] = False
        Profile.model_validate(data)

    def test_popups_empty_stage_is_reported(self):
        profile = defaults.create_profile()
        data = profile.dump()
        data["acts"]["popups"]["cards_enabled"] = False
        data["acts"]["popups"]["swarm"]["enabled"] = False
        report = validate_profile(data)
        self.assertTrue(any(i.path == "acts.popups" and i.severity == "warning" for i in report.issues))
        data["acts"]["popups"]["cards_enabled"] = True
        report = validate_profile(data)
        self.assertFalse(any(i.path == "acts.popups" for i in report.issues))

    def test_swarm_bounds(self):
        profile = defaults.create_profile()
        data = profile.dump()
        data["acts"]["popups"]["swarm"]["count"] = 401
        with self.assertRaises(Exception):
            Profile.model_validate(data)
        data["acts"]["popups"]["swarm"]["count"] = 400
        data["acts"]["popups"]["swarm"]["overlap_pct"] = 99
        with self.assertRaises(Exception):
            Profile.model_validate(data)
        data["acts"]["popups"]["swarm"]["overlap_pct"] = 98
        data["acts"]["cake"]["interaction_hint"] = "x" * 41
        with self.assertRaises(Exception):
            Profile.model_validate(data)
        data["acts"]["cake"]["interaction_hint"] = "x" * 40
        data["acts"]["intro"]["gate_text"] = "x" * 17
        with self.assertRaises(Exception):
            Profile.model_validate(data)
        data["acts"]["intro"]["gate_text"] = "x" * 16
        Profile.model_validate(data)

    def test_invalid_values_are_rejected(self):
        profile = defaults.create_profile()
        data = profile.dump()
        data["acts"]["popups"]["sequence"]["max_living"] = 99
        with self.assertRaises(Exception):
            Profile.model_validate(data)

    def test_legacy_v0_migrates(self):
        legacy = {
            "name": "旧主题",
            "music": {"path": "assets/a.wav", "volume": 0.4},
            "letter": {"text": "旧信"},
            "popups": [{"title": "A", "body": "B"}],
            "cake": {"candles": 7},
        }
        data = migrate(legacy)
        self.assertEqual(data["schema_version"], 1)
        profile = Profile.model_validate(data)
        self.assertEqual(profile.acts.wax.letter.text, "旧信")
        self.assertEqual(profile.acts.cake.candles.count, 7)

    def test_semver_gate(self):
        self.assertTrue(version_in_range((1, 0, 0), ">=1.0.0 <2.0.0"))
        self.assertFalse(version_in_range((2, 0, 0), ">=1.0.0 <2.0.0"))


class StoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.store = ProfileStore()

    def test_lifecycle(self):
        store = self.store
        profile = store.create(theme_id="glass-celebration", honoree="小雨", name="测试配置档")
        self.assertTrue(store.exists(profile.id))
        self.assertIn(profile.id, [p["id"] for p in store.list()])

        profile.acts.popups.sequence.stagger_ms = 80
        store.save(profile)
        loaded, _ = store.load(profile.id)
        self.assertEqual(loaded.acts.popups.sequence.stagger_ms, 80)

        snapshots = store.snapshots(profile.id)
        self.assertGreaterEqual(len(snapshots), 1)
        restored = store.restore_snapshot(profile.id, snapshots[0]["file"])
        self.assertEqual(restored.id, profile.id)

        copy = store.duplicate(profile.id)
        self.assertNotEqual(copy.id, profile.id)
        self.assertTrue(copy.meta.name.endswith("副本"))

        bbp = store.export_bbp(profile.id, Path(HOME) / "test.bbp")
        self.assertTrue(bbp.exists())
        imported = store.import_bbp(bbp)
        self.assertNotEqual(imported.id, profile.id)

        store.delete(copy.id)
        self.assertFalse(store.exists(copy.id))
        trashed = store.trashed()
        self.assertTrue(any(t["id"] == copy.id for t in trashed))
        store.restore_trash(next(t["trashDir"] for t in trashed if t["id"] == copy.id))
        self.assertTrue(store.exists(copy.id))

    def test_crash_journal(self):
        store = self.store
        profile = store.create(theme_id="cartoon-3d", honoree="小满", name="崩溃测试")
        store.journal(profile.id, "open")
        unclean = [p["id"] for p in store.unclean_profiles()]
        self.assertIn(profile.id, unclean)
        store.resolve_crash(profile.id, "resume")
        unclean = [p["id"] for p in store.unclean_profiles()]
        self.assertNotIn(profile.id, unclean)


class ValidationTests(unittest.TestCase):
    def test_default_profiles_pass(self):
        for theme in defaults.list_themes():
            report = validate_profile(defaults.create_profile(theme_id=theme["id"]).dump())
            self.assertTrue(report.ok, [i.message for i in report.errors])

    def test_contrast_and_audio_lint(self):
        profile = defaults.create_profile()
        data = profile.dump()
        data["acts"]["wax"]["letter"]["ink_color"] = "#fffdf5"
        report = validate_profile(data)
        self.assertFalse(report.ok)
        self.assertTrue(any(i.code == "contrast" for i in report.errors))

        data = profile.dump()
        data["global"]["audio"]["master_volume_pct"] = 90
        report = validate_profile(data)
        self.assertTrue(any(i.code == "audio.volume" for i in report.warnings))

    def test_missing_voice_is_an_error(self):
        data = defaults.create_profile().dump()
        self.assertTrue(validate_profile(data).ok)

        data["global"]["audio"]["voice"]["path"] = "assets/missing_voice.wav"
        report = validate_profile(data)
        self.assertFalse(report.ok)
        voice_errors = [i for i in report.errors if i.path == "global.audio.voice.path"]
        self.assertEqual(len(voice_errors), 1)
        self.assertEqual(voice_errors[0].code, "asset.missing")


class ColorTests(unittest.TestCase):
    def test_swarm_ramp_is_pastel_pink_to_blue(self):
        accent = "#7fd8c8"
        out = colors.swarm_palette(20, "analogous", 320, [], accent, 24)
        self.assertEqual(len(out), 320)
        # The ribbon steps by <2° between neighbours; the occasional teal
        # accent is a deliberate exception, not a competing field.
        hues = [colors.hex_to_hsl(c)[0] for c in out]
        accented = {i for i, _ in enumerate(out) if i % 24 == 12}
        deltas = []
        for i in range(len(out) - 1):
            if i in accented or i + 1 in accented:
                continue
            deltas.append(abs((hues[i + 1] - hues[i] + 180) % 360 - 180))
        self.assertLess(max(deltas), 3.0)
        self.assertEqual(len(accented), 13)
        self.assertEqual(len({out[i] for i in accented}), 1)

        # Every chip sits in the pale candy band: no brown (dark orange) and
        # no grey (low chroma) can survive.
        tones = [colors.hex_to_hsl(c) for c in out]
        self.assertGreaterEqual(min(l for _, _, l in tones), 0.72)
        self.assertGreaterEqual(min(s for _, s, _ in tones), 0.40)

        # Pink and powder blue both appear in meaningful shares — the point of
        # the candy mechanism.
        pink = sum(1 for h, _, _ in tones if h >= 315 or h <= 15)
        blue = sum(1 for h, _, _ in tones if 190 <= h <= 225)
        self.assertGreater(pink, 80)
        self.assertGreater(blue, 30)

    def test_every_ribbon_family_stays_in_candy_land(self):
        for base in (20, 100, 200, 290):
            for mode in ("analogous", "triadic", "complementary"):
                out = colors.swarm_palette(base, mode, 96, [], "", 0)
                tones = [colors.hex_to_hsl(c) for c in out]
                self.assertGreaterEqual(min(l for _, _, l in tones), 0.72)
                self.assertGreaterEqual(min(s for _, s, _ in tones), 0.40)
                self.assertTrue(
                    any(h >= 315 or h <= 15 for h, _, _ in tones), (base, mode)
                )
                self.assertTrue(any(190 <= h <= 225 for h, _, _ in tones), (base, mode))

    def test_custom_palette_is_revived_into_the_candy_band(self):
        palette = ["#ff8a6b", "#ffd166", "#7fd8c8"]
        out = colors.swarm_palette(20, "analogous", 120, palette, "", 0)
        self.assertEqual(len(out), 120)
        self.assertGreater(len(set(out)), 40)
        for color in out:
            _, s, l = colors.hex_to_hsl(color)
            self.assertGreaterEqual(l, 0.72)
            self.assertGreaterEqual(s, 0.40)
        # Muddy inputs (dark brown + neutral grey) are lifted out of the mud.
        muddy = colors.swarm_palette(20, "analogous", 40, ["#6b4a2f", "#8a8a8a"], "", 0)
        self.assertGreaterEqual(min(colors.hex_to_hsl(c)[2] for c in muddy), 0.72)
        # A single colour is an explicit monochrome choice and stays verbatim.
        single = colors.swarm_palette(20, "analogous", 8, ["#ff8a6b"], "", 0)
        self.assertEqual(set(single), {"#ff8a6b"})


class ExporterTests(unittest.TestCase):
    def test_package_contains_licenses_and_profile(self):
        store = ProfileStore()
        profile = store.create(theme_id="glass-celebration", honoree="导出", name="导出测试")
        pm = PluginManager([])
        pm.scan()
        exporter = Exporter(store, pm)
        result = exporter.export(
            profile,
            Path(HOME) / "export",
            ExportOptions(exe_name="测试导出", copyright_confirmed=True),
        )
        self.assertTrue(result["ok"])
        package = Path(result["packageDir"])
        self.assertTrue((package / "profile" / "profile.json").exists())
        self.assertTrue((package / "LICENSES" / "SOURCE.txt").exists())
        self.assertTrue((package / "启动演出.bat").exists())
        self.assertTrue(Path(result["zipPath"]).exists())

    def test_voice_asset_is_packaged(self):
        store = ProfileStore()
        profile = store.create(theme_id="glass-celebration", honoree="语音", name="语音导出")
        source = Path(__file__).resolve().parents[1] / "resources" / "audio" / "sfx_chime.wav"
        asset = store.import_asset(profile.id, source, kind="audio", license_type="CC0")
        profile.assets.append(AssetRef(**asset))
        profile.global_.audio.voice.path = f"assets/{asset['filename']}"
        store.save(profile)

        pm = PluginManager([])
        pm.scan()
        exporter = Exporter(store, pm)
        result = exporter.export(
            profile,
            Path(HOME) / "export_voice",
            ExportOptions(exe_name="语音导出", copyright_confirmed=True),
        )
        self.assertTrue(result["ok"])
        package = Path(result["packageDir"])
        self.assertTrue((package / "profile" / "assets" / asset["filename"]).exists())


def tearDownModule():
    shutil.rmtree(HOME, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
