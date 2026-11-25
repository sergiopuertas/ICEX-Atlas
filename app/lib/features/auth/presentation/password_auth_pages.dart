import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/auth_errors.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/links.dart';

/// Acceso con email y contraseña de la beta abierta (`AUTH_MODE=password`):
/// entrar, crear cuenta, recuperar contraseña, «revisa tu correo» y contraseña nueva.

/// Texto para un [AuthErrorCode] (o un mensaje genérico si no se reconoce).
String authErrorText(AppLocalizations l, String code) => switch (code) {
  AuthErrorCode.network => l.errorNetwork,
  AuthErrorCode.invalidCredentials => l.authErrInvalidCredentials,
  AuthErrorCode.userExists => l.authErrUserExists,
  AuthErrorCode.weakPassword => l.authErrWeakPassword,
  AuthErrorCode.rateLimit => l.authErrRateLimit,
  AuthErrorCode.signupClosed => l.authErrSignupClosed,
  AuthErrorCode.samePassword => l.authErrSamePassword,
  _ => l.loginError,
};

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
const minPasswordLength = 8;

String? _validateEmail(AppLocalizations l, String? v) =>
    _emailRe.hasMatch((v ?? '').trim()) ? null : l.authInvalidEmail;

String? _validatePassword(AppLocalizations l, String? v) =>
    (v ?? '').length >= minPasswordLength ? null : l.authShortPassword;

/// Estructura común: barra roja con título y un formulario centrado (máx. 440 px).
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.children, this.leading});

  final String title;
  final List<Widget> children;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), leading: leading),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 32), children: children),
        ),
      ),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Semantics(
      liveRegion: true,
      child: Text(
        text,
        key: const Key('auth-error'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: IcexColors.destructive),
      ),
    ),
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    this.fieldKey,
    this.validator,
    this.newPassword = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final Key? fieldKey;
  final FormFieldValidator<String>? validator;
  final bool newPassword;
  final VoidCallback? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      obscureText: !_visible,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: [
        if (widget.newPassword) AutofillHints.newPassword else AutofillHints.password,
      ],
      textInputAction: widget.onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.newPassword ? l.authPasswordHint : null,
        suffixIcon: IconButton(
          tooltip: _visible ? l.authHidePassword : l.authShowPassword,
          icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}

Widget _submitButton({
  required Key key,
  required String label,
  required bool busy,
  required VoidCallback onPressed,
}) => FilledButton(
  key: key,
  onPressed: busy ? null : onPressed,
  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
  child: busy
      ? const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
      : Text(label),
);

