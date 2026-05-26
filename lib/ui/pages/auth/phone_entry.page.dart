import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/pages/auth/auth_error_message.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/widgets/motorz_wordmark.widget.dart';

/// Saisie du numéro de téléphone → demande d'OTP (self-service).
class PhoneEntryPage extends ConsumerStatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  ConsumerState<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends ConsumerState<PhoneEntryPage> {
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
      await ref.read(sessionControllerProvider.notifier).requestOtp(_controller.text);
      // La redirection vers l'écran OTP est pilotée par le router.
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
    return Scaffold(
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
                  const Center(child: MotorzWordmark(fontSize: 52)),
                  const SizedBox(height: 8),
                  Text(
                    'Le carnet de bord de tes véhicules.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textMuted, fontSize: 15),
                  ),
                  const SizedBox(height: 40),
                  Text('Ton numéro de mobile', style: TextStyle(color: colors.textMuted)),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('phoneField'),
                    controller: _controller,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
                    decoration: const InputDecoration(hintText: '06 12 34 56 78'),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'On t\'envoie un code par SMS. Si tu n\'as pas de compte, '
                    'il est créé automatiquement.',
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('requestOtpButton'),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Recevoir le code'),
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
