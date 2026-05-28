import 'package:motorz/core/domain/model/uuid_value.dart';

/// Métadonnée d'un document (photo/PDF). Les octets vivent dans kDrive ;
/// l'app affiche via le proxy authentifié `/media/:id`.
class MediaItem {
  final UuidValue id;
  final String ownerType; // vehicle | fuel_entry | maintenance_operation | maintenance_quote
  final UuidValue ownerId;
  final String kind; // photo | pdf
  final String? contentType;
  final String? originalFilename;
  final int? fileSize;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  MediaItem({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.kind,
    required this.updatedAt,
    this.contentType,
    this.originalFilename,
    this.fileSize,
    this.deletedAt,
  });

  bool get isPhoto => kind == 'photo';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
