import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records which platform widget created the native view and which ones were
/// disposed.
class _FakePlatform extends InAppWebViewPlatform {
  _FakePlatform({this.createsViewLater = false});

  /// Whether the view is created the way iOS, macOS, Windows and Linux create
  /// it: asynchronously, by whichever platform widget is current when
  /// [completeViewCreation] is called, instead of the way Android does it:
  /// synchronously, by the first platform widget built.
  final bool createsViewLater;

  final disposed = <_FakeWidget>[];
  VoidCallback? _pendingCreation;
  _FakeWidget? viewCreator;

  void completeViewCreation() => _pendingCreation?.call();

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => _FakeWidget(params, platform: this);
}

class _FakeWidget extends PlatformInAppWebViewWidget {
  _FakeWidget(super.params, {required this.platform}) : super.implementation();

  final _FakePlatform platform;

  @override
  Widget build(BuildContext context) => _ViewLink(
    onCreate: () => platform.viewCreator = this,
    platform: platform,
  );

  @override
  void dispose() => platform.disposed.add(this);

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      controller as T;
}

/// Creates the view once and keeps it across every rebuild after that, like
/// Android's `PlatformViewLink` or, when the view is created later, like
/// `UiKitView`, which reads its creation callback from its current widget
/// once creation completes.
class _ViewLink extends StatefulWidget {
  const _ViewLink({required this.onCreate, required this.platform});

  final VoidCallback onCreate;
  final _FakePlatform platform;

  @override
  State<_ViewLink> createState() => _ViewLinkState();
}

class _ViewLinkState extends State<_ViewLink> {
  @override
  void initState() {
    super.initState();
    if (widget.platform.createsViewLater) {
      widget.platform._pendingCreation = () => widget.onCreate();
    } else {
      widget.onCreate();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets(
    'a webview rebuilt after its view exists releases that view when it goes',
    (tester) async {
      final platform = _FakePlatform();
      InAppWebViewPlatform.instance = platform;

      await tester.pumpWidget(InAppWebView());
      await tester.pumpWidget(InAppWebView());
      await tester.pumpWidget(const SizedBox.shrink());

      expect(platform.viewCreator, isNotNull);
      expect(platform.disposed, contains(platform.viewCreator));
    },
  );

  testWidgets(
    'a webview rebuilt while its view is being created releases that view when it goes',
    (tester) async {
      final platform = _FakePlatform(createsViewLater: true);
      InAppWebViewPlatform.instance = platform;

      await tester.pumpWidget(InAppWebView());
      await tester.pumpWidget(InAppWebView());
      platform.completeViewCreation();
      await tester.pumpWidget(InAppWebView());
      await tester.pumpWidget(const SizedBox.shrink());

      expect(platform.viewCreator, isNotNull);
      expect(platform.disposed, contains(platform.viewCreator));
    },
  );

  testWidgets(
    'a webview never rebuilt releases the view it created when it goes',
    (tester) async {
      final platform = _FakePlatform();
      InAppWebViewPlatform.instance = platform;

      await tester.pumpWidget(InAppWebView());
      await tester.pumpWidget(const SizedBox.shrink());

      expect(platform.disposed, [platform.viewCreator]);
    },
  );
}
