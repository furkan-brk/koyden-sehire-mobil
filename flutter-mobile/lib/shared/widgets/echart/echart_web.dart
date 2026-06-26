// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

// ── EChart widget ──────────────────────────────────────────────────────────

int _viewTypeCounter = 0;

/// Renders an Apache ECharts chart on Flutter Web via [HtmlElementView].
///
/// Init is deferred and polled until both the ECharts global is available
/// *and* the container div has a non-zero size — this handles the race
/// between Flutter's platform-view rendering and the page being ready.
class EChart extends StatefulWidget {
  const EChart({
    super.key,
    required this.option,
    this.height = 260,
  });

  final Map<String, dynamic> option;
  final double height;

  @override
  State<EChart> createState() => _EChartState();
}

class _EChartState extends State<EChart> {
  // Each instance needs a unique platform-view type.
  final String _viewType = 'echart-view-${_viewTypeCounter++}';

  js.JsObject? _chart;
  Timer? _initTimer;
  StreamSubscription<html.Event>? _resizeSub;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final div = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%';
        _scheduleInit(div);
        return div;
      },
    );
  }

  /// Polls at 100 ms intervals until:
  /// 1. `window.echarts` is available (JS fully loaded).
  /// 2. The div has been laid out with non-zero dimensions.
  ///
  /// Gives up after ~5 s (50 ticks) to avoid infinite loops.
  void _scheduleInit(html.DivElement div) {
    int ticks = 0;
    _initTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || ticks++ > 50) {
        timer.cancel();
        return;
      }

      final echartsGlobal = js.context['echarts'];
      if (echartsGlobal == null) return; // wait for JS

      final w = div.clientWidth;
      final h = div.clientHeight;
      if (w <= 0 || h <= 0) return; // wait for layout

      timer.cancel();
      _initTimer = null;

      try {
        final chart = (echartsGlobal as js.JsObject).callMethod('init', [div]) as js.JsObject;
        chart.callMethod('setOption', [js_util.jsify(widget.option)]);
        _chart = chart;

        // Re-size on browser window resize.
        _resizeSub = html.window.onResize.listen((_) => _resize());
      } catch (_) {
        // Layout edge cases — will not retry; chart stays blank rather than crash.
      }
    });
  }

  void _applyOption() {
    _chart?.callMethod('setOption', [js_util.jsify(widget.option)]);
  }

  void _resize() {
    _chart?.callMethod('resize', []);
  }

  @override
  void didUpdateWidget(covariant EChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.option != widget.option) _applyOption();
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    _resizeSub?.cancel();
    _chart?.callMethod('dispose', []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, _) {
          // Notify ECharts whenever Flutter re-lays-out this widget.
          WidgetsBinding.instance.addPostFrameCallback((_) => _resize());
          return HtmlElementView(viewType: _viewType);
        },
      ),
    );
  }
}
