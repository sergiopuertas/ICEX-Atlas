#!/usr/bin/env python3
"""Prueba de humo de un entorno desplegado: ¿puede un probador de la beta usar la app?

1. Auth admite email y contraseña, exige confirmar el correo y tiene los hooks activos.
2. Crea una cuenta de prueba (confirmada por la API de administración), entra con
   contraseña y llama a la API como la app: me(), feed, directorio, publicar.
3. Comprueba que un usuario sin sesión no ve nada y borra la cuenta de prueba.

Uso:  SUPABASE_ACCESS_TOKEN=… SUPABASE_PROJECT_REF=… python3 scripts/deploy/smoke_test.py
"""

from __future__ import annotations

import secrets
import sys
import uuid

from supa import Project, request

FAILS: list[str] = []


def check(cond: bool, msg: str):
    print(("  ✓ " if cond else "  ✗ ") + msg)
    if not cond:
        FAILS.append(msg)


def uuid7() -> str:
    import os
    import time
    ms = time.time_ns() // 1_000_000
    rand = int.from_bytes(os.urandom(10), "big")
    v = (ms << 80) | (0x7 << 76) | (((rand >> 62) & 0xFFF) << 64) | (0b10 << 62) | (rand & ((1 << 62) - 1))
    return str(uuid.UUID(int=v))


def main() -> int:
    p = Project()
    keys = p.keys()
    anon, service = keys["anon"], keys["service_role"]
    auth = f"{p.url}/auth/v1"
    print(f"→ Prueba de humo en {p.url}")

    settings = request("GET", f"{auth}/settings", headers={"apikey": anon})
    check(settings.get("external", {}).get("email") is True, "Auth: acceso con email activo")
    if p.ref == "local":
        print("  · local: sin confirmación de correo (normal en desarrollo)")
    else:
        check(settings.get("mailer_autoconfirm") is False, "Auth: hay que confirmar el correo")
    check(settings.get("disable_signup") is False, "Auth: registro abierto (beta)")

    email = f"smoke-{secrets.token_hex(4)}@example.com"
    password = secrets.token_urlsafe(16)
    admin_h = {"apikey": service, "Authorization": f"Bearer {service}"}
    user = request("POST", f"{auth}/admin/users", headers=admin_h, body={
        "email": email, "password": password, "email_confirm": True,
        "user_metadata": {"name": "Prueba de Humo", "promocion": "45"}})
    uid = user["id"]
    try:
        session = request("POST", f"{auth}/token?grant_type=password", headers={"apikey": anon},
                          body={"email": email, "password": password})
        token = session["access_token"]
        api_h = {"apikey": anon, "Authorization": f"Bearer {token}",
                 "Content-Profile": "api", "Accept-Profile": "api"}

        def rpc(fn: str, body=None):
            return request("POST", f"{p.url}/rest/v1/rpc/{fn}", headers=api_h, body=body or {})

        me = rpc("me")
        check(me.get("origen") == "beta", "la cuenta de email es una cuenta beta")
        check(me.get("profile", {}).get("promocion") == 45, "perfil creado con la promoción declarada")
        check(isinstance(rpc("get_feed").get("items"), list), "feed")
        check("items" in rpc("search_directory", {"p_query": "a"}), "directorio")
        post = rpc("create_post", {"p_id": uuid7(), "p_texto": "Prueba de humo del despliegue (se borra sola)"})
        check(bool(post.get("id")), "publicar")
        rpc("delete_post", {"p_id": post["id"]})

        try:
            request("POST", f"{p.url}/rest/v1/rpc/get_feed", body={},
                    headers={"apikey": anon, "Content-Profile": "api", "Accept-Profile": "api"})
            check(False, "sin sesión no se puede leer el feed")
        except RuntimeError as e:
            check("HTTP 401" in str(e) or "HTTP 403" in str(e), "sin sesión no se puede leer el feed")
        try:
            request("GET", f"{p.url}/rest/v1/profiles?select=*", headers={"apikey": anon})
            check(False, "las tablas no están expuestas (solo el esquema api)")
        except RuntimeError as e:
            check("HTTP 4" in str(e), "las tablas no están expuestas (solo el esquema api)")
    finally:
        request("DELETE", f"{auth}/admin/users/{uid}", headers=admin_h)
        print("  · cuenta de prueba borrada")

    print("✓ Entorno listo para la beta." if not FAILS else f"✗ {len(FAILS)} comprobaciones fallidas")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
