import 'package:flutter/material.dart';

import 'lifeos_theme.dart';

final class InspectorPane extends StatelessWidget {
  const InspectorPane({
    required this.child,
    this.showBackToRegister = false,
    this.onBackToRegister,
    super.key,
  });

  final Widget child;
  final bool showBackToRegister;
  final VoidCallback? onBackToRegister;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Record inspector',
      child: ColoredBox(
        color: LifeOSColors.surface,
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBackToRegister)
                DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: LifeOSColors.boundary),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onBackToRegister,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back to register'),
                    ),
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
