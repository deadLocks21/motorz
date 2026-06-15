import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/tire.dart';
import 'package:motorz/core/domain/model/tire_mount.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Pneu monté à une position, avec son intervalle ouvert et ses km roulés dérivés.
typedef MountedTire = ({Tire tire, TireMount mount, int? kmRolled});

/// Dérivations du parc de pneus — faites **localement** (offline-first) à partir
/// de l'inventaire ([Tire]) et du journal de montages ([TireMount]). La position
/// courante et les km roulés ne sont jamais stockés : ils se calculent ici.
abstract final class TireService {
  /// Intervalle ouvert d'un pneu (s'il est monté quelque part), sinon null.
  static TireMount? currentMountFor(String tireId, List<TireMount> mounts) {
    for (final m in mounts) {
      if (m.isOpen && m.tireId.value == tireId) return m;
    }
    return null;
  }

  /// Intervalle ouvert occupant une position, sinon null.
  static TireMount? mountAtPosition(String position, List<TireMount> mounts) {
    for (final m in mounts) {
      if (m.isOpen && m.position == position) return m;
    }
    return null;
  }

  /// IDs des pneus actuellement montés (intervalle ouvert) — le complément est
  /// « en stock ».
  static Set<String> mountedTireIds(List<TireMount> mounts) =>
      {for (final m in mounts) if (m.isOpen) m.tireId.value};

  /// Km roulés par un pneu = somme, sur ses intervalles non supprimés, de
  /// `(fin − début)` où `fin` = km de démontage, ou le km courant si encore
  /// monté. Les intervalles à la **roue de secours** (`SEC`) ne comptent pas (la
  /// galette ne roule pas), de même que ceux sans borne de fin connue (pneu monté
  /// + km courant inconnu). Renvoie null si aucun intervalle exploitable.
  static int? kmRolled(String tireId, List<TireMount> mounts, int? currentOdometer) {
    var total = 0;
    var counted = false;
    for (final m in mounts) {
      if (m.deletedAt != null || m.tireId.value != tireId) continue;
      if (m.position == spareWheelPosition) continue;
      final end = m.dismountedOdometer ?? currentOdometer;
      if (end == null) continue;
      final span = end - m.mountedOdometer;
      if (span > 0) total += span;
      counted = true;
    }
    return counted ? total : null;
  }

  /// Pneu monté à chaque position (intervalle ouvert), indexé par position.
  static Map<String, MountedTire> mountedByPosition(
    List<Tire> tires,
    List<TireMount> mounts,
    int? currentOdometer,
  ) {
    final tireById = {for (final t in tires) t.id.value: t};
    final result = <String, MountedTire>{};
    for (final m in mounts) {
      if (!m.isOpen) continue;
      final tire = tireById[m.tireId.value];
      if (tire == null) continue;
      result[m.position] = (
        tire: tire,
        mount: m,
        kmRolled: kmRolled(tire.id.value, mounts, currentOdometer),
      );
    }
    return result;
  }

  /// Écritures à persister pour **monter** [tireId] en [position] à l'odomètre
  /// [odometer] (date [date], `YYYY-MM-DD`). Ferme l'intervalle ouvert qui
  /// occupait la position (pneu sortant → stock) et celui du pneu s'il était
  /// monté ailleurs, puis ouvre un nouvel intervalle. Liste vide si le pneu est
  /// déjà monté à cette position (no-op).
  static List<TireMount> planMount({
    required UuidValue vehicleId,
    required String tireId,
    required String position,
    required int odometer,
    String? date,
    required List<TireMount> mounts,
    required DateTime now,
  }) {
    final existingAtPosition = mountAtPosition(position, mounts);
    if (existingAtPosition != null && existingAtPosition.tireId.value == tireId) {
      return const [];
    }
    final writes = <TireMount>[];
    // 1. Libère la position (pneu sortant → stock).
    if (existingAtPosition != null) {
      writes.add(_close(existingAtPosition, odometer, date, now));
    }
    // 2. Démonte le pneu de son ancienne position s'il était monté ailleurs.
    final tireOpen = currentMountFor(tireId, mounts);
    if (tireOpen != null && tireOpen.position != position) {
      writes.add(_close(tireOpen, odometer, date, now));
    }
    // 3. Ouvre le nouvel intervalle.
    writes.add(TireMount(
      id: UuidValue.generate(),
      vehicleId: vehicleId,
      tireId: UuidValue.parse(tireId),
      position: position,
      mountedOdometer: odometer,
      mountedDate: date,
      updatedAt: now,
    ));
    return writes;
  }

  /// Écriture pour **démonter** le pneu occupant [position] (→ stock). Liste vide
  /// si rien n'y est monté.
  static List<TireMount> planDismount({
    required String position,
    required int odometer,
    String? date,
    required List<TireMount> mounts,
    required DateTime now,
  }) {
    final open = mountAtPosition(position, mounts);
    if (open == null) return const [];
    return [_close(open, odometer, date, now)];
  }

  /// Ferme un intervalle (pose la borne de démontage), id et bornes de montage
  /// préservés (LWW par `updated_at`).
  static TireMount _close(TireMount m, int odometer, String? date, DateTime now) => TireMount(
    id: m.id,
    vehicleId: m.vehicleId,
    tireId: m.tireId,
    position: m.position,
    mountedOdometer: m.mountedOdometer,
    mountedDate: m.mountedDate,
    dismountedOdometer: odometer,
    dismountedDate: date,
    updatedAt: now,
  );
}
