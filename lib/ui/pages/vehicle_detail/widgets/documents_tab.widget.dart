import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/domain/model/media_category.dart';
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
  final suggestion = MediaCategory.suggestion(ownerType: ownerType, kind: kind);
  // Contexte typé (entretien, devis…) : la nature est évidente, on classe
  // direct. Onglet Documents du véhicule : ambigu (carte grise / assurance /
  // photo…), on demande.
  MediaCategory category;
  if (_promptsCategory(ownerType)) {
    if (!context.mounted) return;
    final picked = await _pickCategory(context, suggestion);
    if (picked == null) return; // annulé
    category = picked;
  } else {
    category = suggestion;
  }

  try {
    final json = await ref.read(mediaRemoteApiProvider).upload(
          ownerType: ownerType,
          ownerId: ownerId,
          kind: kind,
          category: category.value,
          fileName: file.name,
          bytes: bytes,
        );
    await ref.read(localRecordStoreProvider).put('media', json);
    await ref.read(syncServiceProvider).syncNow();
    // Surface le tag posé quand il a été déduit sans demander.
    final msg = _promptsCategory(ownerType)
        ? 'Document ajouté.'
        : 'Document ajouté (${category.label}).';
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Upload impossible (serveur kDrive requis).')),
    );
  }
}

/// Seul l'onglet Documents du véhicule est ambigu et demande la nature ; les
/// cibles typées (opération, devis, plein) la déduisent (cf. [MediaCategory.suggestion]).
bool _promptsCategory(String ownerType) => ownerType == 'vehicle';

/// Demande la nature du document (cf. [MediaCategory]) avant l'upload.
/// Renvoie `null` si l'utilisateur ferme la feuille sans choisir.
Future<MediaCategory?> _pickCategory(BuildContext context, MediaCategory suggested) {
  return showModalBottomSheet<MediaCategory>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final colors = ctx.appColors;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Type de document',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final c in MediaCategory.values)
              ListTile(
                leading: Icon(c.icon,
                    color: c == suggested ? colors.accent : colors.textMuted),
                title: Text(c.label),
                trailing: c == suggested
                    ? Icon(Icons.star_rounded, size: 18, color: colors.accent)
                    : null,
                onTap: () => Navigator.of(ctx).pop(c),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class DocumentsTab extends ConsumerWidget {
  const DocumentsTab({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Text(
            'Factures, photos, carte grise, attestation, documentation technique… '
            '(stockés sur kDrive).',
            style: TextStyle(color: colors.textMuted, fontSize: 13)),
        const SizedBox(height: 12),
        MediaGrid(ownerType: 'vehicle', ownerId: vehicleId),
      ],
    );
  }
}

/// Grille de documents (photos/PDF) d'une cible polymorphe ([ownerType]/[ownerId]) :
/// bouton d'ajout + vignettes + suppression. Réutilisée pour le véhicule (onglet
/// Docs) et pour une opération d'entretien (factures).
class MediaGrid extends ConsumerWidget {
  const MediaGrid({super.key, required this.ownerType, required this.ownerId});
  final String ownerType;
  final String ownerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final media = ref.watch(mediaForOwnerProvider(ownerId)).value ?? const [];
    final baseUrl = ref.watch(apiBaseUrlProvider);
    final session = ref.watch(currentSessionProvider);
    final headers = session == null
        ? const <String, String>{}
        : {'Authorization': 'Bearer ${session.jwt}', 'X-Device-Id': session.device.id};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => uploadDocument(context, ref, ownerType: ownerType, ownerId: ownerId),
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
                      onOpenPdf: () => _openPdf(context, ref, m),
                    ))
                .toList(),
          ),
      ],
    );
  }

  /// Ouvre la visionneuse PDF intégrée immédiatement ; le téléchargement des
  /// octets (proxy authentifié) se fait dans la page avec un loader.
  void _openPdf(BuildContext context, WidgetRef ref, MediaItem m) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PdfViewerPage(
          title: m.originalFilename ?? 'Document',
          bytesFuture: ref.read(mediaRemoteApiProvider).download(m.id.value),
        ),
      ),
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
    required this.onOpenPdf,
  });

  final MediaItem item;
  final String url;
  final Map<String, String> headers;
  final AppColors colors;
  final VoidCallback onDelete;
  final VoidCallback onOpenPdf;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.isPhoto ? () => _openPhoto(context) : onOpenPdf,
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.isPhoto)
              Image.network(
                url,
                headers: headers,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: colors.textMuted),
              )
            else
              Column(
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
            _categoryBadge(),
          ],
        ),
      ),
    );
  }

  /// Pastille de nature documentaire en haut à gauche ; masquée si non classé.
  Widget _categoryBadge() {
    final category = MediaCategory.fromValue(item.category);
    if (category == MediaCategory.uncategorized) return const SizedBox.shrink();
    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Tooltip(
          message: category.label,
          child: Icon(category.icon, size: 16, color: Colors.white),
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

/// Visionneuse PDF intégrée (rendu Flutter via pdfx) — multipage, zoom.
/// Ouvre immédiatement et affiche un loader pendant le téléchargement des octets.
class _PdfViewerPage extends StatefulWidget {
  const _PdfViewerPage({required this.title, required this.bytesFuture});
  final String title;
  final Future<Uint8List> bytesFuture;

  @override
  State<_PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<_PdfViewerPage> {
  PdfControllerPinch? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<Uint8List>(
        future: widget.bytesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Impossible d\'ouvrir le document.'));
          }
          _controller ??= PdfControllerPinch(
            document: PdfDocument.openData(snapshot.data!),
          );
          return PdfViewPinch(controller: _controller!);
        },
      ),
    );
  }
}
