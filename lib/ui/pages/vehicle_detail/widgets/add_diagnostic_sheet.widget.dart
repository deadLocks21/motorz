import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/battery_report.service.dart';
import 'package:motorz/core/application/services/diagnostic_report.service.dart';
import 'package:motorz/core/domain/model/diagnostic_code.dart';
import 'package:motorz/core/domain/model/diagnostic_session.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';

/// Crée ou édite une session de diagnostic (§5.11).
///
/// Trois entrées : **coller le rapport** d'une valise (analysé sur l'appareil,
/// hors-ligne), **coller le lien** d'un testeur de batterie (décodé localement,
/// sans appeler le site), ou tout **saisir à la main**. Dans les deux premiers
/// cas l'analyse ne fait que **pré-remplir** — c'est l'utilisateur qui valide.
Future<void> showDiagnosticSheet(
  BuildContext context,
  WidgetRef ref, {
  required String vehicleId,
  int? lastOdometer,
  DiagnosticSession? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DiagnosticSheet(
      vehicleId: vehicleId,
      lastOdometer: lastOdometer,
      existing: existing,
    ),
  );
}

class _DiagnosticSheet extends ConsumerStatefulWidget {
  const _DiagnosticSheet({required this.vehicleId, this.lastOdometer, this.existing});
  final String vehicleId;
  final int? lastOdometer;
  final DiagnosticSession? existing;

  @override
  ConsumerState<_DiagnosticSheet> createState() => _DiagnosticSheetState();
}

class _DiagnosticSheetState extends ConsumerState<_DiagnosticSheet> {
  late final TextEditingController _odometer;
  late final TextEditingController _tool;
  late final TextEditingController _profile;
  late final TextEditingController _summary;
  late final TextEditingController _notes;
  late final TextEditingController _report;
  late final TextEditingController _link;

  late DiagnosticType _type;
  late DateTime _date;
  bool _saving = false;

  /// Analyse du rapport collé, en attente de validation.
  ParsedReport? _parsed;

  /// Mesures décodées du lien, en attente de validation.
  BatteryReport? _battery;
  String? _analysisError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? DiagnosticType.obd;
    _date = e?.date ?? DateTime.now();
    _odometer = TextEditingController(
      text: (e?.odometer ?? widget.lastOdometer)?.toString() ?? '',
    );
    _tool = TextEditingController(text: e?.tool ?? '');
    _profile = TextEditingController(text: e?.connectionProfile ?? '');
    _summary = TextEditingController(text: e?.summary ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _report = TextEditingController(text: e?.rawText ?? '');
    _link = TextEditingController(text: e?.sourceUrl ?? '');
  }

