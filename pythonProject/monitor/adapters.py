"""External dependencies are initialized explicitly at startup."""
from .domain import Detection


class OpenCVCamera:
    def __init__(self, source):
        import cv2
        self._capture = cv2.VideoCapture(source)
        if not self._capture.isOpened():
            self.close()
            raise RuntimeError(f"Cannot open camera: {source}")

    def read(self):
        success, frame = self._capture.read()
        if not success or frame is None:
            raise RuntimeError("Failed to capture a camera frame.")
        return frame

    def close(self):
        self._capture.release()


class JPEGEncoder:
    def encode(self, frame, quality=50):
        import cv2
        success, buffer = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, quality])
        if not success:
            raise RuntimeError("JPEG encoding failed.")
        return buffer.tobytes()


class YOLODetector:
    def __init__(self, model_path):
        from ultralytics import YOLO
        self._model = YOLO(str(model_path))

    def detect(self, frame):
        results = self._model(frame)
        detections = [Detection(self._model.names[int(box.cls[0])], float(box.conf[0]))
                      for result in results for box in result.boxes]
        return detections, results[0].plot() if results else frame


class FirebaseLogRepository:
    def __init__(self, database_url, credentials_path=None, camera_id=""):
        import firebase_admin
        from firebase_admin import credentials, db
        from uuid import uuid4
        from .security import validate_key
        self._camera_id = validate_key(camera_id)
        if not database_url:
            raise ValueError("Set FIREBASE_DATABASE_URL before starting the server.")
        credential = credentials.Certificate(credentials_path) if credentials_path else credentials.ApplicationDefault()
        self._app = firebase_admin.initialize_app(
            credential, {"databaseURL": database_url}, name=f"monitor-{uuid4().hex}"
        )
        self._reference = db.reference("cameraLogs", app=self._app).child(self._camera_id)

    @property
    def app(self):
        return self._app

    def save(self, object_type, entry):
        from .domain import THREAT_TYPES
        if object_type not in THREAT_TYPES:
            raise ValueError("Unknown threat type.")
        self._reference.child(object_type).push({**entry, "cameraID": self._camera_id})

    def close(self):
        import firebase_admin
        firebase_admin.delete_app(self._app)


class FirebaseTokenVerifier:
    def __init__(self, app):
        self._app = app

    def verify(self, token):
        from firebase_admin import auth
        from .security import AuthenticationError
        try:
            return auth.verify_id_token(token, app=self._app, check_revoked=True)
        except (auth.InvalidIdTokenError, auth.RevokedIdTokenError, auth.UserDisabledError, ValueError) as error:
            raise AuthenticationError("Invalid or revoked token.") from error


class FirebaseCameraAccess:
    def __init__(self, app):
        from firebase_admin import db
        self._root = db.reference(app=app)

    def is_allowed(self, uid, camera_id):
        # UIDs may be supplied by custom auth providers; never allow path injection.
        if any(char in uid for char in ".#$[]/") or any(ord(char) < 32 or ord(char) == 127 for char in uid):
            return False
        member = self._root.child("cameraMembers").child(camera_id).child(uid).get()
        linked = self._root.child("users").child(uid).child("linked_cameras").child(camera_id).get()
        return member is True and isinstance(linked, str) and bool(linked)
