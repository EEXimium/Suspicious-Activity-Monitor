"""Authenticated HTTPS stream. The production listener trusts one local proxy."""
import time
from .security import AuthenticationError, AuthorizationError


def create_app(processor, authorizer, clock=time.time, recheck_interval=15):
    from flask import Flask, Response, request, jsonify
    app = Flask(__name__)

    @app.before_request
    def require_https():
        if not request.is_secure:
            return jsonify(error="HTTPS required."), 400

    @app.after_request
    def private_response(response):
        response.headers["Cache-Control"] = "no-store, private"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "no-referrer"
        return response

    @app.get("/")
    def index():
        return "S.A.M. camera server. Sign in using the iOS app to view this camera."

    @app.get("/video_feed")
    def video_feed():
        header = request.headers.get("Authorization", "")
        scheme, separator, token = header.partition(" ")
        if not separator or scheme.lower() != "bearer" or not token.strip() or len(token) > 8192:
            return jsonify(error="Bearer token required."), 401
        try:
            session = authorizer.authorize(token)
        except AuthenticationError:
            return jsonify(error="Invalid or expired session."), 401
        except AuthorizationError:
            return jsonify(error="Camera access denied."), 403
        except Exception:
            # Never include the credential, claims or an upstream exception in a response/log.
            return jsonify(error="Authorization service unavailable."), 503

        def frames():
            next_check = clock() + recheck_interval
            source = processor.frames()
            try:
                for frame in source:
                    now = clock()
                    if now >= session.expires_at:
                        return
                    if now >= next_check:
                        try:
                            authorizer.authorize(token)
                        except Exception:
                            return
                        next_check = now + recheck_interval
                    yield frame
            finally:
                source.close()

        return Response(frames(), mimetype="multipart/x-mixed-replace; boundary=frame")

    return app
