import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/domain/model/media_item.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';

/// Sélectionne un fichier (photo/PDF) et l'uploade pour [ownerType]/[ownerId].
/// En ligne uniquement (kDrive) ; le média remonte ensuite via la synchro.
Future<void> uploadDocument(
  BuildContext context,
  WidgetRef ref, {
  required String ownerType,
  required String ownerId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'heic', 'pdf'],
    withData: true,
  );
  final file = result?.files.singleOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return;

  final kind = (file.extension?.toLowerCase() == 'pdf') ? 'pdf' : 'photo';
  try {
    final json = await ref.read(mediaRemoteApiProvider).upload(
          ownerType: ownerType,
          ownerId: ownerId,
          kind: kind,
          fileName: file.name,
          bytes: bytes,
        );
    await ref.read(localRecordStoreProvider).put('media', json);
    await ref.read(syncServiceProvider).syncNow();
    messenger.showSnackBar(const SnackBar(content: Text('Document ajouté.')));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Upload impossible (serveur kDrive requis).')),
    );
  }
}

class DocumentsTab extends ConsumerWidget {
  const DocumentsTab({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final media = ref.watch(mediaForOwnerProvider(vehicleId)).value ?? const [];
    final baseUrl = ref.watch(apiBaseUrlProvider);
    final session = ref.watch(currentSessionProvider);
    final headers = session == null
        ? const <String, String>{}
        : {'Authorization': 'Bearer ${session.jwt}', 'X-Device-Id': session.device.id};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Text('Factures, photos, carte grise, attestation… (stockés sur kDrive).',
            style: TextStyle(color: colors.textMuted, fontSize: 13)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => uploadDocument(context, ref, ownerType: 'vehicle', ownerId: vehicleId),
          icon: const Icon(Icons.upload_file),
          label: const Text('Ajouter un document'),
        ),
        const SizedBox(height: 16),
        if (media.isEmpty)
          Text('Aucun document.', style: TextStyle(color: colors.textMuted))
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: media
                .map((m) => _MediaTile(
                      item: m,
                      url: '$baseUrl/media/${m.id.value}',
                      headers: headers,
                      colors: colors,
                      onDelete: () => _delete(ref, m),
                    ))
                .toList(),
          ),
      ],
    );
  }

  Future<void> _delete(WidgetRef ref, MediaItem m) async {
    try {
      await ref.read(mediaRemoteApiProvider).delete(m.id.value);
    } catch (_) {
      // ignore : on pose quand même le tombstone local.
    }
    final tombstoned = {
      ...mediaItemCodec.toJson(m),
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    };
    await ref.read(localRecordStoreProvider).put('media', tombstoned);
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.item,
    required this.url,
    required this.headers,
    required this.colors,
    required this.onDelete,
  });

  final MediaItem item;
  final String url;
  final Map<String, String> headers;
  final AppColors colors;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.isPhoto ? () => _openPhoto(context) : null,
      onLongPress: () => _confirmDelete(context),
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: item.isPhoto
            ? Image.network(
                url,
                headers: headers,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: colors.textMuted),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf_outlined, color: colors.textMuted, size: 32),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      item.originalFilename ?? 'PDF',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textMuted, fontSize: 11),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _openPhoto(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.network(url, headers: headers, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le document ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
