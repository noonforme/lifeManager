import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/window_close_guard.dart';

const _channel = MethodChannel('window_manager');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Object?> preventClose;

  setUp(() {
    preventClose = [];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'setPreventClose') {
        preventClose.add((call.arguments as Map)['isPreventClose']);
      }
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  /// The native close button, as the plugin reports it.
  Future<void> pressClose() => messenger.handlePlatformMessage(
    _channel.name,
    const StandardMethodCodec().encodeMethodCall(
      const MethodCall('onEvent', {'eventName': 'close'}),
    ),
    (_) {},
  );

  test(
    'the latest interception alone answers the close button, once',
    () async {
      final asked = <String>[];
      Future<void> first() async => asked.add('first');
      Future<void> second() async => asked.add('second');
      final earlier = WindowManagerCloseApi();
      final later = WindowManagerCloseApi();
      await earlier.interceptClose(first);
      await later.interceptClose(second);
      await later.interceptClose(second);
      await pressClose();
      expect(asked, ['second']);
      await later.releaseClose(second);
    },
  );

  test('releasing an interception another has since taken leaves theirs '
      'in place', () async {
    final asked = <String>[];
    Future<void> first() async => asked.add('first');
    Future<void> second() async => asked.add('second');
    final earlier = WindowManagerCloseApi();
    final later = WindowManagerCloseApi();
    await earlier.interceptClose(first);
    await later.interceptClose(second);
    await earlier.releaseClose(first);
    await pressClose();
    expect(asked, ['second']);
    expect(preventClose, [true, true]);
    await later.releaseClose(second);
  });

  test('a failed destroy leaves the close interception working', () async {
    var asks = 0;
    Future<void> guard() async => asks++;
    final api = WindowManagerCloseApi();
    await api.interceptClose(guard);
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'destroy') throw PlatformException(code: 'failed');
      return null;
    });
    await expectLater(api.destroy(), throwsA(isA<PlatformException>()));
    await pressClose();
    expect(asks, 1);
    await api.releaseClose(guard);
  });

  test('releasing its own interception lets the window close', () async {
    final asked = <String>[];
    Future<void> guard() async => asked.add('guard');
    final api = WindowManagerCloseApi();
    await api.interceptClose(guard);
    await api.releaseClose(guard);
    await pressClose();
    expect(asked, isEmpty);
    expect(preventClose, [true, false]);
  });
}
