import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/domain/model/app_theme_mode.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/providers/theme_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final session = ref.watch(currentSessionProvider);
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? AppThemeMode.system;

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (session != null)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colors.accentSoft,
                  child: Text(
                    session.user.initials,
                    style: TextStyle(
                      color: colors.onAccentSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(session.user.fullName),
                subtitle: Text(session.user.phoneNumber),
              ),
            ),
          const SizedBox(height: 24),
          Text('Apparence', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<AppThemeMode>(
            segments: const [
              ButtonSegment(value: AppThemeMode.system, label: Text('Système')),
              ButtonSegment(value: AppThemeMode.light, label: Text('Clair')),
              ButtonSegment(value: AppThemeMode.dark, label: Text('Sombre')),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) =>
                ref.read(themeModeControllerProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
