"""Audio human-factors engine (F-25).

Implements the V1.0 chapter 9 contract:
  * two BGM decks for equal-power crossfades
  * 10–20 ms click-guard ramps on every start/stop
  * 300–1000 ms comfort fades, 9–12 dB ducking with 200/700 ms envelope
  * independent master / SFX volume, always-available mute + pause
  * missing or undecodable files degrade to silence, never to a crash
"""

from __future__ import annotations

import math
from pathlib import Path

from PySide6.QtCore import QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtMultimedia import QAudioOutput, QMediaPlayer, QSoundEffect

from .paths import BUILTIN_AUDIO_DIR

CLICK_GUARD_MS = 15
DUCK_FACTOR = 10 ** (-10.5 / 20)  # ≈ -10.5 dB, inside the −9..−12 dB band
TICK_MS = 16


class _Deck:
    def __init__(self, engine: "AudioEngine") -> None:
        self.engine = engine
        self.player = QMediaPlayer()
        self.output = QAudioOutput()
        self.player.setAudioOutput(self.output)
        self.player.setAudioOutput(self.output)
        self.base = 0.0
        self.gain = 0.0
        self.target = 0.0
        self.fade_ms = 0
        self.fading = False
        self.crossfade_role: str | None = None
        self.crossfade_progress = 0.0
        self.path = ""
        self.player.mediaStatusChanged.connect(self._status_changed)
        self.player.errorOccurred.connect(self._error)

    def _status_changed(self, status: QMediaPlayer.MediaStatus) -> None:
        if status == QMediaPlayer.EndOfMedia and self.player.loops() == 1:
            self.target = 0.0
            self.gain = 0.0
            self.fading = False

    def _error(self, *_args) -> None:
        self.engine.last_error = self.player.errorString()
        self.engine.errorOccurred.emit(self.engine.last_error)

    def play(self, path: Path, loop: bool, gain: float, fade_ms: int) -> None:
        self.path = str(path)
        self.player.setSource(QUrl.fromLocalFile(str(path)))
        self.player.setLoops(QMediaPlayer.Infinite if loop else 1)
        self.base = gain
        self.gain = 0.0
        self.target = gain
        self.fade_ms = max(CLICK_GUARD_MS, fade_ms)
        self.fading = True
        self.crossfade_role = None
        self.player.play()

    def fade_to(self, target: float, ms: int, *, stop_when_done: bool = False) -> None:
        if stop_when_done:
            # Fade from the level we are actually at, then stop for real.
            self.base = max(self.base, self.gain)
        self.target = target
        self.fade_ms = max(CLICK_GUARD_MS, ms)
        self.fading = True
        self.crossfade_role = "stop" if stop_when_done else None

    def stop_now(self) -> None:
        self.player.stop()
        self.gain = 0.0
        self.target = 0.0
        self.fading = False
        self.crossfade_role = None
        self.base = 0.0

    def tick(self, dt: float) -> None:
        if self.crossfade_role:
            self.crossfade_progress = min(1.0, self.crossfade_progress + dt / max(1, self.fade_ms))
            if self.crossfade_role == "in":
                self.gain = self.base * math.sin(self.crossfade_progress * math.pi / 2)
            else:  # "out" and "stop" both fade down to zero
                self.gain = self.base * math.cos(self.crossfade_progress * math.pi / 2)
            if self.crossfade_progress >= 1.0:
                if self.crossfade_role in ("out", "stop"):
                    self.player.stop()
                    self.gain = 0.0
                    self.base = 0.0
                    self.target = 0.0
                    self.fading = False
                self.crossfade_role = None
            return
        if not self.fading:
            return
        step = dt / max(1, self.fade_ms)
        if self.gain < self.target:
            self.gain = min(self.target, self.gain + step * max(self.target, 0.001))
        else:
            self.gain = max(self.target, self.gain - step * max(self.gain, 0.001))
        if abs(self.gain - self.target) < 0.002:
            self.gain = self.target
            self.fading = False
            if self.crossfade_role == "stop" or (self.target == 0.0 and self.base == 0.0):
                self.player.stop()

    @property
    def playing(self) -> bool:
        return self.player.playbackState() == QMediaPlayer.PlayingState