// ------------------------------------------------------------------- Entrar ---

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    TextInput.finishAutofillContext();
    unawaited(
      ref
          .read(sessionControllerProvider.notifier)
          .signInWithPassword(email: _email.text, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final busy = session is SigningIn;
    final error = session is SignedOut ? session.error : null;
    return _AuthScaffold(
      title: l.authSignInTitle,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('auth-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  validator: (v) => _validateEmail(l, v),
                  decoration: InputDecoration(labelText: l.authEmail),
                ),
                const SizedBox(height: 16),
                _PasswordField(
                  fieldKey: const Key('auth-password'),
                  controller: _password,
                  label: l.authPassword,
                  validator: (v) => (v ?? '').isEmpty ? l.authShortPassword : null,
                  onSubmitted: _submit,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('auth-forgot'),
            onPressed: () =>
                context.push('/recuperar?email=${Uri.encodeQueryComponent(_email.text)}'),
            child: Text(l.authForgot),
          ),
        ),
        const SizedBox(height: 8),
        _submitButton(
          key: const Key('auth-submit'),
          label: l.authSignInButton,
          busy: busy,
          onPressed: _submit,
        ),
        if (error != null) _ErrorText(authErrorText(l, error)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.pushReplacement('/registro'),
          child: Text(l.authNoAccount),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- Crear cuenta ---

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  int? _promo;
  bool _accepted = false;
  bool _showAcceptError = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final ok = _form.currentState?.validate() ?? false;
    setState(() => _showAcceptError = !_accepted);
    if (!ok || !_accepted) return;
    TextInput.finishAutofillContext();
    unawaited(
      ref
          .read(sessionControllerProvider.notifier)
          .signUp(
            email: _email.text,
            password: _password.text,
            name: _name.text,
            promocion: _promo,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final env = ref.watch(appEnvProvider);
    final session = ref.watch(sessionControllerProvider);
    final busy = session is SigningIn;
    final error = session is SignedOut ? session.error : null;
    final current = currentPromocion();
    return _AuthScaffold(
      title: l.authSignUpTitle,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('auth-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  maxLength: 120,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      null,
                  validator: (v) => (v ?? '').trim().length >= 2 ? null : l.authNameRequired,
                  decoration: InputDecoration(labelText: l.authName),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('auth-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  validator: (v) => _validateEmail(l, v),
                  decoration: InputDecoration(labelText: l.authEmail),
                ),
                const SizedBox(height: 16),
                _PasswordField(
                  fieldKey: const Key('auth-password'),
                  controller: _password,
                  label: l.authPassword,
                  newPassword: true,
                  validator: (v) => _validatePassword(l, v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  key: const Key('auth-promo'),
                  initialValue: _promo,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.authPromo),
                  items: [
                    DropdownMenuItem(child: Text(l.authPromoNone)),
                    for (var p = current; p >= 1; p--)
                      DropdownMenuItem(value: p, child: Text('$pª promoción')),
                  ],
                  onChanged: (v) => setState(() => _promo = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          key: const Key('auth-accept'),
          value: _accepted,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => setState(() {
            _accepted = v ?? false;
            if (_accepted) _showAcceptError = false;
          }),
          title: Text(l.authAcceptPrivacy, style: t.bodyMedium),
          subtitle: _showAcceptError
              ? Text(l.authMustAcceptPrivacy, style: const TextStyle(color: IcexColors.destructive))
              : null,
        ),
        if (env.privacyUrl.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => openExternalUrl(context, env.privacyUrl),
              child: Text(l.authReadPrivacy),
            ),
          ),
        const SizedBox(height: 12),
        _submitButton(
          key: const Key('auth-submit'),
          label: l.authSignUpButton,
          busy: busy,
          onPressed: _submit,
        ),
        if (error != null) _ErrorText(authErrorText(l, error)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.pushReplacement('/entrar'),
          child: Text(l.authHaveAccount),
        ),
      ],
    );
  }
}

// ------------------------------------------------------ Recuperar contraseña ---

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({this.initialEmail = '', super.key});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ref.read(sessionControllerProvider.notifier).sendPasswordReset(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = err == null;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return _AuthScaffold(
      title: l.authForgotTitle,
      children: [
        Text(l.authForgotIntro, style: t.bodyLarge),
        const SizedBox(height: 20),
        Form(
          key: _form,
          child: TextFormField(
            key: const Key('auth-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            validator: (v) => _validateEmail(l, v),
            decoration: InputDecoration(labelText: l.authEmail),
          ),
        ),
        const SizedBox(height: 20),
        _submitButton(
          key: const Key('auth-submit'),
          label: l.authForgotSend,
          busy: _busy,
          onPressed: () => unawaited(_send()),
        ),
        if (_sent) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(l.authForgotSent, key: const Key('auth-sent'), textAlign: TextAlign.center),
          ),
        ],
        if (_error != null) _ErrorText(authErrorText(l, _error!)),
      ],
    );
  }
}

// ---------------------------------------------------------- Revisa tu correo ---

class CheckEmailPage extends ConsumerWidget {
  const CheckEmailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final s = ref.watch(sessionControllerProvider);
    final c = ref.read(sessionControllerProvider.notifier);
    if (s is! AwaitingConfirmation) return const Scaffold();
    return _AuthScaffold(
      title: l.authCheckEmailTitle,
      leading: IconButton(
        tooltip: l.authBack,
        icon: const Icon(Icons.arrow_back),
        onPressed: c.backToStart,
      ),
      children: [
        const Icon(Icons.mark_email_unread_outlined, size: 72, color: IcexColors.primary),
        const SizedBox(height: 20),
        Text(
          l.authCheckEmailBody(s.email),
          key: const Key('check-email-body'),
          textAlign: TextAlign.center,
          style: t.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(l.authCheckEmailSpam, textAlign: TextAlign.center, style: t.bodyMedium),
        const SizedBox(height: 28),
        FilledButton(
          key: const Key('confirmed-sign-in'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () {
            c.backToStart();
            unawaited(context.push('/entrar'));
          },
          child: Text(l.authConfirmedSignIn),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('resend'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: s.resent ? null : () => unawaited(c.resendConfirmation()),
          child: Text(s.resent ? l.authResent : l.authResend),
        ),
        if (s.error != null) _ErrorText(authErrorText(l, s.error!)),
      ],
    );
  }
}

// --------------------------------------------------------- Contraseña nueva ---

class NewPasswordPage extends ConsumerStatefulWidget {
  const NewPasswordPage({super.key});

  @override
  ConsumerState<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends ConsumerState<NewPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _repeat = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    unawaited(ref.read(sessionControllerProvider.notifier).updatePassword(_password.text));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(sessionControllerProvider);
    final busy = s is PasswordRecovery && s.busy;
    final error = s is PasswordRecovery ? s.error : null;
    return _AuthScaffold(
      title: l.authNewPasswordTitle,
      leading: const SizedBox.shrink(),
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PasswordField(
                  fieldKey: const Key('auth-password'),
                  controller: _password,
                  label: l.authPassword,
                  newPassword: true,
                  validator: (v) => _validatePassword(l, v),
                ),
                const SizedBox(height: 16),
                _PasswordField(
                  fieldKey: const Key('auth-password-repeat'),
                  controller: _repeat,
                  label: l.authRepeatPassword,
                  validator: (v) => v == _password.text ? null : l.authPasswordsDontMatch,
                  onSubmitted: _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _submitButton(
          key: const Key('auth-submit'),
          label: l.authNewPasswordButton,
          busy: busy,
          onPressed: _submit,
        ),
        if (error != null) _ErrorText(authErrorText(l, error)),
      ],
    );
  }
}
