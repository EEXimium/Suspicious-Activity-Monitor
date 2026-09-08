"""Local webcam preview. Press q to quit; no Firebase connection is needed."""
import argparse
from monitor.adapters import OpenCVCamera, YOLODetector
from monitor.config import MonitorConfig


class CameraPreview:
    def __init__(self, camera, detector):
        self.camera = camera
        self.detector = detector

    def run(self):
        import cv2
        try:
            while True:
                frame = self.camera.read()
                _, annotated = self.detector.detect(frame)
                cv2.imshow("YOLOv11 Live Detection", annotated)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break
        finally:
            self.camera.close()
            cv2.destroyAllWindows()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--camera", type=int, default=0)
    parser.add_argument("--model", default=str(MonitorConfig.model_path))
    args = parser.parse_args()
    detector = YOLODetector(args.model)
    CameraPreview(OpenCVCamera(args.camera), detector).run()


if __name__ == "__main__":
    main()
