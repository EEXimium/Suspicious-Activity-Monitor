from contextlib import ExitStack
import logging

from monitor.adapters import (FirebaseLogRepository, FirebaseTokenVerifier, FirebaseCameraAccess,
                              JPEGEncoder, OpenCVCamera, YOLODetector)
from monitor.config import MonitorConfig
from monitor.domain import DetectionLogger
from monitor.streaming import StreamProcessor
from monitor.web import create_app
from monitor.security import StreamAuthorizer


def main():
    logging.basicConfig(level=logging.INFO)
    config = MonitorConfig.from_environment()
    config.validate_startup()
    with ExitStack() as resources:
        repository = FirebaseLogRepository(config.database_url, config.credentials_path, config.camera_id)
        resources.callback(repository.close)
        detector = YOLODetector(config.model_path)
        camera = OpenCVCamera(config.camera_source)
        resources.callback(camera.close)
        encoder = JPEGEncoder()
        detection_logger = DetectionLogger(repository, encoder, config.confidence_threshold, config.detection_window)
        processor = StreamProcessor(camera, detector, detection_logger, encoder)
        authorizer = StreamAuthorizer(FirebaseTokenVerifier(repository.app),
                                      FirebaseCameraAccess(repository.app), config.camera_id)
        app = create_app(processor, authorizer)
        # Only the local TLS proxy may reach this listener. One process per camera.
        from waitress import serve
        serve(app, host=config.host, port=config.port, threads=8,
              trusted_proxy="127.0.0.1", trusted_proxy_count=1,
              trusted_proxy_headers={"x-forwarded-proto"})


if __name__ == "__main__":
    main()
