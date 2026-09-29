import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/bootstrap.dart';

void main() {
  test('window is shown only after stable services and router exist', () async {
    final trace = <String>[];
    final database = _FakeDatabase(trace);
    final dependencies = BootstrapDependencies(
      initializeBindings: () async => trace.add('bindings'),
      resolveSupportDirectory: () async => trace.add('supportDir'),
      initializeDiagnostics: () async => trace.add('diagnostics'),
      initializeTimezone: () async => trace.add('timezone'),
      initializeClock: () async => trace.add('clock'),
      openDatabase: () async {
        trace.add('database');
        return database;
      },
      validateSchema: (value) async {
        expect(value, same(database));
        trace.add('schema');
      },
      buildProviders: (value) async {
        expect(value, same(database));
        trace.add('providers');
        return const BootstrapProviders();
      },
      buildRouter: (providers) async {
        trace.add('router');
        return const SizedBox();
      },
      mountApp: (_) async => trace.add('mountApp'),
      showWindow: () async => trace.add('showWindow'),
      showRecovery: (_) async => fail('recovery should not be shown'),
    );

    await bootstrap(dependencies);

    expect(trace, [
      'bindings',
      'supportDir',
      'diagnostics',
      'timezone',
      'clock',
      'database',
      'schema',
      'providers',
      'router',
      'mountApp',
      'showWindow',
    ]);
  });

  test('startup failure closes an opened database before recovery', () async {
    final trace = <String>[];
    final database = _FakeDatabase(trace);
    final dependencies = BootstrapDependencies(
      initializeBindings: () async {},
      resolveSupportDirectory: () async {},
      initializeDiagnostics: () async {},
      initializeTimezone: () async {},
      initializeClock: () async {},
      openDatabase: () async => database,
      validateSchema: (_) async => throw StateError('private path'),
      buildProviders: (_) async => const BootstrapProviders(),
      buildRouter: (_) async => const SizedBox(),
      mountApp: (_) async => fail('app should not mount'),
      showWindow: () async => fail('window should not show'),
      showRecovery: (failure) async =>
          trace.add('recovery:${failure.code.name}'),
    );

    await bootstrap(dependencies);

    expect(trace, ['close', 'recovery:storageUnavailable']);
  });
}

final class _FakeDatabase implements BootstrapDatabase {
  _FakeDatabase(this.trace);

  final List<String> trace;

  @override
  Future<void> close() async => trace.add('close');
}