class AudioEngine(QObject):
    volumeChanged = Signal()
    mutedChanged = Signal()
    playingChanged = Signal()
    voiceChanged = Signal()
    positionChanged = Signal(float, float)  # seconds, duration
    errorOccurred = Signal(str)
    sfxPlayed = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.decks = [_Deck(self), _Deck(self)]
        # Spoken blessing: one dedicated player, kept OUT of self.decks so it
        # never crossfades and is never multiplied by duck_current.
        self.voice = _Deck(self)
        self._voice_ducked = False
        self.voice.player.mediaStatusChanged.connect(self._voice_status)
        self.active = 0
        self.master_pct = 50
        self.sfx_pct = 60
        self.muted = False
        self.duck_enabled = True
        self.duck_target = 1.0
        self.duck_current = 1.0
        self.last_error = ""
        self._duck_ms = 700
        self._last_tick = 0.0
        self._timer = QTimer(self)
        self._timer.setInterval(TICK_MS)
        self._timer.timeout.connect(self._tick)
        self._timer.start()
        self._sfx: list[QSoundEffect] = []
        for _ in range(6):
            eff = QSoundEffect(self)
            self._sfx.append(eff)
        self._sfx_cursor = 0
        self._position_timer = QTimer(self)
        self._position_timer.setInterval(200)
        self._position_timer.timeout.connect(self._emit_position)
        self._position_timer.start()
        self._apply_outputs()

    # ------------------------------------------------------------------ #
    # Properties
    # ------------------------------------------------------------------ #
    @property
    def master_gain(self) -> float:
        return 0.0 if self.muted else self.master_pct / 100.0

    @property
    def bgm_playing(self) -> bool:
        return any(d.playing for d in self.decks)

    @property
    def voice_playing(self) -> bool:
        return self.voice.playing

    def _apply_outputs(self) -> None:
        for d in self.decks:
            d.output.setVolume(max(0.0, min(1.0, d.gain * self.master_gain * self.duck_current)))
        self.voice.output.setVolume(max(0.0, min(1.0, self.voice.gain * self.master_gain)))
        for eff in self._sfx:
            eff.setVolume(max(0.0, min(1.0, (self.sfx_pct / 100.0) * self.master_gain * 0.9)))

    def _tick(self) -> None:
        dt = TICK_MS
        duck_step = dt / max(1, self._duck_ms)
        if self.duck_current < self.duck_target:
            self.duck_current = min(self.duck_target, self.duck_current + duck_step)
        elif self.duck_current > self.duck_target:
            self.duck_current = max(self.duck_target, self.duck_current - duck_step)
        for d in self.decks:
            d.tick(dt)
        self.voice.tick(dt)
        self._apply_outputs()

    def _emit_position(self) -> None:
        d = self.decks[self.active]
        pos = d.player.position() / 1000.0
        dur = max(0.001, d.player.duration() / 1000.0)
        self.positionChanged.emit(pos, dur)

    # ------------------------------------------------------------------ #
    # BGM
    # ------------------------------------------------------------------ #
    def resolve_bgm(self, path: str, profile_dir: Path | None = None) -> Path | None:
        if not path:
            return None
        p = Path(path)
        if p.is_absolute():
            return p if p.exists() else None
        if path.startswith("assets/") and profile_dir:
            candidate = profile_dir / path
            return candidate if candidate.exists() else None
        candidate = BUILTIN_AUDIO_DIR.parent / path
        if candidate.exists():
            return candidate
        candidate = BUILTIN_AUDIO_DIR / Path(path).name
        if candidate.exists():
            return candidate
        return None

    @Slot(str, bool, int, int, str)
    def play_bgm(self, path: str, loop: bool = True, volume_pct: int = 50, fade_ms: int = 600, profile_dir: str = "") -> None:
        target = self.resolve_bgm(path, Path(profile_dir) if profile_dir else None)
        if target is None:
            self.last_error = f"BGM 不存在：{path}"
            self.errorOccurred.emit(self.last_error)
            return
        deck = self.decks[self.active]
        deck.play(target, loop, max(0.0, min(1.0, volume_pct / 100.0)), fade_ms)
        self.playingChanged.emit()

    @Slot(str, bool, int, int, str)
    def crossfade_to(self, path: str, loop: bool = True, volume_pct: int = 50, fade_ms: int = 700, profile_dir: str = "") -> None:
        target = self.resolve_bgm(path, Path(profile_dir) if profile_dir else None)
        if target is None:
            self.last_error = f"BGM 不存在：{path}"
            self.errorOccurred.emit(self.last_error)
            return
        old = self.decks[self.active]
        new_index = 1 - self.active
        new = self.decks[new_index]
        new.play(target, loop, max(0.0, min(1.0, volume_pct / 100.0)), fade_ms)
        if old.playing:
            old.crossfade_role = "out"
            old.crossfade_progress = 0.0
            old.fade_ms = max(CLICK_GUARD_MS, fade_ms)
            old.base = old.base or old.gain
        new.crossfade_role = "in"
        new.crossfade_progress = 0.0
        new.fade_ms = max(CLICK_GUARD_MS, fade_ms)
        self.active = new_index
        self.playingChanged.emit()

    @Slot(int)
    def stop_bgm(self, fade_ms: int = 700) -> None:
        for d in self.decks:
            # target > 0 also catches a deck that is still loading (play() was
            # just called but playbackState has not reached PlayingState yet).
            if d.playing or d.target > 0.001:
                d.fade_to(0.0, fade_ms, stop_when_done=True)
        self.playingChanged.emit()

    @Slot()
    def toggle_pause(self) -> None:
        if self.bgm_playing:
            self.decks[self.active].player.pause()
        else:
            self.decks[self.active].player.play()
        state = self.voice.player.playbackState()
        if state == QMediaPlayer.PlayingState:
            self.voice.player.pause()
        elif state == QMediaPlayer.PausedState:
            self.voice.player.play()
        self.playingChanged.emit()

    @Slot(int)
    def set_master_volume(self, pct: int) -> None:
        self.master_pct = max(0, min(100, int(pct)))
        self._apply_outputs()
        self.volumeChanged.emit()

    @Slot(int)
    def set_sfx_volume(self, pct: int) -> None:
        self.sfx_pct = max(0, min(100, int(pct)))
        self._apply_outputs()
        self.volumeChanged.emit()

    @Slot(bool)
    def set_muted(self, muted: bool) -> None:
        self.muted = bool(muted)
        self._apply_outputs()
        self.mutedChanged.emit()

    @Slot()
    def toggle_mute(self) -> None:
        self.set_muted(not self.muted)

    @Slot(bool, int)
    def set_ducked(self, active: bool, attack_ms: int = 220) -> None:
        if not self.duck_enabled:
            self.duck_target = 1.0
            return
        if active:
            self._duck_ms = max(100, min(300, attack_ms))
            self.duck_target = DUCK_FACTOR
        else:
            self._duck_ms = 700
            self.duck_target = 1.0

    @Slot(bool)
    def set_ducking_enabled(self, enabled: bool) -> None:
        self.duck_enabled = bool(enabled)
        if not enabled:
            self.duck_target = 1.0

    # ------------------------------------------------------------------ #
    # Voice (spoken blessing at the wax seal)
    # ------------------------------------------------------------------ #
    def _voice_status(self, status: QMediaPlayer.MediaStatus) -> None:
        if status in (QMediaPlayer.EndOfMedia, QMediaPlayer.InvalidMedia):
            self._restore_voice_duck()
            self.voiceChanged.emit()

    def _restore_voice_duck(self) -> None:
        if self._voice_ducked:
            self._voice_ducked = False
            self.set_ducked(False)

    @Slot(str, int, bool, str)
    def play_voice(self, path: str, volume_pct: int = 85, duck: bool = True, profile_dir: str = "") -> None:
        target = self.resolve_bgm(path, Path(profile_dir) if profile_dir else None)
        if target is None:
            self.last_error = f"祝福语音不存在：{path}"
            self.errorOccurred.emit(self.last_error)
            return
        self.voice.stop_now()
        self._restore_voice_duck()
        self.voice.play(target, False, max(0.0, min(1.0, volume_pct / 100.0)), 120)
        self._voice_ducked = bool(duck)
        if duck:
            self.set_ducked(True)
        self.voiceChanged.emit()

    @Slot(int)
    def stop_voice(self, fade_ms: int = 200) -> None:
        if self.voice.playing or self.voice.gain > 0.001 or self.voice.target > 0.001:
            self.voice.fade_to(0.0, fade_ms, stop_when_done=True)
        self._restore_voice_duck()
        self.voiceChanged.emit()

    # ------------------------------------------------------------------ #
    # SFX
    # ------------------------------------------------------------------ #
    def resolve_sfx(self, kind_or_path: str, profile_dir: Path | None = None) -> Path | None:
        if kind_or_path.startswith("assets/") and profile_dir:
            candidate = profile_dir / kind_or_path
            return candidate if candidate.exists() else None
        if kind_or_path.endswith((".wav", ".ogg", ".mp3", ".flac")):
            p = Path(kind_or_path)
            if p.is_absolute() and p.exists():
                return p
            candidate = BUILTIN_AUDIO_DIR.parent / kind_or_path
            if candidate.exists():
                return candidate
            candidate = BUILTIN_AUDIO_DIR / p.name
            if candidate.exists():
                return candidate
            return None
        candidate = BUILTIN_AUDIO_DIR / f"sfx_{kind_or_path}.wav"
        return candidate if candidate.exists() else None

    @Slot(str, float, str)
    def play_sfx(self, kind: str, volume_scale: float = 1.0, profile_dir: str = "") -> None:
        path = self.resolve_sfx(kind, Path(profile_dir) if profile_dir else None)
        if path is None:
            return
        eff = self._sfx[self._sfx_cursor % len(self._sfx)]
        self._sfx_cursor += 1
        eff.setSource(QUrl.fromLocalFile(str(path)))
        eff.setVolume(max(0.0, min(1.0, (self.sfx_pct / 100.0) * self.master_gain * volume_scale * 0.9)))
        eff.play()
        self.sfxPlayed.emit(kind)

    @Slot(str, int, float, str)
    def play_sfx_after(self, kind: str, delay_ms: int, volume_scale: float = 1.0, profile_dir: str = "") -> None:
        QTimer.singleShot(max(0, int(delay_ms)), lambda: self.play_sfx(kind, volume_scale, profile_dir))

    @Slot()
    def stop_all_sfx(self) -> None:
        for eff in self._sfx:
            eff.stop()

    def shutdown(self) -> None:
        self._timer.stop()
        self._position_timer.stop()
        for d in self.decks:
            d.player.stop()
        self.voice.stop_now()
        for eff in self._sfx:
            eff.stop()
