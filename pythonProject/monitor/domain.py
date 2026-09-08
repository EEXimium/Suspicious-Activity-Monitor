"""Detection policy, independent of OpenCV, YOLO and Firebase."""
import base64
from dataclasses import dataclass
from datetime import datetime, timezone
import math
from typing import Protocol

THREAT_TYPES = frozenset({"Pistol", "Knife", "Rifle", "Stick-Rod"})


@dataclass(frozen=True)
class Detection:
    object_type: str
    confidence: float


class LogRepository(Protocol):
    def save(self, object_type: str, entry: dict) -> None: ...


class ImageEncoder(Protocol):
    def encode(self, frame, quality: int = 50) -> bytes: ...


class DetectionLogger:
    """Per-object cooldown. Failed writes do not consume the cooldown.

    Access is serialized by the owning StreamProcessor.
    """
    def __init__(self, repository: LogRepository, encoder: ImageEncoder,
                 threshold=0.7, window=10.0, clock=lambda: datetime.now(timezone.utc)):
        self._repository = repository
        self._encoder = encoder
        self._threshold = threshold
        self._window = window
        self._clock = clock
        self._last_saved: dict[str, datetime] = {}

    def record(self, frame, detection: Detection) -> bool:
        if (detection.object_type not in THREAT_TYPES
                or not math.isfinite(detection.confidence)
                or not self._threshold < detection.confidence <= 1):
            return False
        now = self._clock()
        previous = self._last_saved.get(detection.object_type)
        if previous is not None and (now - previous).total_seconds() < self._window:
            return False
        entry = {
            "date": now.isoformat(),
            "timestamp": now.timestamp(),
            "confidence": detection.confidence,
            "photoBase64": base64.b64encode(self._encoder.encode(frame)).decode("ascii"),
        }
        self._repository.save(detection.object_type, entry)
        self._last_saved[detection.object_type] = now
        return True
