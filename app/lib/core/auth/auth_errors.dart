import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Motivos de error de acceso que la app sabe explicar (la pantalla los traduce).
abstract final class AuthErrorCode {
  static const network = 'network';
  static const invalidCredentials = 'invalid_credentials';
  static const emailNotConfirmed = 'email_not_confirmed';
  static const userExists = 'user_exists';
  static const weakPassword = 'weak_password';
  static const rateLimit = 'rate_limit';
  static const signupClosed = 'signup_closed';
  static const samePassword = 'same_password';
  static const notMember = 'not_member';

  static const Set<String> known = {
    network,
    invalidCredentials,
    emailNotConfirmed,
    userExists,
    weakPassword,
    rateLimit,
    signupClosed,
    samePassword,
  };
}

/// Traduce un error de Supabase Auth (o de red) a un [AuthErrorCode]. Si no se reconoce,
/// devuelve el texto original (se muestra un mensaje genérico salvo en desarrollo).
String authErrorCode(Object e) {
  if (e is SocketException || e is HttpException || e is AuthRetryableFetchException) {
    return AuthErrorCode.network;
  }
  final text = e.toString();
  final code = e is AuthException ? (e.code ?? '') : '';
  final msg = (e is AuthException ? e.message : text).toLowerCase();
  if (text.contains('icex_member')) return AuthErrorCode.notMember;
  if (text.contains('signup_closed') ||
      code == 'signup_disabled' ||
      code == 'email_provider_disabled') {
    return AuthErrorCode.signupClosed;
  }
  if (code == 'invalid_credentials' || msg.contains('invalid login credentials')) {
    return AuthErrorCode.invalidCredentials;
  }
  if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
    return AuthErrorCode.emailNotConfirmed;
  }
  if (code == 'user_already_exists' ||
      code == 'email_exists' ||
      msg.contains('already registered')) {
    return AuthErrorCode.userExists;
  }
  if (code == 'weak_password' || msg.contains('password should')) return AuthErrorCode.weakPassword;
  if (code == 'same_password') return AuthErrorCode.samePassword;
  if (code.startsWith('over_') || msg.contains('rate limit')) return AuthErrorCode.rateLimit;
  if (msg.contains('socketexception') ||
      msg.contains('failed host lookup') ||
      msg.contains('connection')) {
    return AuthErrorCode.network;
  }
  return text;
}
