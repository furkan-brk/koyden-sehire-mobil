// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:js' as js;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ── EChart widget ──────────────────────────────────────────────────────────

/// Renders an Apache ECharts chart on Flutter Web.
///
/// Uses ECharts' headless **SSR / SVG** mode (`echarts.init(null, null,
/// {renderer: 'svg', ssr: true, width, height})` + `renderToSVGString()`): the
/// chart is rendered fully and synchronously to an SVG string with no DOM
/// element, then painted by Flutter's own [SvgPicture]. This deliberately
/// avoids [HtmlElementView] platform views, which the CanvasKit renderer failed
/// to composite (the DOM node was laid out correctly but never shown), and also
/// avoids the canvas renderer's deferred first-frame paint. Charts are static
/// (no tooltips/hover), which is fine for dashboard KPIs.
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
  String? _svg;

  /// Width the current [_svg] was rendered at, so we only re-render when the
  /// available width actually changes.
  double? _renderedWidth;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Renders the chart to an SVG string at [width] × [widget.height]. Retries
  /// until the `echarts` global has finished loading.
  void _render(double width) {
    if (width <= 0) return;
    _renderedWidth = width;
    _pollTimer?.cancel();

    int ticks = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || ticks++ > 50) {
        timer.cancel();
        return;
      }
      final echarts = js.context['echarts'];
      if (echarts == null) return; // wait for echarts.min.js to load

      timer.cancel();
      final svg = _renderToSvg(echarts as js.JsObject, width);
      if (svg != null && mounted) {
        setState(() => _svg = svg);
      }
    });
  }

  /// Renders headlessly and returns the SVG markup. Null on any failure.
  String? _renderToSvg(js.JsObject echarts, double width) {
    js.JsObject? chart;
    try {
      final opts = js.JsObject.jsify({
        'renderer': 'svg',
        'ssr': true,
        'width': width.round(),
        'height': widget.height.round(),
      });
      chart = echarts.callMethod('init', [null, null, opts]) as js.JsObject;

      final option = Map<String, dynamic>.from(widget.option)..['animation'] = false;
      chart.callMethod('setOption', [js.JsObject.jsify(option)]);

      return chart.callMethod('renderToSVGString', const []) as String;
    } catch (_) {
      return null;
    } finally {
      chart?.callMethod('dispose', const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (_renderedWidth != width) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _renderedWidth != width) _render(width);
            });
          }
          if (_svg == null) {
            return const SizedBox.shrink();
          }
          return SvgPicture.string(_svg!, fit: BoxFit.contain);
        },
      ),
    );
  }
}
