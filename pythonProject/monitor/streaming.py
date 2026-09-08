"""Serializes camera/model access for concurrent HTTP consumers."""
import logging
from threading import Lock

logger = logging.getLogger(__name__)


class StreamProcessor:
    def __init__(self, camera, detector, detection_logger, encoder):
        self._camera = camera
        self._detector = detector
        self._logger = detection_logger
        self._encoder = encoder
        self._lock = Lock()
        self._closed = False

    def next_frame(self):
        with self._lock:
            if self._closed:
                raise RuntimeError("Stream processor is closed.")
            frame = self._camera.read()
            detections, annotated = self._detector.detect(frame)
            for detection in detections:
                try:
                    self._logger.record(frame, detection)
                except Exception:
                    logger.exception("Could not persist %s detection", detection.object_type)
            return self._encoder.encode(annotated, quality=90)

    def frames(self):
        while True:
            try:
                frame = self.next_frame()
            except RuntimeError:
                logger.exception("Camera stream stopped")
                return
            yield b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + frame + b"\r\n"

    def close(self):
        with self._lock:
            if not self._closed:
                self._closed = True
                self._camera.close()
