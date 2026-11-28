"""Utilidades comunes para hablar con la Management API de Supabase y con el proyecto.

Solo usa la biblioteca estándar (funciona igual en GitHub Actions y en un Mac).
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

MGMT = "https://api.supabase.com/v1"


def need(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"✗ Falta la variable {name}. Mira docs/beta.md (secretos del entorno).")
    return value


def opt(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def request(method: str, url: str, token: str | None = None, body=None, headers=None, ok=(200, 201, 204)):
    data = None if body is None else json.dumps(body).encode()
    h = {"Content-Type": "application/json", "User-Agent": "icex-atlas-deploy"}
    if token:
        h["Authorization"] = f"Bearer {token}"
    h.update(headers or {})
    req = urllib.request.Request(url, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            if r.status not in ok:
                raise RuntimeError(f"{method} {url} → HTTP {r.status}: {raw[:300]!r}")
            return json.loads(raw) if raw.strip() else None
    except urllib.error.HTTPError as e:
        detail = e.read()[:500].decode(errors="replace")
        raise RuntimeError(f"{method} {url} → HTTP {e.code}: {detail}") from None


class Project:
    """Un proyecto de Supabase en la nube, a partir del token de acceso y su ref."""

    def __init__(self):
        # Para probar contra el Supabase local: SUPABASE_URL + SUPABASE_ANON_KEY + SUPABASE_SERVICE_ROLE_KEY.
        self.url = opt("SUPABASE_URL")
        if self.url and opt("SUPABASE_ANON_KEY") and opt("SUPABASE_SERVICE_ROLE_KEY"):
            self.token, self.ref = "", "local"
            self._keys = {"anon": opt("SUPABASE_ANON_KEY"), "service_role": opt("SUPABASE_SERVICE_ROLE_KEY")}
            return
        self.token = need("SUPABASE_ACCESS_TOKEN")
        self.ref = need("SUPABASE_PROJECT_REF")
        self.url = f"https://{self.ref}.supabase.co"
        self._keys = None

    def mgmt(self, method: str, path: str, body=None):
        if not self.token:
            sys.exit("✗ Esta operación necesita SUPABASE_ACCESS_TOKEN y SUPABASE_PROJECT_REF")
        return request(method, f"{MGMT}/projects/{self.ref}{path}", self.token, body)

    def keys(self) -> dict[str, str]:
        """Claves del proyecto (anon y service_role). Así no hace falta guardarlas como secretos."""
        if self._keys is None:
            rows = self.mgmt("GET", "/api-keys?reveal=true") or []
            self._keys = {r.get("name"): r.get("api_key") for r in rows if r.get("api_key")}
            if "anon" not in self._keys or "service_role" not in self._keys:
                sys.exit("✗ No se pudieron leer las claves anon/service_role del proyecto (¿token sin permisos?)")
        return self._keys

    def sql(self, query: str):
        if self.token:
            return self.mgmt("POST", "/database/query", {"query": query})
        # Local: conexión directa (DB_URL, por defecto la del Supabase local). Requiere psycopg.
        try:
            import psycopg
            from psycopg.rows import dict_row
        except ImportError:
            sys.exit('✗ En local, las consultas SQL necesitan psycopg: pip install "psycopg[binary]"')
        dsn = opt("DB_URL", "postgresql://postgres:postgres@127.0.0.1:54322/postgres")
        with psycopg.connect(dsn, autocommit=True, row_factory=dict_row) as conn:
            cur = conn.execute(query)
            return cur.fetchall() if cur.description else []


def lit(value: str) -> str:
    """Literal SQL seguro (comillas simples escapadas)."""
    return "'" + value.replace("'", "''") + "'"
