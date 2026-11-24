/// Errores de dominio, independientes de Supabase. La UI solo conoce estos tipos.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// Traduce el código SQLSTATE / HTTP que devuelve la API (`api.*`) a un fallo de dominio.
  factory AppFailure.fromCode(String? code, String? message, {String? hint}) {
    final msg = message ?? '';
    switch (code) {
      case '42501':
      case '401':
      case '403':
        return ForbiddenFailure(msg);
      case 'P0002':
      case '23503': // algo que se borró en ese mismo instante (clave ajena)
      case '404':
      case 'PGRST202':
        return NotFoundFailure(msg);
      case 'P0001' when hint == 'rate_limited':
      case '429':
        return RateLimitedFailure(msg);
      case '22023':
      case '22001':
      case '400':
      case '415':
      case '413':
        return ValidationFailure(msg);
      default:
        return UnknownFailure(msg);
    }
  }

  final String message;

  @override
  String toString() => 'AppFailure($message)';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Sin conexión']);
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure(super.message);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}

final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure(super.message);
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message);
}
