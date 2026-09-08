"""Administrator-only camera provisioning. Dry-run unless --apply is supplied."""
import argparse
import json
from urllib.parse import urlparse

from monitor.config import MonitorConfig
from monitor.security import validate_key


def build_changes(action, camera_id, uid=None, url=None):
    validate_key(camera_id)
    if action == "register":
        parsed = urlparse(url or "")
        if (parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password
                or parsed.query or parsed.fragment or parsed.path != "/video_feed"):
            raise ValueError("URL must be https://<camera-host>/video_feed with no credentials or query.")
        return {f"cameras/{camera_id}": {"url": url}}
    validate_key(uid or "", "User UID")
    if action == "grant":
        return {f"cameraMembers/{camera_id}/{uid}": True}
    if action == "revoke":
        return {f"cameraMembers/{camera_id}/{uid}": None,
                f"users/{uid}/linked_cameras/{camera_id}": None}
    raise ValueError("Unknown provisioning action.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["register", "grant", "revoke"])
    parser.add_argument("--camera-id", required=True)
    parser.add_argument("--uid", help="Firebase Authentication UID, not email")
    parser.add_argument("--url", help="HTTPS stream URL, for register")
    parser.add_argument("--apply", action="store_true", help="Apply this plan to the configured Firebase project")
    args = parser.parse_args()
    try:
        changes = build_changes(args.action, args.camera_id, args.uid, args.url)
    except ValueError as error:
        parser.error(str(error))
    config = MonitorConfig.from_environment()
    print(json.dumps({"database": config.database_url, "updates": changes}, indent=2))
    if not args.apply:
        print("Dry-run only. Review the database and updates before using --apply.")
        return
    if not config.database_url.startswith("https://"):
        parser.error("Set FIREBASE_DATABASE_URL to the intended HTTPS database URL.")
    import firebase_admin
    from firebase_admin import auth, credentials, db
    credential = credentials.Certificate(config.credentials_path) if config.credentials_path else credentials.ApplicationDefault()
    app = firebase_admin.initialize_app(credential, {"databaseURL": config.database_url})
    try:
        root = db.reference(app=app)
        if args.action == "grant":
            auth.get_user(args.uid, app=app)
            if not root.child("cameras").child(args.camera_id).child("url").get():
                parser.error("Register this camera before granting access.")
        root.update(changes)
        print("Provisioning applied.")
    finally:
        firebase_admin.delete_app(app)


if __name__ == "__main__":
    main()
