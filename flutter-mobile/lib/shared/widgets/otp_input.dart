import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Imperative handle for [OtpInput] so callers can trigger animations or
/// programmatic changes (e.g. shake on error, paste from clipboard).
class OtpInputController {
  _OtpInputState? _state;

  void _attach(_OtpInputState state) => _state = state;
  void _detach(_OtpInputState state) {
    if (identical(_state, state)) _state = null;
  }

  /// Plays a short horizontal shake animation. Safe to call repeatedly.
  void shake() => _state?._shake();

  /// Programmatically fills all cells with [value] (digits only).
  void setValue(String value) => _state?._setValue(value);

  /// Clears every cell.
  void clear() => _state?._setValue('');
}

class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final String? errorText;
  final OtpInputController? controller;

  const OtpInput({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.errorText,
    this.controller,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput>
    with SingleTickerProviderStateMixin {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final AnimationController _shakeCtrl;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant OtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _shakeCtrl.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _shake() {
    if (!mounted) return;
    _shakeCtrl
      ..reset()
      ..forward();
  }

  void _setValue(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < widget.length; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }
    final v = _value;
    widget.onChanged(v);
    if (v.length == widget.length) {
      widget.onCompleted?.call(v);
      _focusNodes.last.unfocus();
    } else if (digits.isNotEmpty) {
      final next = digits.length.clamp(0, widget.length - 1);
      _focusNodes[next].requestFocus();
    }
  }

  String get _value => _controllers.map((c) => c.text).join();

  void _handleChanged(int index, String value) {
    if (value.length > 1) {
      // Paste support: distribute digits.
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < widget.length; i++) {
        _controllers[i].text =
            i < digits.length ? digits[i] : '';
      }
      final filled = digits.length.clamp(0, widget.length);
      if (filled < widget.length) {
        _focusNodes[filled].requestFocus();
      } else {
        _focusNodes.last.unfocus();
      }
    } else if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
    final v = _value;
    widget.onChanged(v);
    if (v.length == widget.length) {
      widget.onCompleted?.call(v);
    }
  }

  void _handleBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      widget.onChanged(_value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (context, child) {
            // 3 oscillations, amplitude 8px, damped to 0 at the end.
            final t = _shakeCtrl.value;
            final dx = _shakeCtrl.isAnimating || t > 0
                ? math.sin(t * math.pi * 6) * 8 * (1 - t)
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (i) {
              return SizedBox(
                width: 44,
                child: KeyboardListener(
                  focusNode: FocusNode(skipTraversal: true),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.backspace) {
                      _handleBackspace(i);
                    }
                  },
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    enabled: widget.enabled,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: '',
                    ),
                    onChanged: (v) => _handleChanged(i, v),
                  ),
                ),
              );
            }),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
