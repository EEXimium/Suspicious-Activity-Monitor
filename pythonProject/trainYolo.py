"""Train a model using an explicitly supplied dataset configuration."""
import argparse
from pathlib import Path
from monitor.config import PROJECT_DIR


class ModelTrainer:
    def __init__(self, model_path):
        self.model_path = model_path

    def train(self, data, epochs=100, image_size=640, batch=-1, device=None):
        from ultralytics import YOLO
        options = dict(data=str(data), epochs=epochs, imgsz=image_size, batch=batch)
        if device is not None:
            options["device"] = device
        return YOLO(str(self.model_path)).train(**options)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", required=True, type=Path)
    parser.add_argument("--model", type=Path, default=PROJECT_DIR / "yolo11n.pt")
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--device", help="cpu, mps, or a CUDA device index")
    args = parser.parse_args()
    if not args.data.is_file():
        parser.error("Dataset YAML does not exist.")
    ModelTrainer(args.model).train(args.data.resolve(), epochs=args.epochs, device=args.device)


if __name__ == "__main__":
    main()
