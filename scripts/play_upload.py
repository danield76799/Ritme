#!/usr/bin/env python3
"""Upload een Android App Bundle naar de Play Store (androidpublisher v3).

De service-account JSON wordt uit de omgevingsvariabele
PLAY_SERVICE_ACCOUNT_JSON gelezen (in CI: een GitHub Actions-secret).
Zonder die variabele doet het script niets en eindigt het met code 2, zodat
een workflow kan kiezen om de stap over te slaan.

Standaard gaat de upload naar de 'internal' track: dat is de veilige,
automatische route (geen review nodig). Productie-uploads blijven bewust
handmatig, of via --track production (dan kan Google om 'Send for review'
vragen; dat wordt hieronder opgevangen).
"""

import argparse
import json
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def build_service():
    raw = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON", "").strip()
    if not raw:
        print("PLAY_SERVICE_ACCOUNT_JSON ontbreekt", file=sys.stderr)
        return None
    info = json.loads(raw)
    creds = service_account.Credentials.from_service_account_info(
        info, scopes=SCOPES
    )
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def upload(aab, package, track, status, name):
    service = build_service()
    if service is None:
        return 2

    edit_id = (
        service.edits().insert(body={}, packageName=package).execute()["id"]
    )
    media = MediaFileUpload(aab, mimetype="application/octet-stream", resumable=True)
    bundle = (
        service.edits()
        .bundles()
        .upload(packageName=package, editId=edit_id, media_body=media)
        .execute()
    )
    version_code = bundle["versionCode"]

    service.edits().tracks().update(
        packageName=package,
        editId=edit_id,
        track=track,
        body={
            "track": track,
            "releases": [
                {
                    "versionCodes": [str(version_code)],
                    "status": status,
                    "name": name or f"Ritme {version_code}",
                }
            ],
        },
    ).execute()

    try:
        service.edits().commit(packageName=package, editId=edit_id).execute()
    except Exception as e:  # noqa: BLE001 - Google gebruikt een generieke HttpError
        if "changesNotSentForReview" not in str(e) and "changesNotSentForReview" not in repr(e):
            raise
        # Google eist soms dat de developer zelf op 'Send for review' drukt.
        service.edits().commit(
            packageName=package,
            editId=edit_id,
            changesNotSentForReview=True,
        ).execute()

    print(f"PUBLISHED versionCode={version_code} track={track} status={status}")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--aab", required=True, help="pad naar app-release.aab")
    ap.add_argument("--package", default="com.ritme.ritme.v2")
    ap.add_argument("--track", default="internal", choices=["internal", "alpha", "beta", "production"])
    ap.add_argument("--status", default="completed", choices=["draft", "completed", "halted", "inProgress"])
    ap.add_argument("--name", default="")
    args = ap.parse_args()
    return upload(args.aab, args.package, args.track, args.status, args.name)


if __name__ == "__main__":
    sys.exit(main())
