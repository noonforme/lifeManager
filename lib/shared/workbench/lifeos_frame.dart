import 'package:flutter/material.dart';

import 'inspector_pane.dart';
import 'lifeos_theme.dart';

final class LifeOSFrame extends StatelessWidget {
  const LifeOSFrame({
    required this.rail,
    required this.register,
    required this.inspector,
    required this.inspectorIsActive,
    required this.onBackToRegister,
    super.key,
  });

  final Widget rail;
  final Widget register;
  final Widget inspector;
  final bool inspectorIsActive;
  final VoidCallback onBackToRegister;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sequential =
            constraints.maxWidth < LifeOSMetrics.sequentialThreshold;
        final Widget content;
        if (sequential) {
          content = inspectorIsActive
              ? InspectorPane(
                  key: const ValueKey('inspector'),
                  showBackToRegister: true,
                  onBackToRegister: onBackToRegister,
                  child: inspector is InspectorPane
                      ? (inspector as InspectorPane).child
                      : inspector,
                )
              : _RegisterLandmark(
                  key: const ValueKey('register'),
                  child: register,
                );
        } else {
          content = Row(
            key: const ValueKey('wide'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: LifeOSMetrics.railWidth,
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: 'System navigation',
                  child: rail,
                ),
              ),
              const VerticalDivider(width: LifeOSMetrics.separatorWidth),
              Expanded(child: _RegisterLandmark(child: register)),
              const VerticalDivider(width: LifeOSMetrics.separatorWidth),
              SizedBox(
                width: LifeOSMetrics.inspectorWidth,
                child: inspector is InspectorPane
                    ? inspector
                    : InspectorPane(child: inspector),
              ),
            ],
          );
        }
        return AnimatedSwitcher(
          duration: lifeOSTransitionDuration(context),
          child: content,
        );
      },
    );
  }
}

final class _RegisterLandmark extends StatelessWidget {
  const _RegisterLandmark({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Work register',
      child: ColoredBox(
        color: LifeOSColors.ground,
        child: FocusTraversalGroup(child: child),
      ),
    );
  }
}
