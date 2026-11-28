#!/usr/bin/env python3
"""Cuenta temporal para las pruebas en móviles reales (Firebase Test Lab).

  create  → crea una cuenta beta confirmada (sin enviar correos) y escribe, para GitHub
            Actions, TEST_EMAIL, TEST_PASSWORD (enmascarada) y TEST_USER_ID en $GITHUB_ENV.
  delete  → la borra (por id o, si falta, por email).

Las cuentas son `testlab-<hex>@example.com` y se llaman «Prueba en Dispositivo», para que
se reconozcan si alguna quedara por un fallo. `delete --stale` borra las de más de 1 día.

Uso:  SUPABASE_ACCESS_TOKEN=… SUPABASE_PROJECT_REF=… python3 scripts/deploy/test_account.py create
"""

from __future__ import annotations

import os
import secrets
import sys
from datetime import datetime, timedelta, timezone

from supa import Project, request

PREFIX = "testlab-"
DOMAIN = "example.com"


def admin_headers(p: Project) -> dict[str, str]:
    service = p.keys()["service_role"]
    return {"apikey": service, "Authorization": f"Bearer {service}"}


def export(name: str, value: str, secret: bool = False):
    if secret and os.environ.get("GITHUB_ACTIONS"):
        print(f"::add-mask::{value}")
    path = os.environ.get("GITHUB_ENV")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            f.write(f"{name}={value}\n")
    else:
        print(f"{name}={'***' if secret else value}")


def create(p: Project):
    email = f"{PREFIX}{secrets.token_hex(4)}@{DOMAIN}"
    password = secrets.token_urlsafe(18)
    user = request("POST", f"{p.url}/auth/v1/admin/users", headers=admin_headers(p), body={
        "email": email, "password": password, "email_confirm": True,
        "user_metadata": {"name": "Prueba en Dispositivo", "promocion": "45"}})
    export("TEST_EMAIL", email)
    export("TEST_PASSWORD", password, secret=True)
    export("TEST_USER_ID", user["id"])
    print(f"✓ cuenta de prueba {email}")


def delete(p: Project, stale: bool):
    h = admin_headers(p)
    ids = [os.environ["TEST_USER_ID"]] if os.environ.get("TEST_USER_ID") and not stale else []
    if stale or not ids:
        cutoff = datetime.now(timezone.utc) - timedelta(days=1)
        page = 1
        while True:
            users = (request("GET", f"{p.url}/auth/v1/admin/users?page={page}&per_page=200", headers=h) or {}).get("users", [])
            for u in users:
                email = u.get("email") or ""
                created = datetime.fromisoformat(u["created_at"].replace("Z", "+00:00"))
                if email.startswith(PREFIX) and email.endswith(f"@{DOMAIN}") and (not stale or created < cutoff):
                    ids.append(u["id"])
            if len(users) < 200:
                break
            page += 1
    for uid in ids:
        # Lo que haya publicado la prueba se va con la cuenta (borrado en cascada en la base de datos).
        request("DELETE", f"{p.url}/auth/v1/admin/users/{uid}", headers=h, ok=(200, 204, 404))
    print(f"✓ {len(ids)} cuenta(s) de prueba borrada(s)")


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] not in ("create", "delete"):
        print(__doc__)
        return 2
    p = Project()
    if sys.argv[1] == "create":
        create(p)
    else:
        delete(p, stale="--stale" in sys.argv)
    return 0


if __name__ == "__main__":
    sys.exit(main())
