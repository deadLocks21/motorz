import 'dart:io';

import 'package:path/path.dart' as p;

import 'layout.dart';
import 'log.dart';

/// Crée le(s) raccourci(s) « point d'entrée stable » qui lancent l'updater en
/// mode `--launch` (check + MAJ silencieuse + démarrage de l'app).
///
/// Le raccourci ne pointe JAMAIS sur un exe versionné : il passe par l'updater
/// relocalisé sous `<root>/updater/`, donc il ne casse jamais d'une version à
/// l'autre.
void createShortcuts(Layout layout, Log log) {
  if (Platform.isWindows) {
    _createWindowsShortcuts(layout, log);
  } else {
    _createLinuxDesktopEntry(layout, log);
  }
}

// ── Windows ─────────────────────────────────────────────────────────────────

void _createWindowsShortcuts(Layout layout, Log log) {
  // Wrapper VBS : lance l'updater fenêtre cachée (window style 0) -> aucun
  // terminal au démarrage. `--ui` : si (et seulement si) une MAJ est trouvée,
  // l'updater affiche lui-même une fenêtre de progression native.
  final vbs =
      '''
Set shell = CreateObject("WScript.Shell")
shell.Run """${layout.updaterExe}"" --launch --ui", 0, False
''';
  File(layout.launchVbs).writeAsStringSync(vbs);

  final ps = r'''
param($vbs, $iconExe, $workDir)
$shell = New-Object -ComObject WScript.Shell
foreach ($dir in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
  $lnk = $shell.CreateShortcut((Join-Path $dir 'Motorz.lnk'))
  $lnk.TargetPath = 'wscript.exe'
  $lnk.Arguments = '"' + $vbs + '"'
  $lnk.IconLocation = $iconExe + ',0'
  $lnk.WorkingDirectory = $workDir
  $lnk.Description = 'Motorz'
  $lnk.Save()
}
''';
  final psFile = File(p.join(layout.root, '_mkshortcut.ps1'))
    ..writeAsStringSync(ps);
  try {
    final r = Process.runSync('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      psFile.path,
      layout.launchVbs,
      layout.appExecutable, // current\motorz.exe -> icône
      layout.root,
    ]);
    if (r.exitCode != 0) {
      log.error('Création des raccourcis Windows', r.stderr);
    } else {
      log('Raccourcis créés (Bureau + Menu Démarrer)');
    }
  } finally {
    if (psFile.existsSync()) psFile.deleteSync();
  }
}

// ── Linux ───────────────────────────────────────────────────────────────────

void _createLinuxDesktopEntry(Layout layout, Log log) {
  final home = Platform.environment['HOME'] ?? '.';
  final appsDir = Directory(p.join(home, '.local', 'share', 'applications'))
    ..createSync(recursive: true);

  // Terminal=false -> lancement silencieux, sans fenêtre de terminal.
  final desktop =
      '''
[Desktop Entry]
Type=Application
Name=Motorz
Comment=Carnet de bord de vos véhicules
Exec="${layout.updaterExe}" --launch
Icon=${layout.appExecutable}
Terminal=false
Categories=Utility;
''';
  final file = File(p.join(appsDir.path, 'motorz.desktop'));
  file.writeAsStringSync(desktop);
  Process.runSync('chmod', ['+x', file.path]);

  // Petit symlink CLI pratique : `motorz` dans ~/.local/bin.
  final binDir = Directory(p.join(home, '.local', 'bin'));
  if (binDir.existsSync()) {
    final link = Link(p.join(binDir.path, 'motorz'));
    if (link.existsSync()) link.deleteSync();
    try {
      link.createSync(layout.updaterExe);
    } catch (_) {
      /* best-effort */
    }
  }

  log('Entrée de bureau créée : ${file.path}');
}
