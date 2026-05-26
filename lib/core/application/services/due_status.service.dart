import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/maintenance_task.dart';

/// Échéance calculée d'une tâche : statut + temps/km restants.
class DueInfo {
  final DueStatus status;
  final int? remainingKm;
  final int? remainingDays;
  final int? dueOdometer;
  final DateTime? dueDate;

  const DueInfo({
    required this.status,
    this.remainingKm,
    this.remainingDays,
    this.dueOdometer,
    this.dueDate,
  });

  bool get hasTrigger => dueOdometer != null || dueDate != null;
}

/// Calcul d'échéance — local, sans réseau (cf. indicateurs in-app §5.10).
abstract final class DueStatusService {
  static const kmSoonThreshold = 1000;
  static const daysSoonThreshold = 30;

  static DateTime _addMonths(DateTime d, int months) {
    final totalMonth = d.month - 1 + months;
    final year = d.year + totalMonth ~/ 12;
    final month = totalMonth % 12 + 1;
    final day = d.day.clamp(1, _daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  static int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  static DueInfo compute(MaintenanceTask task, {int? currentOdometer, DateTime? now}) {
    final ref = now ?? DateTime.now();

    int? dueOdometer = task.dueOdometer;
    DateTime? dueDate = _parseDate(task.dueDate);

    // Périodique : prochaine échéance depuis la dernière réalisation.
    if (task.kind == TaskKind.periodic) {
      if (task.intervalKm != null && task.lastDoneOdometer != null) {
        dueOdometer = task.lastDoneOdometer! + task.intervalKm!;
      }
      if (task.intervalMonths != null) {
        final base = _parseDate(task.lastDoneDate) ?? ref;
        dueDate = _addMonths(base, task.intervalMonths!);
      }
    }

    final remainingKm =
        (dueOdometer != null && currentOdometer != null) ? dueOdometer - currentOdometer : null;
    final remainingDays = dueDate?.difference(ref).inDays;

    final overdue = (remainingKm != null && remainingKm <= 0) ||
        (remainingDays != null && remainingDays < 0);
    final soon = (remainingKm != null && remainingKm <= kmSoonThreshold) ||
        (remainingDays != null && remainingDays <= daysSoonThreshold);

    final status = overdue
        ? DueStatus.overdue
        : (soon ? DueStatus.dueSoon : DueStatus.upcoming);

    return DueInfo(
      status: status,
      remainingKm: remainingKm,
      remainingDays: remainingDays,
      dueOdometer: dueOdometer,
      dueDate: dueDate,
    );
  }

  static DateTime? _parseDate(String? s) => s == null ? null : DateTime.tryParse(s);
}
