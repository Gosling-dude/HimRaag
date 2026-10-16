import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:himraag/core/constants/app_constants.dart';
import 'package:himraag/features/home/presentation/widgets/auto_advancing_carousel.dart';

const _interval = AppConstants.homeBannerAutoAdvanceInterval;

Widget _carousel({int count = 3, bool tickers = true}) {
  return MaterialApp(
    home: Scaffold(
      body: TickerMode(
        enabled: tickers,
        child: AutoAdvancingCarousel(
          itemCount: count,
          itemBuilder: (context, i) => Center(child: Text('slide $i')),
        ),
      ),
    ),
  );
}

/// Index of the highlighted (wide) indicator dot.
int _activeDot(WidgetTester tester) {
  final dots = find.descendant(
    of: find.byType(AutoAdvancingCarousel),
    matching: find.byType(AnimatedContainer),
  );
  final count = dots.evaluate().length;
  for (var i = 0; i < count; i++) {
    if (tester.getSize(dots.at(i)).width > 10) return i;
  }
  return -1;
}

double _page(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page!;

Future<void> _lifecycle(WidgetTester tester, List<AppLifecycleState> states) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

void main() {
  test('the Home banner interval is ~3 s with a 300–400 ms slide', () {
    expect(_interval, const Duration(seconds: 3));
    expect(AppConstants.homeBannerSlideDuration.inMilliseconds,
        inInclusiveRange(300, 400));
  });

  testWidgets('advances on its own at the configured interval',
      (tester) async {
    await tester.pumpWidget(_carousel());
    expect(find.text('slide 0'), findsOneWidget);

    await tester.pump(_interval - const Duration(milliseconds: 100));
    expect(find.text('slide 1'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('slide 1'), findsOneWidget);
    expect(_activeDot(tester), 1);
  });

  testWidgets('wraps forward from the last slide to the first',
      (tester) async {
    await tester.pumpWidget(_carousel());
    final start = _page(tester);

    for (var i = 0; i < 3; i++) {
      await tester.pump(_interval);
      await tester.pumpAndSettle();
    }

    expect(find.text('slide 0'), findsOneWidget);
    expect(_activeDot(tester), 0);
    expect(_page(tester), start + 3, reason: 'moved forward, not rewound');
  });

  testWidgets('a swipe changes slide, updates the indicator and restarts the '
      'countdown', (tester) async {
    await tester.pumpWidget(_carousel());
    await tester.pump(const Duration(seconds: 2)); // 1 s before auto-advance

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('slide 1'), findsOneWidget);
    expect(_activeDot(tester), 1);

    // The countdown restarted with the swipe: the timer that was due 1 s
    // after it never fires.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('slide 1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('slide 2'), findsOneWidget);
    expect(_activeDot(tester), 2);
  });

  testWidgets('holding a drag pauses rotation; it resumes after release',
      (tester) async {
    await tester.pumpWidget(_carousel());

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(PageView)));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(_activeDot(tester), 0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_activeDot(tester), 0);

    await tester.pump(_interval);
    await tester.pumpAndSettle();
    expect(_activeDot(tester), 1);
  });

  testWidgets('does not rotate while covered or in the background',
      (tester) async {
    await tester.pumpWidget(_carousel(tickers: false));
    await tester.pump(const Duration(seconds: 10));
    expect(_activeDot(tester), 0);

    await tester.pumpWidget(_carousel());
    await tester.pump(_interval);
    await tester.pumpAndSettle();
    expect(_activeDot(tester), 1);

    await _lifecycle(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await tester.pump(const Duration(seconds: 10));
    expect(_activeDot(tester), 1);

    await _lifecycle(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pump(_interval);
    await tester.pumpAndSettle();
    expect(_activeDot(tester), 2);
  });

  testWidgets('a single slide never rotates', (tester) async {
    await tester.pumpWidget(_carousel(count: 1));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('slide 0'), findsOneWidget);
  });

  testWidgets('disposing cancels the pending timer', (tester) async {
    await tester.pumpWidget(_carousel());
    await tester.pump(const Duration(seconds: 1));

    // Replacing the tree disposes the carousel; a timer left running would
    // fail the test ("A Timer is still pending…") or throw on a dead state.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
