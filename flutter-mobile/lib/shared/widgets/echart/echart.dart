// Platform-adaptive ECharts widget.
//
// On Flutter Web (where the admin panel runs), renders an Apache ECharts
// chart via HtmlElementView + JS interop.
// On other platforms (mobile/desktop) the widget is a no-op SizedBox.
library;

export 'echart_stub.dart'
    if (dart.library.html) 'echart_web.dart';
