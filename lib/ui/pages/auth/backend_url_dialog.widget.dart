import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/infrastructure/http/api_endpoint_probe.dart';
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

  /// Sondage en cours : le dialogue attend le serveur, on ne le laisse pas
  /// enregistrer deux fois.
  bool _checking = false;

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

  /// Enregistre l'URL — après avoir vérifié que l'API répond bien au bout, et
  /// en corrigeant le tir quand elle répond ailleurs sur le même hôte.
  ///
  /// Sans cette vérification, une URL fausse s'enregistre en silence et ne se
  /// manifeste qu'au premier appel réel, déguisée en panne réseau : c'est
  /// exactement ainsi que l'hôte nu (`https://…`, sans le `/api` qu'exige le
  /// découpage Traefik) a survécu à un déploiement.
  ///
  /// Un serveur muet n'empêche pas d'enregistrer : on peut vouloir configurer
  /// un backend momentanément éteint. On le dit, c'est tout.
  Future<void> _save() async {
    final input = ApiBaseUrl.normalize(_apiUrl.text);
    if (isMemoryMode(input)) return _commit(input, 'Mode local activé.');

    setState(() => _checking = true);
    final resolution = await ref.read(apiEndpointProbeProvider).resolve(input);
    if (!mounted) return;
    setState(() => _checking = false);

    if (resolution.corrected) {
      final url = resolution.workingBaseUrl!;
      return _commit(url, 'Serveur enregistré : l\'API répond sur $url.');
    }
    return switch (resolution.status) {
      ApiEndpointStatus.reachable => _commit(input, 'Serveur enregistré.'),
      ApiEndpointStatus.notApi => _commit(
          input,
          'Enregistré, mais ce serveur ne répond pas comme l\'API Motorz.',
        ),
      ApiEndpointStatus.unreachable => _commit(
          input,
          'Enregistré, mais ce serveur est injoignable.',
        ),
    };
  }

  Future<void> _commit(String url, String message) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(apiBaseUrlProvider.notifier).update(url);
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
            enabled: !_checking,
            onSubmitted: (_) => _save(),
          ),
          if (_checking) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Vérification du serveur…',
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('saveApiBaseUrlButton'),
          onPressed: _checking ? null : _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
