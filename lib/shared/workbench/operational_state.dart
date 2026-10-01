import 'package:flutter/material.dart';

import 'lifeos_theme.dart';

enum OperationalStateKind {
  loading,
  empty,
  unavailable,
  invalidScope,
  conflict,
  uncertain,
}

final class OperationalState extends StatelessWidget {
  const OperationalState({
    required this.kind,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final OperationalStateKind kind;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final warning = switch (kind) {
      OperationalStateKind.unavailable ||
      OperationalStateKind.invalidScope ||
      OperationalStateKind.conflict ||
      OperationalStateKind.uncertain => true,
      OperationalStateKind.loading || OperationalStateKind.empty => false,
    };
    return Semantics(
      container: true,
      liveRegion: kind == OperationalStateKind.loading,
      label: title,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  warning ? Icons.warning_amber_rounded : Icons.work_outline,
                  color: warning ? LifeOSColors.warning : LifeOSColors.muted,
                ),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center),
                if (action != null) ...[const SizedBox(height: 16), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
