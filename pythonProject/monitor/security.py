"""Fail-closed authentication and camera authorization, independent of Flask."""
import re
import time
from dataclasses import dataclass


def validate_key(value: str, label="Camera ID") -> str:
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", value):
        raise ValueError(f"{label} must contain 1-128 letters, digits, underscores or hyphens.")
    return value


class AuthenticationError(Exception):
    pass


class AuthorizationError(Exception):
    pass


@dataclass(frozen=True)
class StreamSession:
    uid: str
    expires_at: float


class StreamAuthorizer:
    def __init__(self, verifier, access, camera_id, clock=time.time):
        self._verifier = verifier
        self._access = access
        self._camera_id = validate_key(camera_id)
        self._clock = clock

    def authorize(self, token):
        claims = self._verifier.verify(token)
        uid = claims.get("uid")
        expiry = claims.get("exp")
        if not isinstance(uid, str) or not uid:
            raise AuthenticationError("Invalid identity.")
        if not isinstance(expiry, (int, float)) or not self._clock() < expiry < float("inf"):
            raise AuthenticationError("Expired or invalid token.")
        if not self._access.is_allowed(uid, self._camera_id):
            raise AuthorizationError("Camera access denied.")
        return StreamSession(uid, expiry)
