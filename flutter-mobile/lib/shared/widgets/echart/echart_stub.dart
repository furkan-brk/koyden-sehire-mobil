import 'package:flutter/material.dart';

/// Non-web stub for [EChart]. Returns an empty box since charts are only
/// rendered on the web-based admin panel.
class EChart extends StatelessWidget {
  // ignore: avoid_unused_constructor_parameters
  const EChart({super.key, required Map<String, dynamic> option, this.height = 260});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}
