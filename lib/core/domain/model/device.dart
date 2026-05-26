/// Appareil connu de l'utilisateur. `id` = UUID v4 généré au premier lancement
/// et persisté ; envoyé en `X-Device-Id` sur chaque requête authentifiée.
class Device {
  final String id;
  final String? name;

  const Device({required this.id, this.name});

  Device copyWith({String? id, String? name}) => Device(id: id ?? this.id, name: name ?? this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device && runtimeType == other.runtimeType && id == other.id && name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}
