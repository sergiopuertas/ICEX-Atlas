#!/usr/bin/env python3
"""Configura un proyecto de Supabase en la nube para ICEX Atlas (idempotente).

Lo que `supabase db push` y `functions deploy` NO hacen y antes había que tocar a mano en el
Dashboard (docs/runbook.md): Auth (registro, URLs, hooks, correos en español, SMTP),
esquemas expuestos de la API, secretos de Vault para las tareas Cron, modo de acceso
(beta abierta) y secretos de las Edge Functions.

Uso (en GitHub Actions lo lanza el flujo «Deploy backend»):
    SUPABASE_ACCESS_TOKEN=… SUPABASE_PROJECT_REF=… python3 scripts/deploy/configure_supabase.py
    … --dry-run      muestra lo que enviaría (sin secretos) y no cambia nada

Variables: ver docs/beta.md → «Secretos y variables».
"""

from __future__ import annotations

import pathlib
import sys

from supa import Project, lit, opt

ROOT = pathlib.Path(__file__).resolve().parents[2]
TEMPLATES = ROOT / "supabase" / "templates"

# Secretos de las Edge Functions que se copian si están definidos (ver .env.example).
FUNCTION_SECRETS = [
    "LLM_PROVIDER", "LLM_BASE_URL", "LLM_API_KEY", "LLM_MODEL", "EMBEDDINGS_PROVIDER",
    "PUSH_PROVIDER", "FCM_SERVICE_ACCOUNT_JSON", "WP_BASE_URL", "WP_SYNC_TOKEN",
    "MEMBERSHIP_MAX_REVOKE_RATIO", "ADMIN_ALLOWED_ORIGINS",
]
SECRET_FIELDS = {"smtp_pass"}


def auth_config() -> dict:
    redirect = opt("AUTH_REDIRECT", "es.icexalumni.atlas://login-callback")
    extra = [u.strip() for u in opt("EXTRA_REDIRECT_URLS").split(",") if u.strip()]
    access_mode = opt("ACCESS_MODE", "open_beta")
    cfg = {
        "site_url": redirect,
        "uri_allow_list": ",".join([redirect, *extra]),
        # Email y contraseña: imprescindible en beta abierta; en «alumni» se cierra el registro.
        "external_email_enabled": True,
        "disable_signup": access_mode != "open_beta",
        "mailer_autoconfirm": False,                 # hay que confirmar el correo
        "mailer_secure_email_change_enabled": True,
        "password_min_length": 8,
        "external_phone_enabled": False,
        "external_anonymous_users_enabled": False,
        "security_refresh_token_reuse_interval": 10,
        "jwt_exp": 3600,
        # Hooks (funciones Postgres de las migraciones).
        "hook_before_user_created_enabled": True,
        "hook_before_user_created_uri": "pg-functions://postgres/identity/before_user_created",
        "hook_custom_access_token_enabled": True,
        "hook_custom_access_token_uri": "pg-functions://postgres/identity/custom_access_token",
        # Correos en español.
        "mailer_subjects_confirmation": "Activa tu cuenta de ICEX Atlas",
        "mailer_templates_confirmation_content": (TEMPLATES / "confirmacion.html").read_text(),
        "mailer_subjects_recovery": "Elige una contraseña nueva para ICEX Atlas",
        "mailer_templates_recovery_content": (TEMPLATES / "recuperar.html").read_text(),
        "mailer_subjects_email_change": "Confirma tu nuevo correo en ICEX Atlas",
        "mailer_templates_email_change_content": (TEMPLATES / "cambio_email.html").read_text(),
    }
    if opt("SMTP_HOST"):
        cfg |= {
            "smtp_host": opt("SMTP_HOST"),
            "smtp_port": opt("SMTP_PORT", "587"),
            "smtp_user": opt("SMTP_USER"),
            "smtp_pass": opt("SMTP_PASS"),
            "smtp_admin_email": opt("SMTP_SENDER_EMAIL"),
            "smtp_sender_name": opt("SMTP_SENDER_NAME", "ICEX Atlas"),
            # Con SMTP propio hay que subir el límite explícitamente (si no, sigue en 2/h).
            "rate_limit_email_sent": int(opt("EMAIL_RATE_LIMIT_PER_HOUR", "100")),
        }
    return cfg


def postgrest_config() -> dict:
    # Solo el esquema `api` se expone (las tablas viven en esquemas privados).
    return {"db_schema": "api", "db_extra_search_path": "api, extensions", "max_rows": 1000}


def database_sql(p: Project, service_key: str) -> str:
    access_mode = opt("ACCESS_MODE", "open_beta")
    if access_mode not in ("open_beta", "alumni"):
        sys.exit("✗ ACCESS_MODE debe ser open_beta o alumni")

    def upsert_secret(name: str, value: str) -> str:
        return f"""
  if exists (select 1 from vault.secrets where name = {lit(name)}) then
    perform vault.update_secret((select id from vault.secrets where name = {lit(name)}), {lit(value)});
  else
    perform vault.create_secret({lit(value)}, {lit(name)});
  end if;"""

    return f"""do $$
begin{upsert_secret('project_url', p.url)}{upsert_secret('service_role_key', service_key)}
end $$;
insert into config.app_config (key, value, descripcion)
values ('access.mode', to_jsonb({lit(access_mode)}::text), 'alumni | open_beta (registro con email y contraseña)')
on conflict (key) do update set value = excluded.value, updated_at = now();
select key, value from config.app_config where key = 'access.mode';"""


def masked(d: dict) -> dict:
    return {k: ("***" if k in SECRET_FIELDS and v else (f"<{len(v)} caracteres>" if k.endswith("_content") else v))
            for k, v in d.items()}


def main(argv: list[str]) -> int:
    dry = "--dry-run" in argv
    p = Project()
    print(f"→ Proyecto {p.ref} ({p.url})")

    auth = auth_config()
    if not opt("SMTP_HOST"):
        print("  ⚠ Sin SMTP propio: Supabase solo envía 2 correos/hora y solo a miembros del equipo.\n"
              "    Para la beta pública configura SMTP_* (p. ej. Resend o Brevo). Ver docs/beta.md.")
    secrets = [{"name": n, "value": opt(n)} for n in FUNCTION_SECRETS if opt(n)]

    if dry:
        import json
        print(json.dumps({"auth": masked(auth), "postgrest": postgrest_config(),
                          "function_secrets": [s["name"] for s in secrets]}, indent=2, ensure_ascii=False))
        return 0

    print("→ Auth (registro, URLs, hooks, correos)")
    p.mgmt("PATCH", "/config/auth", auth)
    print("→ API REST: solo el esquema api")
    p.mgmt("PATCH", "/postgrest", postgrest_config())
    print("→ Vault (tareas Cron) y modo de acceso")
    result = p.sql(database_sql(p, p.keys()["service_role"]))
    print(f"  {result}")
    if secrets:
        print(f"→ Secretos de Edge Functions: {', '.join(s['name'] for s in secrets)}")
        p.mgmt("POST", "/secrets", secrets)

    # Comprobación: lo que ha quedado guardado.
    saved = p.mgmt("GET", "/config/auth")
    problems = [k for k in ("site_url", "external_email_enabled", "disable_signup", "mailer_autoconfirm",
                            "hook_before_user_created_enabled", "hook_custom_access_token_enabled")
                if saved.get(k) != auth[k]]
    if problems:
        print(f"✗ La configuración de Auth no coincide en: {problems}")
        return 1
    print("✓ Supabase configurado.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
