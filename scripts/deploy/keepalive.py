#!/usr/bin/env python3
"""Mantiene despierto un proyecto del plan gratuito de Supabase.

Supabase pausa los proyectos gratuitos tras 7 días sin actividad (p. ej. en Navidad, si no entra
ningún probador). Este script genera actividad real y barata: Auth, la API (PostgREST) y una
consulta a la base de datos. Si el proyecto ya estaba pausado, lo dice y falla, para que llegue
el aviso de GitHub y alguien lo reactive desde el panel (Project → Restore).

Uso:  SUPABASE_ACCESS_TOKEN=… SUPABASE_PROJECT_REF=… python3 scripts/deploy/keepalive.py
"""

from __future__ import annotations

import sys

from supa import Project, request


def main() -> int:
    p = Project()
    info = p.mgmt("GET", "") or {}
    status = info.get("status", "?")
    if status != "ACTIVE_HEALTHY":
        print(f"✗ El proyecto {p.ref} está en estado {status}. Si está pausado, reactívalo en el panel de Supabase.")
        return 1
    anon = p.keys()["anon"]
    request("GET", f"{p.url}/auth/v1/health", headers={"apikey": anon})
    try:  # sin sesión la API responde 401, pero la petición llega a PostgREST y a la base de datos
        request("POST", f"{p.url}/rest/v1/rpc/me", body={},
                headers={"apikey": anon, "Content-Profile": "api", "Accept-Profile": "api"})
    except RuntimeError:
        pass
    rows = p.sql("select count(*)::int as socios from identity.members") or [{}]
    print(f"✓ {p.ref} activo · {rows[0].get('socios', '?')} cuentas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
