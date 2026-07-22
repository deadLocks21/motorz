import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';

/// Dialogue de configuration de l'URL du backend, accessible depuis l'écran de
/// connexion (roue crantée). C'est le **seul** endroit où on règle le serveur :
/// une fois connecté, on ne change plus de backend.
Future<void> showBackendUrlDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _BackendUrlDialog(),
  );
}

class _BackendUrlDialog extends ConsumerStatefulWidget {
  const _BackendUrlDialog();

  @override
  ConsumerState<_BackendUrlDialog> createState() => _BackendUrlDialogState();
}

class _BackendUrlDialogState extends ConsumerState<_BackendUrlDialog> {
  late final TextEditingController _apiUrl;

  @override
  void initState() {
    super.initState();
    _apiUrl = TextEditingController(text: ref.read(apiBaseUrlProvider));
  }

  @override
  void dispose() {
    _apiUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(apiBaseUrlProvider.notifier).update(_apiUrl.text.trim());
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Serveur enregistré.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AlertDialog(
      title: const Text('Serveur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'URL de l\'API self-hosted, préfixe de chemin compris. '
            '« memory » = mode local sans serveur.',
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('apiBaseUrlField'),
            controller: _apiUrl,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'API_BASE_URL',
              // Depuis que le client web occupe l'hôte en catch-all, l'API
              // n'est plus servie qu'à `/api` (StripPrefix Traefik, cf. README).
              // Sans ce suffixe, tout part chez nginx : `POST /auth/request-otp`
              // → 405, `GET /sync/changes` → la SPA en 200 text/html. La
              // connexion et la synchro échouent alors ensemble, sans que rien
              // n'indique que c'est le réglage qui est périmé.
              hintText: 'https://motorz.dtfh.fr/api',
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('saveApiBaseUrlButton'),
          onPressed: _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
