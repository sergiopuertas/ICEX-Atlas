/// Cuentas de prueba para el acceso rápido de desarrollo.
///
/// Deben coincidir con `supabase/seed_dev_accounts.sql`. Solo se muestran con
/// `AppEnv.devLogin` (DEV_LOGIN=true en `env/local.json` y nunca en producción).
class DevAccount {
  const DevAccount({required this.email, required this.name, required this.role});

  final String email;
  final String name;

  /// Para qué sirve probar con esta cuenta (texto de la portada).
  final String role;

  /// Contraseña común de las cuentas locales (datos ficticios, solo en tu Supabase local).
  static const password = 'atlas-dev-local';

  static const all = [
    DevAccount(
      email: 'ana.ortega@demo.icexalumni.invalid',
      name: 'Ana Ortega Jiménez',
      role: 'Socia · 49ª promoción',
    ),
    DevAccount(
      email: 'javier.martin@demo.icexalumni.invalid',
      name: 'Javier Martín Jiménez',
      role: 'Socio · para probar chats entre dos',
    ),
    DevAccount(
      email: 'laura.gil@demo.icexalumni.invalid',
      name: 'Laura Gil Navarro',
      role: 'Administradora',
    ),
    DevAccount(
      email: 'pedro.nosocio@demo.icexalumni.invalid',
      name: 'Pedro Sin Membresía',
      role: 'No socio · acceso denegado',
    ),
  ];
}
