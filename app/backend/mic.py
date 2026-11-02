"""Optional microphone blow detector (F-22 enhancement; click is the default)."""

from __future__ import annotations

import struct

from PySide6.QtCore import QObject, QTimer, Signal, Slot
from PySide6.QtMultimedia import QAudioFormat, QAudioSource, QMediaDevices


class MicMonitor(QObject):
    levelChanged = Signal(float)
    availabilityChanged = Signal(bool, str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._source: QAudioSource | None = None
        self._io = None
        self._level = 0.0
        self._available = False
        self._message = "麦克风未启用"
        self._timer = QTimer(self)
        self._timer.setInterval(50)
        self._timer.timeout.connect(self._decay)

    @property
    def level(self) -> float:
        return self._level

    @property
    def available(self) -> bool:
        return self._available

    @property
    def message(self) -> str:
        return self._message

    @Slot()
    def start(self) -> None:
        if self._source is not None:
            return
        try:
            device = QMediaDevices.defaultAudioInput()
            if device is None or device.isNull():
                self._fail("未检测到麦克风设备")
                return
            fmt = QAudioFormat()
            fmt.setSampleRate(16000)
            fmt.setChannelCount(1)
            fmt.setSampleFormat(QAudioFormat.Int16)
            if not device.isFormatSupported(fmt):
                fmt = device.preferredFormat()
            self._source = QAudioSource(device, fmt, self)
            self._io = self._source.start()
            if self._io is None:
                self._fail("麦克风无法启动，将回退为点击吹蜡烛")
                return
            self._io.readyRead.connect(self._read)
            self._available = True
            self._message = "麦克风已就绪"
            self.availabilityChanged.emit(True, self._message)
            self._timer.start()
        except Exception as exc:  # pragma: no cover - device dependent
            self._fail(f"麦克风不可用：{exc}")

    def _read(self) -> None:
        if self._io is None:
            return
        data = bytes(self._io.readAll())
        if len(data) < 2:
            return
        count = len(data) // 2
        try:
            samples = struct.unpack(f"<{count}h", data[: count * 2])
        except struct.error:
            return
        if not samples:
            return
        peak = max(abs(s) for s in samples) / 32768.0
        # Fast attack, slow release makes a puff easy to trigger.
        self._level = max(peak, self._level * 0.82)
        self.levelChanged.emit(self._level)

    def _decay(self) -> None:
        self._level *= 0.9
        self.levelChanged.emit(self._level)

    def _fail(self, message: str) -> None:
        self._available = False
        self._message = message
        self.stop()
        self.availabilityChanged.emit(False, message)

    @Slot()
    def stop(self) -> None:
        self._timer.stop()
        if self._source is not None:
            try:
                self._source.stop()
            except Exception:
                pass
            self._source.deleteLater()
            self._source = None
        self._io = None
        self._level = 0.0
