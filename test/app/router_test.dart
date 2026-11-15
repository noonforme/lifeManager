import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';

/// Pumps the production app on [location] with a probe for the Work shell,
/// and returns the links the probe was built with.
Future<List<Uri?>> _pumpAt(WidgetTester tester, String location) async {
  final links = <Uri?>[];
  final router = createAppRouter(
    initialLocation: location,
    work: (link) {
      links.add(link);
      return const SizedBox(key: ValueKey('work shell'));
    },
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(LifeOsApp(router: router));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('work shell')), findsOneWidget);
  expect(router.routeInformationProvider.value.uri.path, '/work');
  return links;
}

void main() {
  testWidgets('bare /work builds the shell with no link', (tester) async {
    final links = await _pumpAt(tester, '/work');
    expect(links.toSet(), {null});
  });

  testWidgets('/work with a query passes it as the link', (tester) async {
    const location = '/work?employment=e1&sheet=shifts&from=2026-10-01';
    final links = await _pumpAt(tester, location);
    expect(links.toSet(), {Uri.parse(location)});
  });

  for (final old in [
    '/',
    '/today',
    '/today?desk=d1',
    '/journal',
    '/journal?from=2026-10-01&to=2026-10-07',
    '/finance',
    '/tracking',
    '/knowledge',
    '/money',
    '/habits',
    '/system/files',
    '/nowhere/at/all',
  ]) {
    testWidgets('the old link $old opens bare /work', (tester) async {
      final links = await _pumpAt(tester, old);
      expect(links.toSet(), {null});
    });
  }
}
