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
from app.config.schema import Profile  # noqa: E402
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


def tearDownModule():
    shutil.rmtree(HOME, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
