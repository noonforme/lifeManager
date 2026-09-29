import 'dart:convert';
import 'dart:io';

import 'safe_diagnostic.dart';

abstract interface class DiagnosticSink {
  Future<void> record(SafeDiagnostic diagnostic);
}

final class DisabledDiagnosticSink implements DiagnosticSink {
  const DisabledDiagnosticSink();

  @override
  Future<void> record(SafeDiagnostic diagnostic) async {}
}

final class FileDiagnosticSink implements DiagnosticSink {
  const FileDiagnosticSink({required this.file, required this.enabled});

  final File file;
  final bool enabled;

  @override
  Future<void> record(SafeDiagnostic diagnostic) async {
    if (!enabled) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(diagnostic.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}
