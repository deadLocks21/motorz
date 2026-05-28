import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/due_status.service.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';

/// Ordre des suggestions du champ « Pièce » (`rankDueTitles`) : les intitulés des
/// échéances « À prévoir », dans l'ordre de l'onglet (à réaliser puis prochaines).
void main() {
  final vehicleId = UuidValue.generate();

  // `hasTrigger` dérive de la présence d'un déclencheur km/date (cf. DueInfo).
  DuePlan due(String title, DueStatus status, {bool hasTrigger = true}) => (
        plan: Plan(
          id: UuidValue.generate(),
          vehicleId: vehicleId,
          title: title,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        due: DueInfo(status: status, dueOdometer: hasTrigger ? 100000 : null),
        lastDone: null,
      );

  test('respecte l\'ordre de l\'onglet : « à réaliser » puis « prochaines échéances »', () {
    // [items] arrive déjà trié par urgence (comme `duePlans`). La partition doit
    // remonter la tâche ponctuelle « à venir sans déclencheur » au-dessus des
    // « prochaines échéances » (à venir avec déclencheur), comme dans l'onglet.
    final items = [
      due('Distribution', DueStatus.overdue), // à réaliser
      due('Vidange', DueStatus.dueSoon), // à réaliser
      due('Contrôle technique', DueStatus.upcoming, hasTrigger: false), // à réaliser (sans déclencheur)
      due('Révision 30000', DueStatus.upcoming), // prochaines échéances
    ];
    expect(
      rankDueTitles(items),
      ['Distribution', 'Vidange', 'Contrôle technique', 'Révision 30000'],
    );
  });

  test('dédoublonne sans tenir compte de la casse, garde la 1ʳᵉ orthographe vue', () {
    expect(
      rankDueTitles([
        due('Vidange', DueStatus.overdue),
        due('vidange', DueStatus.dueSoon),
        due('VIDANGE', DueStatus.upcoming),
      ]),
      ['Vidange'],
    );
  });

  test('liste vide quand rien n\'est à prévoir', () {
    expect(rankDueTitles(const []), isEmpty);
  });
}
