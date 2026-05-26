import 'package:motorz/core/domain/model/enums.dart';

/// Modèle d'échéance préconfiguré (bibliothèque §5.6), activable en un clic.
class TaskTemplate {
  final String title;
  final TaskKind kind;
  final String? category;
  final int? intervalKm;
  final int? intervalMonths;

  const TaskTemplate(
    this.title,
    this.kind, {
    this.category,
    this.intervalKm,
    this.intervalMonths,
  });
}

/// Bibliothèque d'échéances types (vidange, filtres, freins, distribution, CT…).
const maintenanceTaskTemplates = <TaskTemplate>[
  TaskTemplate('Vidange', TaskKind.periodic, category: 'vidange', intervalKm: 15000, intervalMonths: 12),
  TaskTemplate('Filtre à air', TaskKind.periodic, category: 'filtres', intervalKm: 30000),
  TaskTemplate('Filtre habitacle', TaskKind.periodic, category: 'filtres', intervalMonths: 12),
  TaskTemplate('Plaquettes de frein', TaskKind.periodic, category: 'freins', intervalKm: 40000),
  TaskTemplate('Distribution', TaskKind.periodic, category: 'distribution', intervalKm: 100000, intervalMonths: 120),
  TaskTemplate('Pneumatiques', TaskKind.periodic, category: 'pneumatiques', intervalKm: 40000),
  TaskTemplate('Contrôle technique', TaskKind.controleTechnique, category: 'controle_technique', intervalMonths: 24),
];
