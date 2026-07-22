import 'package:intl/intl.dart';

final _int = NumberFormat('#,##0', 'fr_FR');
final _dec1 = NumberFormat('#,##0.0', 'fr_FR');
final _dec2 = NumberFormat('#,##0.00', 'fr_FR');

/// Nombre décimal (1 chiffre) au format FR (virgule décimale), sans unité.
String formatDecimal1(double v) => _dec1.format(v);

/// Nombre décimal (2 chiffres) au format FR (virgule décimale), sans unité.
String formatDecimal2(double v) => _dec2.format(v);

String formatKm(int? km) => km == null ? '—' : '${_int.format(km)} km';
String formatEur(double? v) => v == null ? '—' : '${_dec2.format(v)} €';
String formatLiters(double? v) => v == null ? '—' : '${_dec2.format(v)} L';
String formatConsumption(double? v) => v == null ? '—' : '${_dec1.format(v)} L/100 km';
String formatPricePerLiter(double? v) => v == null ? '—' : '${_dec2.format(v)} €/L';
String formatBar(double? v) => v == null ? '—' : '${_dec1.format(v)} bar';
String formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d.toLocal());
/// Mois court pour les axes de graphe (« 07/26 »). Numérique : les libellés
/// littéraux demanderaient `initializeDateFormatting`, non appelé ici.
String formatMonthShort(DateTime d) => DateFormat('MM/yy').format(d.toLocal());
String formatDateOrNull(DateTime? d) => d == null ? '—' : formatDate(d);
String formatDateTime(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
