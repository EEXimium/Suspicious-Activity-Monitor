import base64
import unittest
from datetime import datetime, timedelta
from unittest.mock import Mock, patch

from monitor.config import MonitorConfig, PROJECT_DIR
from monitor.domain import Detection, DetectionLogger
from monitor.streaming import StreamProcessor


class DetectionLoggerTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 1, 1)
        self.repository = Mock()
        self.encoder = Mock()
        self.encoder.encode.return_value = b"jpeg"
        self.logger = DetectionLogger(self.repository, self.encoder, clock=lambda: self.now)

    def test_filters_unknown_objects_and_threshold_boundary(self):
        for detection in [Detection("person", 0.99), Detection("Knife", 0.7), Detection("Pistol", 0.1)]:
            self.assertFalse(self.logger.record("frame", detection))
        self.encoder.encode.assert_not_called()
        self.repository.save.assert_not_called()

    def test_preserves_database_payload(self):
        self.assertTrue(self.logger.record("frame", Detection("Knife", 0.9)))
        self.repository.save.assert_called_once_with("Knife", {
            "date": self.now.isoformat(), "confidence": 0.9,
            "timestamp": self.now.timestamp(),
            "photoBase64": base64.b64encode(b"jpeg").decode("ascii"),
        })

    def test_cooldown_is_per_object_and_expires_at_ten_seconds(self):
        self.logger.record("frame", Detection("Knife", 0.9))
        self.now += timedelta(seconds=9)
        self.assertFalse(self.logger.record("frame", Detection("Knife", 0.95)))
        self.assertTrue(self.logger.record("frame", Detection("Pistol", 0.95)))
        self.now += timedelta(seconds=1)
        self.assertTrue(self.logger.record("frame", Detection("Knife", 0.95)))
        self.assertEqual(self.repository.save.call_count, 3)

    def test_failed_write_can_be_retried_immediately(self):
        self.repository.save.side_effect = [RuntimeError("offline"), None]
        with self.assertRaises(RuntimeError):
            self.logger.record("frame", Detection("Knife", 0.9))
        self.assertTrue(self.logger.record("frame", Detection("Knife", 0.9)))

    def test_invalid_confidence_never_reaches_storage(self):
        for confidence in [float("nan"), float("inf"), -1, 1.1]:
            self.assertFalse(self.logger.record("frame", Detection("Knife", confidence)))
        self.repository.save.assert_not_called()


class StreamProcessorTests(unittest.TestCase):
    def setUp(self):
        self.camera, self.detector, self.logger, self.encoder = Mock(), Mock(), Mock(), Mock()
        self.camera.read.return_value = "raw"
        self.detector.detect.return_value = ([Detection("Knife", 0.9)], "annotated")
        self.encoder.encode.return_value = b"jpeg"
        self.processor = StreamProcessor(self.camera, self.detector, self.logger, self.encoder)

    def test_stream_format_and_raw_evidence_frame(self):
        stream = self.processor.frames()
        self.assertEqual(next(stream), b"--frame\r\nContent-Type: image/jpeg\r\n\r\njpeg\r\n")
        self.logger.record.assert_called_once_with("raw", Detection("Knife", 0.9))
        self.encoder.encode.assert_called_once_with("annotated", quality=90)
        stream.close()

    def test_database_failure_does_not_stop_stream(self):
        self.logger.record.side_effect = RuntimeError("offline")
        with self.assertLogs("monitor.streaming", level="ERROR"):
            self.assertEqual(self.processor.next_frame(), b"jpeg")

    def test_close_releases_camera_once_and_prevents_reads(self):
        self.processor.close()
        self.processor.close()
        self.camera.close.assert_called_once()
        with self.assertRaises(RuntimeError):
            self.processor.next_frame()
        self.camera.read.assert_not_called()

    def test_failed_camera_ends_stream(self):
        self.camera.read.side_effect = RuntimeError("disconnected")
        with self.assertLogs("monitor.streaming", level="ERROR"):
            self.assertEqual(list(self.processor.frames()), [])


class ConfigurationTests(unittest.TestCase):
    def test_defaults_do_not_depend_on_current_directory(self):
        self.assertTrue(MonitorConfig().model_path.is_absolute())
        self.assertEqual(MonitorConfig().model_path, PROJECT_DIR / "models/best.pt")

    def test_camera_accepts_device_index_and_url(self):
        for source, expected in [("0", 0), ("rtsp://camera/stream", "rtsp://camera/stream")]:
            with patch.dict("os.environ", {"CAMERA_SOURCE": source}, clear=True):
                self.assertEqual(MonitorConfig.from_environment().camera_source, expected)

    def test_invalid_threshold_and_window_are_rejected(self):
        with self.assertRaises(ValueError):
            MonitorConfig(confidence_threshold=1.1)
        with self.assertRaises(ValueError):
            MonitorConfig(detection_window=-1)

    def test_nonfinite_window_and_invalid_port_are_rejected(self):
        for window in [float("nan"), float("inf")]:
            with self.assertRaises(ValueError):
                MonitorConfig(detection_window=window)
        for port in [0, 65536]:
            with self.assertRaises(ValueError):
                MonitorConfig(port=port)

    def test_invalid_camera_sources_are_rejected(self):
        for source in ["", "-1"]:
            with patch.dict("os.environ", {"CAMERA_SOURCE": source}, clear=True):
                with self.assertRaises(ValueError):
                    MonitorConfig.from_environment()

    def test_relative_model_override_is_project_relative(self):
        with patch.dict("os.environ", {"MODEL_PATH": "models/best.pt"}, clear=True):
            self.assertEqual(MonitorConfig.from_environment().model_path, PROJECT_DIR / "models/best.pt")

    def test_missing_startup_configuration_fails_before_external_connections(self):
        with self.assertRaisesRegex(ValueError, "FIREBASE_DATABASE_URL"):
            MonitorConfig(camera_id="front-door").validate_startup()
        with self.assertRaisesRegex(ValueError, "Model file not found"):
            MonitorConfig(camera_id="front-door", model_path=PROJECT_DIR / "missing.pt").validate_startup()


if __name__ == "__main__":
    unittest.main()