  @override
  void dispose() {
    for (final c in [_odometer, _tool, _profile, _summary, _notes, _report, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Analyse le rapport collé et pré-remplit — sans rien enregistrer.
  void _analyzeReport() {
    final raw = _report.text.trim();
    if (raw.isEmpty) return;
    final parsed = DiagnosticReportParser.parse(raw);
    setState(() {
      _parsed = parsed;
      _analysisError = parsed.isEmpty ? 'Aucun code défaut reconnu dans ce rapport.' : null;
      if (parsed.tool != null && _tool.text.trim().isEmpty) _tool.text = parsed.tool!;
      if (parsed.connectionProfile != null && _profile.text.trim().isEmpty) {
        _profile.text = parsed.connectionProfile!;
      }
      if (parsed.date != null) _date = parsed.date!;
    });
  }

  /// Décode le lien du testeur — localement, sans appeler le site.
  void _decodeLink() {
    final url = _link.text.trim();
    if (url.isEmpty) return;
    final report = BatteryLinkDecoder.decode(url);
    setState(() {
      _battery = report;
      _analysisError = report == null
          ? 'Lien non reconnu. Il sera conservé tel quel — saisis les mesures à la main.'
          : null;
      if (report != null) {
        _type = DiagnosticType.battery;
        if (report.result != null && _summary.text.trim().isEmpty) {
          _summary.text = report.result!;
        }
      }
    });
  }

  DiagnosticSource _resolveSource() {
    if (_link.text.trim().isNotEmpty) return DiagnosticSource.link;
    if (_report.text.trim().isNotEmpty) return DiagnosticSource.pasted;
    return widget.existing?.source ?? DiagnosticSource.manual;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final e = widget.existing;
    final now = DateTime.now().toUtc();
    final parsed = _parsed;
    final link = _link.text.trim();
    final raw = _report.text.trim();

    final session = DiagnosticSession(
      id: e?.id ?? UuidValue.generate(),
      vehicleId: UuidValue.parse(widget.vehicleId),
      createdByUserId: e?.createdByUserId,
      date: _date,
      odometer: int.tryParse(_odometer.text.trim()),
      type: _type,
      tool: _emptyToNull(_tool.text),
      connectionProfile: _emptyToNull(_profile.text),
      source: _resolveSource(),
      sourceUrl: link.isEmpty ? null : link,
      rawText: raw.isEmpty ? null : raw,
      // Analysé = on a dépouillé le rapport. Un rapport collé sans analyse
      // reste « à analyser » : c'est ce qui le distingue d'un diagnostic
      // analysé sans le moindre défaut.
      analyzedAt: (parsed != null || _battery != null) ? now : e?.analyzedAt,
      summary: _emptyToNull(_summary.text),
      measurements: _battery?.measurements ?? e?.measurements,
      modulesScanned: parsed?.modules ?? e?.modulesScanned ?? const [],
      notes: _emptyToNull(_notes.text),
      updatedAt: now,
    );

    await ref.read(diagnosticSessionRepositoryProvider).save(session);

    // Les codes analysés remplacent ceux de la session : ré-analyser un rapport
    // ne doit pas empiler deux fois les mêmes défauts.
    if (parsed != null) {
      final repo = ref.read(diagnosticCodeRepositoryProvider);
      if (e != null) {
        final previous = (await repo.listAll()).where((c) => c.sessionId == session.id);
        for (final old in previous) {
          await repo.delete(old);
        }
      }
      for (final c in parsed.codes) {
        await repo.save(DiagnosticCode(
          id: UuidValue.generate(),
          sessionId: session.id,
          code: c.code,
          module: c.module,
          description: c.description,
          status: c.status,
          rawStatus: c.rawStatus,
          updatedAt: now,
        ));
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final repo = ref.read(diagnosticCodeRepositoryProvider);
    final codes = (await repo.listAll()).where((c) => c.sessionId == e.id);
    for (final c in codes) {
      await repo.delete(c);
    }
    await ref.read(diagnosticSessionRepositoryProvider).delete(e);
    if (mounted) Navigator.of(context).pop();
  }

  static String? _emptyToNull(String v) => v.trim().isEmpty ? null : v.trim();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.existing != null;
    final parsed = _parsed;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isEdit ? 'Modifier le diagnostic' : 'Nouveau diagnostic',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<DiagnosticType>(
              segments: const [
                ButtonSegment(
                  value: DiagnosticType.obd,
                  label: Text('OBD'),
                  icon: Icon(Icons.troubleshoot),
                ),
                ButtonSegment(
                  value: DiagnosticType.battery,
                  label: Text('Batterie'),
                  icon: Icon(Icons.battery_charging_full),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text('${_date.day}/${_date.month}/${_date.year}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _odometer,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Km', suffixText: 'km'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Un rapport OBD ne porte pas le kilométrage : il est proposé au dernier connu.',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            if (_type == DiagnosticType.obd) ..._obdFields(colors) else ..._batteryFields(colors),
            if (_analysisError != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: colors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_analysisError!,
                        style: TextStyle(color: colors.textMuted, fontSize: 12.5)),
                  ),
                ],
              ),
            ],
            if (parsed != null && !parsed.isEmpty) ...[
              const SizedBox(height: 12),
              _ParsedPreview(report: parsed, colors: colors),
            ],
            if (_battery != null) ...[
              const SizedBox(height: 12),
              _MeasurementsPreview(measurements: _battery!.measurements, colors: colors),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('saveDiagnosticButton'),
              onPressed: _saving ? null : _save,
              child: const Text('Enregistrer'),
            ),
            if (isEdit) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _obdFields(AppColors colors) => [
        TextField(
          key: const Key('diagnosticReportField'),
          controller: _report,
          maxLines: 6,
          minLines: 3,
          decoration: InputDecoration(
            labelText: 'Rapport de la valise',
            hintText: 'Colle ici le rapport partagé par ton scanner…',
            alignLabelWithHint: true,
            suffixIcon: IconButton(
              tooltip: 'Coller',
              icon: const Icon(Icons.content_paste),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final text = data?.text;
                if (text == null || text.trim().isEmpty) return;
                _report.text = text;
                _analyzeReport();
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('analyzeReportButton'),
          onPressed: _analyzeReport,
          icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
          label: const Text('Analyser le rapport'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tool,
          decoration: const InputDecoration(
            labelText: 'Outil',
            hintText: 'Car Scanner ELM OBD2…',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _profile,
          decoration: const InputDecoration(
            labelText: 'Profil de connexion',
            hintText: 'Citroen OBD-II / EOBD…',
          ),
        ),
      ];

  List<Widget> _batteryFields(AppColors colors) => [
        TextField(
          key: const Key('batteryLinkField'),
          controller: _link,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'Lien du rapport',
            hintText: 'https://…',
            suffixIcon: IconButton(
              tooltip: 'Coller',
              icon: const Icon(Icons.content_paste),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final text = data?.text;
                if (text == null || text.trim().isEmpty) return;
                _link.text = text.trim();
                _decodeLink();
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Le lien porte les mesures : elles sont décodées sur l\'appareil, sans '
          'ouvrir le site, puis conservées dans le carnet.',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('decodeLinkButton'),
          onPressed: _decodeLink,
          icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
          label: const Text('Décoder le lien'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _summary,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Verdict',
            hintText: 'Bonne batterie, à remplacer…',
          ),
        ),
      ];
}

/// Ce que l'analyse propose d'enregistrer — relu avant validation.
class _ParsedPreview extends StatelessWidget {
  const _ParsedPreview({required this.report, required this.colors});
  final ParsedReport report;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final distinct = report.distinctCodes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${distinct.length} défaut${distinct.length > 1 ? 's' : ''} '
              '· ${report.modules.length} calculateur${report.modules.length > 1 ? 's' : ''} lu'
              '${report.modules.length > 1 ? 's' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (report.usedFallback)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Format non reconnu : seuls les codes ont pu être lus.',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final code in distinct)
                  Chip(
                    label: Text(code),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Mesures décodées d'un test de batterie.
class _MeasurementsPreview extends StatelessWidget {
  const _MeasurementsPreview({required this.measurements, required this.colors});
  final Map<String, dynamic> measurements;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in measurements.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(batteryMeasurementLabel(entry.key),
                        style: TextStyle(color: colors.textMuted, fontSize: 13)),
                    Text(formatBatteryMeasurement(entry.key, entry.value),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Libellé lisible d'une mesure de testeur (clés de `measurements`).
String batteryMeasurementLabel(String key) => switch (key) {
      'battery_type' => 'Type de batterie',
      'rated' => 'Capacité évaluée',
      'measured' => 'Capacité mesurée',
      'voltage' => 'Tension',
      'standard' => 'Standard',
      'result' => 'Verdict',
      'soc' => 'État de charge (SoC)',
      'soh' => 'État de santé (SoH)',
      'internal_mohm' => 'Résistivité',
      'vehicle_type' => 'Type de véhicule',
      'cranking_voltage' => 'Tension au démarrage',
      'cranking_ms' => 'Durée de démarrage',
      'cranking_result' => 'Verdict démarreur',
      'charging_loaded_voltage' => 'Tension avec charge',
      'charging_unloaded_voltage' => 'Tension sans charge',
      'ripple' => 'Ondulation',
      'charging_result' => 'Verdict de charge',
      _ => key,
    };

/// Valeur formatée avec son unité, d'après la clé.
String formatBatteryMeasurement(String key, Object? value) {
  if (value == null) return '—';
  return switch (key) {
    'voltage' ||
    'cranking_voltage' ||
    'charging_loaded_voltage' ||
    'charging_unloaded_voltage' =>
      '$value V',
    'rated' || 'measured' => '$value A',
    'soc' || 'soh' => '$value %',
    'internal_mohm' => '$value mΩ',
    'cranking_ms' => '$value ms',
    _ => '$value',
  };
}
