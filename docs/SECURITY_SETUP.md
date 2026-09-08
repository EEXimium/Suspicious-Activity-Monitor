# Secure deployment and migration

This change must be deployed as a coordinated database/server/iOS upgrade. The
repository provides code, rules and a proxy template; it does not change your
live Firebase project or provision a DNS name/certificate automatically.

## Access model

- Firebase Authentication **UID**, not email, is the authorization identity.
- An administrator registers camera metadata and grants membership. Clients
  cannot write membership or camera metadata. Shared camera passwords are removed.
- A member can link the registered camera to their own account. The database
  checks membership and the exact administrator-registered URL on every link.
- Logs are stored once under `cameraLogs/{cameraID}/{object}/{eventID}`. Only a
  member who has linked that camera can read or delete its events. All members
  of a camera share its history and can delete individual events; they cannot
  create or edit evidence. There is no global client-readable log endpoint.
- Unlinking hides the camera from that user's app and stops their stream access.
  Only an administrator can revoke membership; an unlinked member can relink.
- Feedback is create-only under the authenticated UID, at most 5,000 characters,
  with a server timestamp. It is readable only using administrator credentials.

## 1. Prepare and test

Enable Firebase Email/Password Authentication and Realtime Database. Download
the iOS configuration and a server-side service-account credential. Keep the
service account off the phone and out of Git; it bypasses database rules and must
be stored only on the trusted camera/admin host. Use a separate Firebase project
for staging. Do not set Firebase emulator environment variables in production.

From the repository root, test the rules with Node 22+ and Java 21+:

```powershell
cd firebase
npm ci --ignore-scripts
npm test
```

Tests target the `demo-sam-security` local emulator project, not a live database.
Deploy the reviewed rules from the repository root to an explicitly selected
project after backing up the existing data:

```powershell
.\firebase\node_modules\.bin\firebase.cmd deploy --only database --project YOUR_PROJECT_ID
```

On macOS/Linux use `./firebase/node_modules/.bin/firebase` for that command.

## 2. HTTPS camera host

Install Caddy on the camera host. Set `CAMERA_DOMAIN` to a DNS hostname that points
to it, for example `front-camera.example.com`. The provided `deploy/Caddyfile`
obtains and renews a publicly trusted certificate. DNS and certificate issuance
must work for that hostname; Caddy's default challenge flow requires ports 80/443.
For a private LAN, use a certificate trusted by the phone and the server's DNS
name. Do not bypass iOS certificate validation or re-enable HTTP exceptions.

```powershell
$env:CAMERA_DOMAIN = "front-camera.example.com"
caddy run --config deploy/Caddyfile
```

Run the Python server separately:

```powershell
cd pythonProject
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
$env:FIREBASE_DATABASE_URL = "https://YOUR_PROJECT_DATABASE_URL"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\private\serviceAccount.json"
$env:CAMERA_ID = "front-door"
$env:CAMERA_SOURCE = "0"
.\.venv\Scripts\python.exe GoingLiveYOLO.py
```

The Waitress listener is deliberately bound to `127.0.0.1:5000`. Only one local
proxy is trusted to assert HTTPS. Do not expose the listener to the LAN or add a
port-forward for port 5000. The Caddy template uses port 5000; update its upstream
if you explicitly change `PORT`. Run one process/proxy upstream per camera.

The stream accepts Firebase **ID tokens** only in the `Authorization: Bearer`
header, verifies signatures, expiration and revocation, then checks membership
and linking. Query-string credentials and anonymous video access are rejected.
Open streams stop at token expiry, or after a failed authorization recheck (every
15 seconds, at the next processed frame). No further frame is yielded after a
failed check. The iOS app refreshes the token/connection before expiry and offers
Retry on connection failure. Video responses are not cached. The camera server
and phone need synchronized clocks.

## 3. Register a camera and grant access

Run these commands from `pythonProject` on the trusted administrator machine,
with the intended Firebase environment variables set. Find each user's UID in
Firebase Authentication. Camera IDs and provisioned UIDs must use letters,
digits, underscores or hyphens (maximum 128 characters).

```powershell
python manage_camera.py register --camera-id front-door --url https://front-camera.example.com/video_feed
python manage_camera.py grant --camera-id front-door --uid FIREBASE_USER_UID
```

These commands print the exact target database and changes without writing.
After review, repeat each with `--apply`. Granting does not automatically link
the camera: in the iOS app, sign in and enter `front-door` under Account Settings.
The stream URL must end in `/video_feed`, with no embedded credentials or query.

To revoke access, review and then apply:

```powershell
python manage_camera.py revoke --camera-id front-door --uid FIREBASE_USER_UID
python manage_camera.py revoke --camera-id front-door --uid FIREBASE_USER_UID --apply
```

Revocation atomically removes membership and that user's linked-camera entry.

## 4. Existing installation migration

1. Stop old camera servers and take an administrator export/backup of the database.
2. Deploy the reviewed deny-by-default rules. Old clients will no longer work.
3. Register each camera's HTTPS endpoint and explicitly grant the correct UIDs.
   Registering replaces that camera's metadata with its URL, removing the old
   plaintext password at that path. Delete remaining obsolete password records
   only after reviewing the backup; the supplied rules deny client reads of them.
4. Start updated servers with a unique `CAMERA_ID` matching each registration.
5. Install the updated iOS app; users sign in and link their granted cameras.
6. Check with two different accounts that each sees only its granted cameras,
   logs and streams. Revoke one grant while its stream is open and verify closure.

Legacy `logs/...` have no camera ownership information. They are intentionally
inaccessible under the new rules and are not automatically copied into a user's
history. If you can independently establish a record's camera, migrate it as an
administrator to that camera's subtree after review. Old email-keyed links are
not trusted as authorization and are not used. Preserve the backup until you
have verified the new deployment.

## References and remaining runtime checks

The implementation follows [Firebase ID token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens),
[Realtime Database rules](https://firebase.google.com/docs/database/security) and
[trusted proxy configuration](https://flask.palletsprojects.com/en/stable/deploying/proxy_fix/).
Local tests cover authorization decisions, revocation, expiry, database isolation
and denied privilege escalation. A real iOS build, camera inference and TLS/
Firebase integration still need macOS/Xcode, hardware and your own credentials.
Detection still requires a stream consumer; remote push delivery and continuous
background monitoring are separate features, not guarantees of this setup.
