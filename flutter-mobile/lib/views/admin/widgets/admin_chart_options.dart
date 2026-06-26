import 'package:koyden_sehire/models/admin/admin_dashboard_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour tokens — mirrors AppColors hex values so ECharts matches the theme
// ─────────────────────────────────────────────────────────────────────────────

const _colorPrimary = '#14422D';
const _colorSecondary = '#43664D';
const _colorWarning = '#717973';
const _colorSurface = '#FFFFFF';
const _colorGridLine = '#E0E0E0';
const _colorTextMuted = '#6B7280';
const _colorTextBody = '#1C1B1F';

const _fontFamily = 'PlusJakartaSans, Roboto, sans-serif';

const _palette = [
  _colorPrimary,
  '#2D5A43',
  _colorSecondary,
  '#5C8060',
  '#8CA893',
  _colorWarning,
  '#4E7C58',
];

// ─────────────────────────────────────────────────────────────────────────────
// Shared style helpers
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _tooltip({String trigger = 'axis'}) => {
      'trigger': trigger,
      'backgroundColor': _colorSurface,
      'borderColor': _colorGridLine,
      'borderWidth': 1,
      'textStyle': {
        'color': _colorTextBody,
        'fontSize': 12,
        'fontFamily': _fontFamily,
      },
      'extraCssText':
          'box-shadow:0 2px 8px rgba(0,0,0,.12);border-radius:8px;',
    };

Map<String, dynamic> _axisLabel() => {
      'color': _colorTextMuted,
      'fontSize': 11,
      'fontFamily': _fontFamily,
    };

Map<String, dynamic> _splitLine() => {
      'lineStyle': {
        'color': _colorGridLine,
        'width': 1,
        'type': 'dashed',
      },
    };

String _hexWithAlpha(String hex, double alpha) {
  final r = int.parse(hex.substring(1, 3), radix: 16);
  final g = int.parse(hex.substring(3, 5), radix: 16);
  final b = int.parse(hex.substring(5, 7), radix: 16);
  return 'rgba($r,$g,$b,$alpha)';
}

List<String> _palette$(int count) =>
    List.generate(count, (i) => _palette[i % _palette.length]);

