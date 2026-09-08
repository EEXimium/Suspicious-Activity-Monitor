import os
import math
from dataclasses import dataclass
from pathlib import Path
from .security import validate_key

PROJECT_DIR = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class MonitorConfig:
    model_path: Path = PROJECT_DIR / "models/best.pt"
    camera_source: int | str = 1
    confidence_threshold: float = 0.7
    detection_window: float = 10.0
    database_url: str = ""
    credentials_path: str | None = None
    host: str = "127.0.0.1"
    port: int = 5000
    camera_id: str = ""

    def __post_init__(self):
        if not 0 <= self.confidence_threshold <= 1:
            raise ValueError("Confidence threshold must be between 0 and 1.")
        if not math.isfinite(self.detection_window) or self.detection_window < 0:
            raise ValueError("Detection window must be finite and non-negative.")
        if not 1 <= self.port <= 65535:
            raise ValueError("Port must be between 1 and 65535.")
        if not str(self.camera_source).strip() or (isinstance(self.camera_source, int) and self.camera_source < 0):
            raise ValueError("Camera source must be a non-negative index or a stream URL.")

    def validate_startup(self):
        validate_key(self.camera_id)
        if self.host != "127.0.0.1":
            raise ValueError("HOST must be 127.0.0.1; expose the server only through the HTTPS proxy.")
        if not self.model_path.is_file():
            raise ValueError(f"Model file not found: {self.model_path}")
        if not self.database_url.startswith("https://"):
            raise ValueError("Set FIREBASE_DATABASE_URL to your HTTPS Realtime Database URL.")
        if self.credentials_path and not Path(self.credentials_path).is_file():
            raise ValueError(f"Firebase credentials file not found: {self.credentials_path}")

    @classmethod
    def from_environment(cls):
        source = os.getenv("CAMERA_SOURCE", "1").strip()
        model_path = Path(os.getenv("MODEL_PATH", str(cls.model_path))).expanduser()
        if not model_path.is_absolute():
            model_path = PROJECT_DIR / model_path
        return cls(
            model_path=model_path,
            camera_source=int(source) if source.lstrip("-").isdecimal() else source,
            confidence_threshold=float(os.getenv("CONFIDENCE_THRESHOLD", "0.7")),
            detection_window=float(os.getenv("DETECTION_WINDOW", "10")),
            database_url=os.getenv("FIREBASE_DATABASE_URL", ""),
            credentials_path=os.getenv("GOOGLE_APPLICATION_CREDENTIALS"),
            host=os.getenv("HOST", "127.0.0.1"),
            port=int(os.getenv("PORT", "5000")),
            camera_id=os.getenv("CAMERA_ID", ""),
        )
