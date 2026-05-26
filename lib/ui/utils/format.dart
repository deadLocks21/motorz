import 'package:intl/intl.dart';

final _int = NumberFormat('#,##0');
final _dec1 = NumberFormat('#,##0.0');
final _dec2 = NumberFormat('#,##0.00');

String formatKm(int? km) => km == null ? '—' : '${_int.format(km)} km';
String formatEur(double? v) => v == null ? '—' : '${_dec2.format(v)} €';
String formatLiters(double? v) => v == null ? '—' : '${_dec2.format(v)} L';
String formatConsumption(double? v) => v == null ? '—' : '${_dec1.format(v)} L/100 km';
String formatPricePerLiter(double? v) => v == null ? '—' : '${_dec2.format(v)} €/L';
String formatBar(double? v) => v == null ? '—' : '${_dec1.format(v)} bar';
String formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d.toLocal());
String formatDateTime(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
