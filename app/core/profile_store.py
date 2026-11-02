"""Profile library: lifecycle, atomic autosave, snapshots, journal, trash, .bbp."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import time
import uuid
import zipfile
from pathlib import Path
from typing import Any

from ..config import defaults
from ..config.io import (
    atomic_write_bytes,
    atomic_write_json,
    load_profile_json,
    read_json,
)
from ..config.schema import SCHEMA_VERSION, Profile, now_iso
from .paths import FONTS_DIR, PROFILES_DIR, TRASH_DIR, ensure_home
from .tokens import TokenResolver

TRASH_RETENTION_DAYS = 30
SNAPSHOT_INTERVAL_SECONDS = 300
SNAPSHOT_KEEP = 10


def _tail_event(path: Path) -> str | None:
    """Last journal event, reading the file from the end efficiently."""
    if not path.exists():
        return None
    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            chunk = min(size, 8192)
            f.seek(size - chunk)
            data = f.read().decode("utf-8", errors="replace")
        lines = [ln for ln in data.splitlines() if ln.strip()]
        if not lines:
            return None
        return json.loads(lines[-1]).get("event")
    except (OSError, json.JSONDecodeError):
        return None


class ProfileStore:
    def __init__(self, root: Path | None = None, trash_root: Path | None = None) -> None:
        self.root = root or PROFILES_DIR
        self.trash_root = trash_root or TRASH_DIR
        ensure_home()
        self.root.mkdir(parents=True, exist_ok=True)
        self.trash_root.mkdir(parents=True, exist_ok=True)
        self.tokens = TokenResolver()

    # ------------------------------------------------------------------ #
    # Paths & summaries
    # ------------------------------------------------------------------ #
    def dir_of(self, profile_id: str) -> Path:
        return self.root / profile_id

    def exists(self, profile_id: str) -> bool:
        return (self.dir_of(profile_id) / "profile.json").exists()

    def list(self) -> list[dict[str, Any]]:
        from ..config.defaults import list_themes

        theme_names = {t["id"]: t["name"] for t in list_themes()}
        out: list[dict[str, Any]] = []
        if not self.root.exists():
            return out
        for d in sorted(self.root.iterdir(), key=lambda p: p.name):
            if not d.is_dir():
                continue
            p = d / "profile.json"
            if not p.exists():
                continue
            try:
                raw = read_json(p)
                meta = raw.get("meta", {})
                preview = d / "preview.png"
                out.append(
                    {
                        "id": raw.get("id", d.name),
                        "name": meta.get("name", d.name),
                        "honoree": meta.get("honoree", ""),
                        "author": meta.get("author", ""),
                        "theme": meta.get("theme", ""),
                        "themeName": theme_names.get(meta.get("theme", ""), meta.get("theme", "")),
                        "description": meta.get("description", ""),
                        "modifiedAt": meta.get("modified_at", ""),
                        "createdAt": meta.get("created_at", ""),
                        "dir": str(d),
                        "previewUrl": preview.as_uri() if preview.exists() else "",
                        "sizeBytes": sum(f.stat().st_size for f in d.rglob("*") if f.is_file()),
                    }
                )
            except (OSError, ValueError, json.JSONDecodeError):
                out.append(
                    {
                        "id": d.name,
                        "name": f"⚠ 损坏的配置档（{d.name}）",
                        "honoree": "",
                        "theme": "",
                        "themeName": "",
                        "modifiedAt": "",
                        "dir": str(d),
                        "previewUrl": "",
                        "broken": True,
                        "sizeBytes": 0,
                    }
                )
        out.sort(key=lambda x: x.get("modifiedAt", ""), reverse=True)
        return out

    # ------------------------------------------------------------------ #
    # Create / load / save
    # ------------------------------------------------------------------ #
    def create(
        self,
        *,
        theme_id: str = "glass-celebration",
        name: str = "",
        honoree: str = "你",
        author: str = "SrQingChen",
    ) -> Profile:
        profile = defaults.create_profile(
            theme_id=theme_id, name=name, honoree=honoree, author=author
        )
        directory = self.dir_of(profile.id)
        while directory.exists():
            profile.id = uuid.uuid4().hex[:12]
            directory = self.dir_of(profile.id)
        (directory / "assets").mkdir(parents=True, exist_ok=True)
        (directory / "snapshots").mkdir(parents=True, exist_ok=True)
        self.save(profile, reason="create", render_preview=True)
        self.journal(profile.id, "open")
        return profile

    def duplicate(self, profile_id: str, new_name: str | None = None) -> Profile:
        src = self.dir_of(profile_id)
        profile, raw = load_profile_json(src / "profile.json")
        new_id = uuid.uuid4().hex[:12]
        dst = self.dir_of(new_id)
        (dst / "assets").mkdir(parents=True, exist_ok=True)
        (dst / "snapshots").mkdir(parents=True, exist_ok=True)
        if (src / "assets").exists():
            shutil.copytree(src / "assets", dst / "assets", dirs_exist_ok=True)
        copy = json.loads(json.dumps(raw))
        copy["id"] = new_id
        copy["meta"]["name"] = new_name or f"{profile.meta.name} 副本"
        copy["meta"]["created_at"] = now_iso()
        copy["meta"]["modified_at"] = now_iso()
        new_profile = Profile.model_validate(copy)
        self.save(new_profile, reason="duplicate", render_preview=True)
        return new_profile

    def load(self, profile_id: str) -> tuple[Profile, dict[str, Any]]:
        directory = self.dir_of(profile_id)
        profile, raw = load_profile_json(directory / "profile.json")
        self.journal(profile_id, "open")
        return profile, raw

    def load_path(self, path: Path) -> tuple[Profile, dict[str, Any]]:
        profile, raw = load_profile_json(path)
        return profile, raw

    def save(
        self,
        profile: Profile | dict[str, Any],
        *,
        reason: str = "autosave",
        render_preview: bool = False,
    ) -> Profile:
        if isinstance(profile, dict):
            profile = Profile.model_validate(profile)
        directory = self.dir_of(profile.id)
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "assets").mkdir(exist_ok=True)
        (directory / "snapshots").mkdir(exist_ok=True)
        profile.touch()
        raw = profile.dump()
        atomic_write_json(directory / "profile.json", raw)
        atomic_write_json(directory / "meta.json", {"meta": raw.get("meta", {}), "schema_version": SCHEMA_VERSION})
        self.journal(profile.id, "save", reason)
        self._maybe_snapshot(profile)
        if render_preview or not (directory / "preview.png").exists():
            self.render_preview(profile)
        elif reason in {"create", "duplicate", "restore-snapshot"}:
            self.render_preview(profile)
        return profile

    def touch_preview(self, profile: Profile) -> None:
        self.render_preview(profile)

    def save_raw(self, profile_id: str, raw: dict[str, Any], *, reason: str = "autosave") -> None:
        """Persist a draft that may not satisfy the schema yet.

        The editor deliberately allows invalid intermediate values (yellow
        field + fallback preview); autosave must not lose them.  Export is
        gated separately and will refuse a profile with schema errors.
        """
        directory = self.dir_of(profile_id)
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "assets").mkdir(exist_ok=True)
        (directory / "snapshots").mkdir(exist_ok=True)
        raw = json.loads(json.dumps(raw))
        raw.setdefault("meta", {})["modified_at"] = now_iso()
        atomic_write_json(directory / "profile.json", raw)
        atomic_write_json(
            directory / "meta.json",
            {"meta": raw.get("meta", {}), "schema_version": raw.get("schema_version", SCHEMA_VERSION)},
        )
        self.journal(profile_id, "save", reason)

    # ------------------------------------------------------------------ #
    # Snapshots
    # ------------------------------------------------------------------ #
    def snapshot_dir(self, profile_id: str) -> Path:
        d = self.dir_of(profile_id) / "snapshots"
        d.mkdir(parents=True, exist_ok=True)
        return d

    def _maybe_snapshot(self, profile: Profile) -> None:
        sd = self.snapshot_dir(profile.id)
        snaps = sorted(sd.glob("snap-*.json"))
        last_time = 0.0
        if snaps:
            last_time = snaps[-1].stat().st_mtime
        if time.time() - last_time < SNAPSHOT_INTERVAL_SECONDS:
            return
        name = f"snap-{time.strftime('%Y%m%d-%H%M%S')}.json"
        atomic_write_json(sd / name, profile.dump())
        for old in sorted(sd.glob("snap-*.json"))[:-SNAPSHOT_KEEP]:
            try:
                old.unlink()
            except OSError:
                pass
        self.journal(profile.id, "snapshot", name)

    def snapshots(self, profile_id: str) -> list[dict[str, Any]]:
        out: list[dict[str, Any]] = []
        for p in sorted(self.snapshot_dir(profile_id).glob("snap-*.json"), reverse=True):
            try:
                raw = read_json(p)
                meta = raw.get("meta", {})
                out.append(
                    {
                        "file": p.name,
                        "path": str(p),
                        "time": p.stem.replace("snap-", ""),
                        "name": meta.get("name", ""),
                        "size": p.stat().st_size,
                        "summary": self._summarize(raw),
                    }
                )
            except (OSError, ValueError):
                continue
        return out

    @staticmethod
    def _summarize(raw: dict[str, Any]) -> str:
        acts = raw.get("acts", {})
        cards = len(acts.get("popups", {}).get("cards", []))
        honoree = raw.get("meta", {}).get("honoree", "")
        return f"{honoree} · {cards} 只弹窗 · {acts.get('cake', {}).get('candles', {}).get('count', '?')} 根蜡烛"

    def restore_snapshot(self, profile_id: str, snapshot_file: str) -> Profile:
        path = self.snapshot_dir(profile_id) / snapshot_file
        if not path.exists():
            raise FileNotFoundError(snapshot_file)
        raw = read_json(path)
        raw["id"] = profile_id
        raw["meta"]["modified_at"] = now_iso()
        profile = Profile.model_validate(raw)
        self.save(profile, reason="restore-snapshot", render_preview=True)
        self.journal(profile_id, "snapshot-restored", snapshot_file)
        return profile

    # ------------------------------------------------------------------ #
    # Journal / crash recovery
    # ------------------------------------------------------------------ #
    def journal_path(self, profile_id: str) -> Path:
        return self.dir_of(profile_id) / "journal.jsonl"

    def journal(self, profile_id: str, event: str, detail: str = "") -> None:
        p = self.journal_path(profile_id)
        p.parent.mkdir(parents=True, exist_ok=True)
        entry = {"t": now_iso(), "event": event, "detail": detail}
        with open(p, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
            f.flush()
            os.fsync(f.fileno())

    def unclean_profiles(self) -> list[dict[str, Any]]:
        out: list[dict[str, Any]] = []
        for item in self.list():
            if item.get("broken"):
                continue
            last = _tail_event(self.journal_path(item["id"]))
            if last not in (None, "close"):
                item["lastEvent"] = last
                out.append(item)
        return out

    def resolve_crash(self, profile_id: str, action: str, snapshot_file: str = "") -> Profile | None:
        """action: resume | snapshot | discard."""
        if action == "snapshot" and snapshot_file:
            profile = self.restore_snapshot(profile_id, snapshot_file)
        elif action == "discard":
            snaps = self.snapshots(profile_id)
            if snaps:
                profile = self.restore_snapshot(profile_id, snaps[0]["file"])
            else:
                profile, _ = self.load(profile_id)
        else:
            profile, _ = self.load(profile_id)
        self.journal(profile_id, "close", f"crash-recovery:{action}")
        return profile

    def mark_clean_exit(self) -> None:
        for item in self.list():
            if item.get("broken"):
                continue
            last = _tail_event(self.journal_path(item["id"]))
            if last not in (None, "close"):
                self.journal(item["id"], "close", "app-exit")

    # ------------------------------------------------------------------ #
    # Trash / delete / restore
    # ------------------------------------------------------------------ #
    def delete(self, profile_id: str) -> Path:
        src = self.dir_of(profile_id)
        if not src.exists():
            raise FileNotFoundError(profile_id)
        stamp = time.strftime("%Y%m%d-%H%M%S")
        dst = self.trash_root / f"{profile_id}-{stamp}"
        shutil.move(str(src), str(dst))
        (dst / "trash.json").write_text(
            json.dumps({"deleted_at": now_iso(), "original_id": profile_id}, ensure_ascii=False),
            encoding="utf-8",
        )
        return dst

    def trashed(self) -> list[dict[str, Any]]:
        self.purge_trash()
        out = []
        for d in sorted(self.trash_root.iterdir(), reverse=True) if self.trash_root.exists() else []:
            if not d.is_dir():
                continue
            p = d / "profile.json"
            if not p.exists():
                continue
            try:
                raw = read_json(p)
                out.append(
                    {
                        "id": raw.get("id", d.name),
                        "name": raw.get("meta", {}).get("name", d.name),
                        "trashDir": str(d),
                        "deletedAt": d.name.rsplit("-", 2)[-2] + "-" + d.name.rsplit("-", 1)[-1],
                        "previewUrl": (d / "preview.png").as_uri() if (d / "preview.png").exists() else "",
                    }
                )
            except (OSError, ValueError):
                continue
        return out

    def restore_trash(self, trash_dir: str) -> Profile:
        src = Path(trash_dir)
        raw = read_json(src / "profile.json")
        pid = raw.get("id") or src.name.split("-")[0]
        dst = self.dir_of(pid)
        if dst.exists():
            pid = f"{pid}-{uuid.uuid4().hex[:4]}"
            dst = self.dir_of(pid)
            raw["id"] = pid
        shutil.move(str(src), str(dst))
        try:
            (dst / "trash.json").unlink()
        except OSError:
            pass
        profile = Profile.model_validate(raw)
        self.save(profile, reason="restore-trash")
        self.journal(pid, "close", "restored-from-trash")
        return profile

    def purge_trash(self) -> None:
        if not self.trash_root.exists():
            return
        cutoff = time.time() - TRASH_RETENTION_DAYS * 86400
        for d in self.trash_root.iterdir():
            if not d.is_dir():
                continue
            try:
                if d.stat().st_mtime < cutoff:
                    shutil.rmtree(d, ignore_errors=True)
            except OSError:
                pass

    # ------------------------------------------------------------------ #
    # .bbp import / export
    # ------------------------------------------------------------------ #
    def export_bbp(self, profile_id: str, dest_zip: Path) -> Path:
        src = self.dir_of(profile_id)
        if not (src / "profile.json").exists():
            raise FileNotFoundError(profile_id)
        dest_zip.parent.mkdir(parents=True, exist_ok=True)
        tmp = dest_zip.with_suffix(".bbp.tmp")
        with zipfile.ZipFile(tmp, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for p in src.rglob("*"):
                if not p.is_file():
                    continue
                rel = p.relative_to(src)
                if p.name in {"journal.jsonl"} or p.suffix == ".tmp":
                    continue
                zf.write(p, arcname=str(rel).replace("\\", "/"))
        os.replace(tmp, dest_zip)
        return dest_zip

    def import_bbp(self, zip_path: Path) -> Profile:
        with zipfile.ZipFile(zip_path, "r") as zf:
            names = zf.namelist()
            if "profile.json" not in names:
                raise ValueError("不是有效的 .bbp 包：缺少 profile.json")
            with zf.open("profile.json") as f:
                raw = json.loads(f.read().decode("utf-8"))
            pid = raw.get("id") or uuid.uuid4().hex[:12]
            if self.exists(pid):
                pid = f"{pid}-{uuid.uuid4().hex[:4]}"
            dst = self.dir_of(pid)
            dst.mkdir(parents=True, exist_ok=True)
            for member in zf.infolist():
                # zip-slip guard
                target = (dst / member.filename).resolve()
                if not str(target).startswith(str(dst.resolve()) + os.sep):
                    continue
                if member.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                with zf.open(member) as src_f, open(target, "wb") as dst_f:
                    shutil.copyfileobj(src_f, dst_f)
        raw = read_json(dst / "profile.json")
        raw["id"] = pid
        raw["meta"]["name"] = raw.get("meta", {}).get("name", pid)
        raw["meta"]["modified_at"] = now_iso()
        profile = Profile.model_validate(raw)
        self.save(profile, reason="import", render_preview=True)
        self.journal(pid, "close", "imported")
        return profile

    # ------------------------------------------------------------------ #
    # Assets
    # ------------------------------------------------------------------ #
    def import_asset(
        self,
        profile_id: str,
        source: Path,
        *,
        kind: str = "other",
        license_type: str = "unknown",
    ) -> dict[str, Any]:
        data = source.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        safe_name = "".join(c for c in source.name if c.isalnum() or c in "._- ")[:80] or "asset"
        filename = f"{digest[:10]}_{safe_name}"
        target = self.dir_of(profile_id) / "assets" / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            # Content-addressed: reuse, but keep the first friendly name.
            for existing in target.parent.glob(f"{digest[:10]}_*"):
                filename = existing.name
                break
        else:
            atomic_write_bytes(target, data)
        return {
            "id": digest[:16],
            "kind": kind,
            "filename": filename,
            "sha256": digest,
            "license": license_type,
            "source": source.name,
        }

    # ------------------------------------------------------------------ #
    # Preview image
    # ------------------------------------------------------------------ #
    def render_preview(self, profile: Profile) -> Path | None:
        try:
            from PySide6.QtGui import QGuiApplication
        except Exception:
            return None
        if QGuiApplication.instance() is None:
            # Tests and headless tools run without a GUI; previews are optional.
            return None
        try:
            from PySide6.QtCore import Qt
            from PySide6.QtGui import QColor, QFont, QImage, QLinearGradient, QPainter, QRadialGradient
        except Exception:
            return None
        try:
            tokens = self.tokens.resolve(profile.meta.theme)
            palette = tokens.get("color", {}).get("palette", {})
            bg = tokens.get("background", {})
            stops = bg.get("stops", ["#2b1730", "#160d1c"])
            accent = palette.get("primary", "#ffb08a")
            ink = palette.get("on-surface", "#fff5ee")
            w, h = 480, 270
            img = QImage(w, h, QImage.Format_ARGB32)
            img.fill(QColor(stops[0] if stops else "#2b1730"))
            painter = QPainter(img)
            painter.setRenderHint(QPainter.Antialiasing, True)
            painter.setRenderHint(QPainter.TextAntialiasing, True)
            grad = QLinearGradient(0, 0, w, h)
            for i, c in enumerate(stops[:3]):
                grad.setColorAt(i / max(1, len(stops[:3]) - 1), QColor(c))
            painter.fillRect(0, 0, w, h, grad)
            # warm bokeh
            for i, c in enumerate(bg.get("bokeh", [accent])[:2]):
                r = QRadialGradient(90 + i * 300, 90 + i * 90, 140)
                col = QColor(c)
                col.setAlpha(90)
                r.setColorAt(0, col)
                r.setColorAt(1, QColor(0, 0, 0, 0))
                painter.fillRect(0, 0, w, h, r)
            # card motif
            painter.setBrush(QColor(255, 255, 255, 34))
            painter.setPen(QColor(255, 255, 255, 90))
            painter.drawRoundedRect(40, 60, 190, 120, 18, 18)
            painter.setBrush(QColor(255, 255, 255, 20))
            painter.drawRoundedRect(210, 110, 210, 96, 16, 16)
            painter.setPen(QColor(ink))
            font = QFont("Microsoft YaHei UI", 18)
            font.setWeight(QFont.DemiBold)
            painter.setFont(font)
            painter.drawText(52, 100, 168, 40, Qt.AlignLeft | Qt.AlignVCenter, profile.meta.name)
            painter.setPen(QColor(accent))
            font.setPointSize(11)
            font.setWeight(QFont.Normal)
            painter.setFont(font)
            painter.drawText(52, 140, 168, 24, Qt.AlignLeft | Qt.AlignVCenter, f"致 {profile.meta.honoree}")
            painter.end()
            path = self.dir_of(profile.id) / "preview.png"
            img.save(str(path), "PNG")
            return path
        except Exception:
            return None
