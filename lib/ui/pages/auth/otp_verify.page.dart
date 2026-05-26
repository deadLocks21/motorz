import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/session_state.dart';
import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/pages/auth/auth_error_message.dart';
import 'package:motorz/ui/theme/app_colors.dart';

/// Vérification de l'OTP. Sur compte inconnu, la session passe à `Registering`
/// (le router redirige vers l'inscription).
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final state = ref.watch(sessionControllerProvider);
    final phone = state is OtpRequested ? state.phone.e164 : '';

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
                  Text('Envoyé au $phone', style: TextStyle(color: colors.textMuted)),
                  const SizedBox(height: 28),
                  TextField(
                    key: const Key('otpField'),
                    controller: _controller,
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
                  FilledButton(
                    key: const Key('verifyOtpButton'),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Vérifier'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading || phone.isEmpty
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
