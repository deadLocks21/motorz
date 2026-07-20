import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/session_state.dart';
import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/pages/auth/auth_error_message.dart';
import 'package:motorz/ui/theme/app_colors.dart';

/// Vérification de l'OTP : authentifie le compte associé au numéro.
class OtpVerifyPage extends ConsumerStatefulWidget {
  const OtpVerifyPage({super.key});

  @override
  ConsumerState<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends ConsumerState<OtpVerifyPage> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(sessionControllerProvider.notifier).verifyOtp(_controller.text.trim());
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(e.code))));
      }
    } catch (_) {
      // Toute erreur inattendue (ex. persistance de session) doit être visible
      // plutôt que de laisser l'utilisateur bloqué sans retour.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(AuthErrorCode.unknown))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final state = ref.watch(sessionControllerProvider);
    final phone = switch (state) {
      OtpRequested(:final phone) => phone.e164,
      SessionExpired(:final phone) => phone.e164,
      _ => '',
    };
    // Session expirée : le SMS part tout seul, le champ n'a rien à recevoir tant
    // qu'on n'a pas la confirmation d'envoi (passage en `OtpRequested`).
    final expired = state is SessionExpired;
    final resendError = state is SessionExpired ? state.error : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(sessionControllerProvider.notifier).cancel(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Code reçu par SMS', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    expired ? 'Envoi au $phone…' : 'Envoyé au $phone',
                    style: TextStyle(color: colors.textMuted),
                  ),
                  if (_sessionExpiredNotice(state)) ...[
                    const SizedBox(height: 16),
                    _Banner(
                      key: const Key('sessionExpiredBanner'),
                      icon: Icons.lock_clock_outlined,
                      text: resendError != null
                          ? 'Ta session a expiré. ${authErrorMessage(resendError)}'
                          : 'Ta session a expiré, on t\'envoie un nouveau code.',
                    ),
                  ],
                  const SizedBox(height: 28),
                  TextField(
                    key: const Key('otpField'),
                    controller: _controller,
                    enabled: !expired,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, letterSpacing: 8),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  if (resendError != null)
                    FilledButton(
                      key: const Key('retryExpiredOtpButton'),
                      onPressed: () =>
                          ref.read(sessionControllerProvider.notifier).retryExpiredOtp(),
                      child: const Text('Réessayer'),
                    )
                  else
                    FilledButton(
                      key: const Key('verifyOtpButton'),
                      onPressed: _loading || expired ? null : _submit,
                      child: _loading || expired
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Vérifier'),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading || expired || phone.isEmpty
                        ? null
                        : () => ref.read(sessionControllerProvider.notifier).requestOtp(phone),
                    child: const Text('Renvoyer un code'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vrai tant que l'écran doit rappeler *pourquoi* on redemande un code : pendant
/// le renvoi automatique, puis une fois le SMS parti.
bool _sessionExpiredNotice(SessionState state) =>
    state is SessionExpired ||
    (state is OtpRequested && state.reason == OtpReason.sessionExpired);

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Banner({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onAccentSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.onAccentSoft, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