// ─────────────────────────────────────────────────────────────────────────────
// 1. Applications trend — smoothed area line
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> applicationsTrendOption(List<ChartPoint> points) {
  final names = points.map((p) => p.name).toList();
  final values = points.map((p) => p.value).toList();
  return {
    'tooltip': _tooltip(),
    'grid': {
      'left': 16,
      'right': 16,
      'top': 16,
      'bottom': 40,
      'containLabel': true,
    },
    'xAxis': {
      'type': 'category',
      'data': names,
      'axisLine': {'show': false},
      'axisTick': {'show': false},
      'axisLabel': {
        ..._axisLabel(),
        'interval': _xInterval(names.length),
        'rotate': names.length > 10 ? 30 : 0,
      },
      'splitLine': {'show': false},
    },
    'yAxis': {
      'type': 'value',
      'axisLabel': _axisLabel(),
      'axisLine': {'show': false},
      'axisTick': {'show': false},
      'splitLine': _splitLine(),
      'minInterval': 1,
    },
    'series': [
      {
        'name': 'Başvurular',
        'type': 'line',
        'data': values,
        'smooth': true,
        'symbol': 'circle',
        'symbolSize': 6,
        'lineStyle': {'color': _colorPrimary, 'width': 2.5},
        'itemStyle': {
          'color': _colorPrimary,
          'borderColor': _colorSurface,
          'borderWidth': 2,
        },
        'areaStyle': {
          'color': {
            'type': 'linear',
            'x': 0, 'y': 0, 'x2': 0, 'y2': 1,
            'colorStops': [
              {'offset': 0, 'color': _hexWithAlpha(_colorPrimary, 0.18)},
              {'offset': 1, 'color': _hexWithAlpha(_colorPrimary, 0.00)},
            ],
          },
        },
      },
    ],
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Products by category — vertical column bar
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> productsByCategoryOption(List<ChartPoint> points) {
  final sorted = [...points]..sort((a, b) => b.value.compareTo(a.value));
  final names = sorted.map((p) => p.name).toList();
  final values = sorted.map((p) => p.value).toList();
  final colours = _palette$(names.length);
  return {
    'tooltip': _tooltip(),
    'grid': {
      'left': 16,
      'right': 16,
      'top': 16,
      'bottom': 48,
      'containLabel': true,
    },
    'xAxis': {
      'type': 'category',
      'data': names,
      'axisLine': {'show': false},
      'axisTick': {'show': false},
      'axisLabel': {
        ..._axisLabel(),
        'interval': 0,
        'rotate': names.length > 5 ? 25 : 0,
        'overflow': 'truncate',
        'width': 80,
      },
      'splitLine': {'show': false},
    },
    'yAxis': {
      'type': 'value',
      'axisLabel': _axisLabel(),
      'axisLine': {'show': false},
      'axisTick': {'show': false},
      'splitLine': _splitLine(),
      'minInterval': 1,
    },
    'series': [
      {
        'name': 'Ürün Sayısı',
        'type': 'bar',
        'data': List.generate(values.length, (i) => {
              'value': values[i],
              'itemStyle': {
                'color': colours[i],
                'borderRadius': [6, 6, 0, 0],
              },
            }),
        'barMaxWidth': 52,
        'label': {
          'show': true,
          'position': 'top',
          'color': _colorTextMuted,
          'fontSize': 11,
          'fontFamily': _fontFamily,
        },
      },
    ],
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Producers by city — horizontal bar
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> producersByCityOption(List<ChartPoint> points) {
  final sorted = [...points]..sort((a, b) => a.value.compareTo(b.value));
  final cities = sorted.map((p) => p.name).toList();
  final values = sorted.map((p) => p.value).toList();
  return {
    'tooltip': _tooltip(trigger: 'axis'),
    'grid': {
      'left': 16,
      'right': 48,
      'top': 8,
      'bottom': 8,
      'containLabel': true,
    },
    'xAxis': {
      'type': 'value',
      'axisLabel': _axisLabel(),
      'axisLine': {'show': false},
      'axisTick': {'show': false},
      'splitLine': _splitLine(),
      'minInterval': 1,
    },
    'yAxis': {
      'type': 'category',
      'data': cities,
      'axisLabel': _axisLabel(),
      'axisLine': {'show': false},
      'axisTick': {'show': false},
      'splitLine': {'show': false},
    },
    'series': [
      {
        'name': 'Üretici Sayısı',
        'type': 'bar',
        'data': values,
        'barMaxWidth': 28,
        'itemStyle': {
          'color': {
            'type': 'linear',
            'x': 0, 'y': 0, 'x2': 1, 'y2': 0,
            'colorStops': [
              {'offset': 0, 'color': _colorSecondary},
              {'offset': 1, 'color': _colorPrimary},
            ],
          },
          'borderRadius': [0, 4, 4, 0],
        },
        'label': {
          'show': true,
          'position': 'right',
          'color': _colorTextMuted,
          'fontSize': 11,
          'fontFamily': _fontFamily,
        },
      },
    ],
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Ratio gauge — needle gauge showing value/total as a percentage
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> ratioGaugeOption({
  required String title,
  required int value,
  required int total,
}) {
  final pct = total > 0 ? (value / total * 100) : 0.0;
  return {
    'tooltip': {
      'formatter': '{a} <br/>{b}: {c}%',
      'backgroundColor': _colorSurface,
      'borderColor': _colorGridLine,
      'textStyle': {'color': _colorTextBody, 'fontFamily': _fontFamily},
    },
    'series': [
      {
        'name': title,
        'type': 'gauge',
        'radius': '85%',
        'startAngle': 200,
        'endAngle': -20,
        'min': 0,
        'max': 100,
        'splitNumber': 5,
        'axisLine': {
          'lineStyle': {
            'width': 12,
            'color': [
              [pct / 100, _colorPrimary],
              [1, _colorGridLine],
            ],
          },
        },
        'pointer': {
          'itemStyle': {'color': _colorPrimary},
          'length': '60%',
          'width': 5,
        },
        'axisTick': {
          'distance': -16,
          'length': 6,
          'lineStyle': {'color': _colorSurface, 'width': 2},
        },
        'splitLine': {
          'distance': -22,
          'length': 12,
          'lineStyle': {'color': _colorSurface, 'width': 3},
        },
        'axisLabel': {
          'color': _colorTextMuted,
          'fontSize': 10,
          'distance': 18,
          'fontFamily': _fontFamily,
          'formatter': '{value}%',
        },
        'detail': {
          'valueAnimation': true,
          'formatter': '${pct.toStringAsFixed(1)}%\n$value / $total',
          'color': _colorPrimary,
          'fontSize': 16,
          'fontWeight': 'bold',
          'fontFamily': _fontFamily,
          'offsetCenter': [0, '55%'],
        },
        'title': {
          'show': true,
          'offsetCenter': [0, '-20%'],
          'color': _colorTextMuted,
          'fontSize': 12,
          'fontFamily': _fontFamily,
        },
        'data': [
          {'value': double.parse(pct.toStringAsFixed(1)), 'name': title},
        ],
      },
    ],
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Product status donut — pie chart showing active/pending/other breakdown
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> productStatusDonutOption(DashboardStats stats) {
  final other = (stats.totalProducts - stats.activeProducts - stats.pendingProducts)
      .clamp(0, stats.totalProducts);
  final slices = <Map<String, dynamic>>[
    {
      'name': 'Yayında',
      'value': stats.activeProducts,
      'itemStyle': {'color': _colorPrimary},
    },
    {
      'name': 'Onay Bekleyen',
      'value': stats.pendingProducts,
      'itemStyle': {'color': _colorWarning},
    },
    if (other > 0)
      {
        'name': 'Diğer',
        'value': other,
        'itemStyle': {'color': _colorGridLine},
      },
  ];
  return {
    'tooltip': _tooltip(trigger: 'item'),
    'legend': {
      'bottom': 0,
      'left': 'center',
      'itemWidth': 12,
      'itemHeight': 12,
      'textStyle': {
        'color': _colorTextMuted,
        'fontSize': 11,
        'fontFamily': _fontFamily,
      },
    },
    'series': [
      {
        'name': 'Ürün Durumu',
        'type': 'pie',
        'radius': ['42%', '68%'],
        'center': ['50%', '45%'],
        'avoidLabelOverlap': true,
        'label': {
          'show': true,
          'position': 'outside',
          'formatter': '{b}: {c}',
          'color': _colorTextMuted,
          'fontSize': 11,
          'fontFamily': _fontFamily,
        },
        'labelLine': {
          'show': true,
          'length': 10,
          'length2': 8,
          'lineStyle': {'color': _colorGridLine},
        },
        'emphasis': {
          'label': {'show': true, 'fontSize': 13, 'fontWeight': 'bold'},
          'itemStyle': {
            'shadowBlur': 10,
            'shadowOffsetX': 0,
            'shadowColor': 'rgba(0,0,0,0.3)',
          },
        },
        'data': slices,
      },
    ],
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

int _xInterval(int count) {
  if (count <= 7) return 0;
  if (count <= 14) return 1;
  return 2;
}
