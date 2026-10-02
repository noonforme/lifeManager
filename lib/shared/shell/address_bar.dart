import 'package:flutter/widgets.dart';

import '../workbench/era_controls.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';
import '../workbench/office_controls.dart';

/// One level of the current location. A crumb with a [route] opens it.
@immutable
final class AddressCrumb {
  const AddressCrumb(this.label, [this.route]);

  final String label;
  final String? route;

  @override
  bool operator ==(Object other) =>
      other is AddressCrumb && other.label == label && other.route == route;

  @override
  int get hashCode => Object.hash(label, route);
}

/// Where the owner is, as crumbs in a read-only field, with **Go** to
/// reload (spec 4 item 3).
final class AddressBar extends StatelessWidget {
  const AddressBar({
    required this.crumbs,
    required this.onNavigate,
    required this.onGo,
    super.key,
  });

  final List<AddressCrumb> crumbs;
  final ValueChanged<String> onNavigate;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final body = skin.typography.body.copyWith(color: tokens.ink);
    return Semantics(
      container: true,
      label: 'Address',
      explicitChildNodes: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 26),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: tokens.chrome,
          border: Border(bottom: BorderSide(color: tokens.chromeLine)),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Text('Address', style: body.copyWith(color: tokens.muted)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: tokens.paper,
                  border: Border.all(color: MillenniumColors.fieldLine),
                ),
                child: Row(
                  children: [
                    for (final (index, crumb) in crumbs.indexed) ...[
                      if (index > 0)
                        ExcludeSemantics(child: Text(' › ', style: body)),
                      Flexible(
                        child: _Crumb(
                          crumb: crumb,
                          last: index == crumbs.length - 1,
                          onNavigate: onNavigate,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            KeyButton(
              label: 'Go',
              kind: KeyKind.small,
              leading: const Orb(
                glyph: OrbGlyph.forward,
                tone: OrbTone.green,
                size: 14,
              ),
              onPressed: onGo,
            ),
          ],
        ),
      ),
    );
  }
}

final class _Crumb extends StatelessWidget {
  const _Crumb({
    required this.crumb,
    required this.last,
    required this.onNavigate,
  });

  final AddressCrumb crumb;
  final bool last;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final route = crumb.route;
    final text = Text(
      crumb.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: skin.typography.body.copyWith(
        color: skin.tokens.ink,
        fontWeight: last ? FontWeight.w700 : FontWeight.w400,
      ),
    );
    if (route == null || last) return text;
    return EraPressable(
      label: crumb.label,
      link: true,
      onPressed: () => onNavigate(route),
      child: text,
    );
  }
}
