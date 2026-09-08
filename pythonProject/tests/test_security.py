import unittest
from unittest.mock import Mock, patch
from monitor.security import StreamAuthorizer, StreamSession, AuthenticationError, AuthorizationError
from monitor.config import MonitorConfig
from monitor.adapters import FirebaseLogRepository, FirebaseCameraAccess
from monitor.web import create_app
from manage_camera import build_changes


class AuthorizerTests(unittest.TestCase):
    def setUp(self):
        self.verifier, self.access = Mock(), Mock()
        self.verifier.verify.return_value = {"uid": "alice", "exp": 200}
        self.access.is_allowed.return_value = True
        self.authorizer = StreamAuthorizer(self.verifier, self.access, "front", clock=lambda: 100)

    def test_verified_uid_not_caller_input_controls_access(self):
        self.assertEqual(self.authorizer.authorize("token"), StreamSession("alice", 200))
        self.access.is_allowed.assert_called_once_with("alice", "front")

    def test_invalid_or_expired_identity_is_rejected(self):
        for claims in [{}, {"uid": "alice", "exp": 100}, {"uid": "alice", "exp": float("nan")},
                       {"uid": "alice", "exp": float("inf")}, {"uid": "", "exp": 200}]:
            self.verifier.verify.return_value = claims
            with self.assertRaises(AuthenticationError):
                self.authorizer.authorize("token")
        self.access.is_allowed.assert_not_called()

    def test_valid_token_without_camera_membership_is_denied(self):
        self.access.is_allowed.return_value = False
        with self.assertRaises(AuthorizationError):
            self.authorizer.authorize("token")

    def test_repository_writes_only_configured_camera(self):
        repository = FirebaseLogRepository.__new__(FirebaseLogRepository)
        repository._camera_id = "front"
        repository._reference = Mock()
        repository.save("Knife", {"confidence": 0.9, "cameraID": "other"})
        repository._reference.child.assert_called_once_with("Knife")
        repository._reference.child.return_value.push.assert_called_once_with({"confidence": 0.9, "cameraID": "front"})

    def test_access_requires_membership_and_link_and_rejects_path_injection(self):
        access = FirebaseCameraAccess.__new__(FirebaseCameraAccess)
        access._root = Mock()
        access._root.child.return_value = access._root
        for member, linked, expected in [(True, "https://camera/video_feed", True),
                                          (False, "https://camera/video_feed", False),
                                          (True, None, False), ("true", "https://camera/video_feed", False)]:
            access._root.get.side_effect = [member, linked]
            self.assertEqual(access.is_allowed("alice", "front"), expected)
        access._root.reset_mock()
        self.assertFalse(access.is_allowed("alice/other", "front"))
        access._root.child.assert_not_called()


class WebSecurityTests(unittest.TestCase):
    def setUp(self):
        self.now = 100
        self.processor, self.authorizer = Mock(), Mock()
        self.authorizer.authorize.return_value = StreamSession("alice", 200)
        self.processor.frames.side_effect = lambda: iter_frames()
        self.client = create_app(self.processor, self.authorizer, clock=lambda: self.now).test_client()

    def get(self, **kwargs):
        return self.client.get("/video_feed", base_url="https://camera.test", **kwargs)

    def test_https_is_required_even_with_spoofed_forwarded_header(self):
        response = self.client.get("/video_feed", headers={"Authorization": "Bearer token", "X-Forwarded-Proto": "https"})
        self.assertEqual(response.status_code, 400)
        self.authorizer.authorize.assert_not_called()
        self.processor.frames.assert_not_called()

    def test_missing_token_and_query_tokens_are_rejected(self):
        for kwargs in [{}, {"query_string": {"token": "secret"}}, {"headers": {"Authorization": "Basic secret"}}]:
            self.assertEqual(self.get(**kwargs).status_code, 401)
        self.processor.frames.assert_not_called()

    def test_invalid_token_forbidden_camera_and_auth_outage_fail_closed(self):
        for error, status in [(AuthenticationError(), 401), (AuthorizationError(), 403), (RuntimeError("secret"), 503)]:
            self.authorizer.authorize.side_effect = error
            response = self.get(headers={"Authorization": "Bearer token"})
            self.assertEqual(response.status_code, status)
            self.assertNotIn(b"secret", response.data)
        self.processor.frames.assert_not_called()

    def test_authorized_stream_has_private_cache_policy(self):
        response = self.get(headers={"Authorization": "Bearer token"})
        self.assertEqual(response.status_code, 200)
        self.assertIn("multipart/x-mixed-replace", response.content_type)
        self.assertEqual(response.headers["Cache-Control"], "no-store, private")
        self.assertEqual(next(response.response), b"frame")
        response.close()

    def test_open_stream_stops_when_membership_is_revoked(self):
        closed = Mock()
        self.processor.frames.side_effect = lambda: iter_frames(closed)
        response = self.get(headers={"Authorization": "Bearer token"})
        iterator = iter(response.response)
        self.assertEqual(next(iterator), b"frame")
        self.now = 116
        self.authorizer.authorize.side_effect = AuthorizationError()
        with self.assertRaises(StopIteration):
            next(iterator)
        closed.assert_called_once()

    def test_open_stream_stops_when_token_expires(self):
        response = self.get(headers={"Authorization": "Bearer token"})
        iterator = iter(response.response)
        next(iterator)
        self.now = 200
        with self.assertRaises(StopIteration):
            next(iterator)


def iter_frames(closed=None):
    try:
        while True:
            yield b"frame"
    finally:
        if closed is not None:
            closed()


class ProvisioningTests(unittest.TestCase):
    def test_grant_does_not_let_user_choose_an_arbitrary_url(self):
        self.assertEqual(build_changes("grant", "front", "alice"), {"cameraMembers/front/alice": True})

    def test_revoke_removes_membership_and_link_atomically(self):
        self.assertEqual(build_changes("revoke", "front", "alice"), {
            "cameraMembers/front/alice": None, "users/alice/linked_cameras/front": None,
        })

    def test_insecure_urls_and_path_injection_are_rejected(self):
        for url in ["http://camera/video_feed", "https://user:password@camera/video_feed",
                    "https://camera/video_feed?token=secret", "https://camera/wrong"]:
            with self.assertRaises(ValueError):
                build_changes("register", "front", url=url)
        with self.assertRaises(ValueError):
            build_changes("grant", "front/other", "alice")

    def test_startup_requires_camera_identity_and_loopback_listener(self):
        for config in [MonitorConfig(), MonitorConfig(camera_id="front", host="0.0.0.0")]:
            with self.assertRaises(ValueError):
                config.validate_startup()


if __name__ == "__main__":
    unittest.main()
