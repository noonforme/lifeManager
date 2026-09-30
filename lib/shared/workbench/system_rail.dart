import 'package:flutter/material.dart';

import 'lifeos_theme.dart';

final class SystemRail extends StatelessWidget {
  const SystemRail({
    required this.selectedPath,
    required this.onNavigate,
    super.key,
  });

  final String selectedPath;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'System navigation',
      child: ColoredBox(
        color: LifeOSColors.rail,
        child: SafeArea(
          child: FocusTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 16),
                  child: Text(
                    'LifeOS',
                    style: TextStyle(
                      color: LifeOSColors.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _Destination(
                  label: 'Today',
                  path: '/today',
                  selectedPath: selectedPath,
                  available: false,
                  onNavigate: onNavigate,
                ),
                _Destination(
                  label: 'Work',
                  path: '/work',
                  selectedPath: selectedPath,
                  available: true,
                  onNavigate: onNavigate,
                ),
                _Destination(
                  label: 'Money',
                  path: '/money',
                  selectedPath: selectedPath,
                  available: false,
                  onNavigate: onNavigate,
                ),
                _Destination(
                  label: 'Habits',
                  path: '/habits',
                  selectedPath: selectedPath,
                  available: false,
                  onNavigate: onNavigate,
                ),
                const Spacer(),
                _Destination(
                  label: 'Backup and Export',
                  path: '/system/files',
                  selectedPath: selectedPath,
                  available: true,
                  onNavigate: onNavigate,
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _Destination extends StatelessWidget {
  const _Destination({
    required this.label,
    required this.path,
    required this.selectedPath,
    required this.available,
    required this.onNavigate,
  });

  final String label;
  final String path;
  final String selectedPath;
  final bool available;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final selected = selectedPath == path;
    final semanticLabel = selected
        ? '$label, selected'
        : available
        ? label
        : '$label, Not available in this release';
    return Semantics(
      button: true,
      enabled: available,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: available ? label : 'Not available in this release',
        child: InkWell(
          onTap: available ? () => onNavigate(path) : null,
          focusColor: LifeOSColors.selectionWash,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: LifeOSMetrics.controlHeight,
            ),
            decoration: BoxDecoration(
              color: selected ? LifeOSColors.surface : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: selected ? LifeOSColors.selection : Colors.transparent,
                ),
                bottom: const BorderSide(color: LifeOSColors.boundary),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: available ? LifeOSColors.ink : LifeOSColors.muted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (!available)
                  const Icon(
                    Icons.lock_outline,
                    size: 15,
                    color: LifeOSColors.muted,
                    semanticLabel: 'Not available in this release',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
