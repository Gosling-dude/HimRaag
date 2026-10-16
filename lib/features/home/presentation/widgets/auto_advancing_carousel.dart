import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// A swipeable page view that also advances on its own every [interval], with
/// a page indicator underneath.
///
/// There is only ever one pending timer: it restarts on every page change
/// (auto or swiped), so a swipe gets a full [interval] before the next move.
/// Rotation pauses while the user drags, while another screen covers this one
/// (e.g. the full player) and while the app is in the background, and
/// rebuilds never touch the timer.
class AutoAdvancingCarousel extends StatefulWidget {
  const AutoAdvancingCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 200,
    this.interval = AppConstants.homeBannerAutoAdvanceInterval,
    this.animationDuration = AppConstants.homeBannerSlideDuration,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;
  final Duration interval;
  final Duration animationDuration;

  @override
  State<AutoAdvancingCarousel> createState() => _AutoAdvancingCarouselState();
}

class _AutoAdvancingCarouselState extends State<AutoAdvancingCarousel> {
  late PageController _controller;
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  int _current = 0;
  bool _dragging = false;
  bool _visible = true;
  bool _foreground = true;

  bool get _loops => widget.itemCount > 1;

  bool get _canAdvance => _loops && !_dragging && _visible && _foreground;

  // With more than one slide, pages sit on a long strip shown modulo
  // itemCount, so the carousel always slides forward — wrapping from the last
  // slide to the first without rewinding across the others. Starting
  // mid-strip keeps backward swipes working as well.
  PageController _createController() =>
      PageController(initialPage: _loops ? widget.itemCount * 1000 : 0);

  @override
  void initState() {
    super.initState();
    _controller = _createController();
    _lifecycle = AppLifecycleListener(onStateChange: (state) {
      _foreground = state == AppLifecycleState.resumed;
      _restartTimer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible || _timer == null) {
      _visible = visible;
      _restartTimer();
    }
  }

  @override
  void didUpdateWidget(AutoAdvancingCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount == widget.itemCount) return;
    if ((oldWidget.itemCount > 1) != _loops) {
      _controller.dispose();
      _controller = _createController();
      _current = 0;
    } else if (widget.itemCount > 0) {
      _current %= widget.itemCount;
    }
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = _canAdvance ? Timer(widget.interval, _advance) : null;
  }

  void _advance() {
    _timer = null;
    if (!mounted || !_controller.hasClients) return;
    _controller.nextPage(
      duration: widget.animationDuration,
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int page) {
    setState(() => _current = page % widget.itemCount);
    _restartTimer();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _dragging = true;
      _restartTimer();
    } else if (notification is ScrollEndNotification && _dragging) {
      _dragging = false;
      _restartTimer();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: PageView.builder(
              controller: _controller,
              itemCount: _loops ? null : widget.itemCount,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, page) =>
                  widget.itemBuilder(context, page % widget.itemCount),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.itemCount,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _current == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _current == i ? AppColors.primary : AppColors.dividerDark,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
