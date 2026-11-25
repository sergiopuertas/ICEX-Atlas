#!/usr/bin/env python3
"""Genera app/env/<entorno>.json para compilar la app contra un proyecto de Supabase.

La URL y la clave pública (anon) se leen del proyecto con el token de acceso: no hay que
copiarlas a mano. El resto sale de variables opcionales.

Uso:  SUPABASE_ACCESS_TOKEN=… SUPABASE_PROJECT_REF=… python3 scripts/deploy/app_env.py staging
"""

from __future__ import annotations

import json
import pathlib
import sys

from supa import Project, opt

ROOT = pathlib.Path(__file__).resolve().parents[2]


def main(argv: list[str]) -> int:
    environment = argv[0] if argv else "staging"
    p = Project()
    env = {
        "SUPABASE_URL": p.url,
        "SUPABASE_ANON_KEY": p.keys()["anon"],
        "APP_ENV": environment,
        "AUTH_MODE": opt("AUTH_MODE", "password"),
        "AUTH_REDIRECT": opt("AUTH_REDIRECT", "es.icexalumni.atlas://login-callback"),
        "OIDC_PROVIDER": "custom:icex-alumni",
        "SENTRY_DSN": opt("SENTRY_DSN"),
        "FEEDBACK_URL": opt("FEEDBACK_URL"),
        "PRIVACY_URL": opt("PRIVACY_URL"),
        "SHOW_DEMO_BANNER": False,
        "DEV_LOGIN": False,
    }
    if not env["PRIVACY_URL"]:
        print("  ⚠ PRIVACY_URL vacío: las tiendas y TestFlight exigen una política de privacidad.")
    out = ROOT / "app" / "env" / f"{environment}.json"
    out.write_text(json.dumps(env, indent=2, ensure_ascii=False) + "\n")
    print(f"✓ {out.relative_to(ROOT)} ({env['SUPABASE_URL']}, AUTH_MODE={env['AUTH_MODE']})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
