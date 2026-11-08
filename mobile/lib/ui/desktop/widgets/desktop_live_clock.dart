import 'dart:async';
import 'package:flutter/material.dart';

/// Lightweight, self-contained live clock widget that updates every second
/// without triggering full parent screen rebuilds.
class DesktopLiveClock extends StatefulWidget {
  const DesktopLiveClock({
    super.key,
    required this.builder,
    this.period = const Duration(seconds: 1),
  });

  final Widget Function(BuildContext context, DateTime now) builder;
  final Duration period;

  @override
  State<DesktopLiveClock> createState() => _DesktopLiveClockState();
}

class _DesktopLiveClockState extends State<DesktopLiveClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(widget.period, (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _now);
  }
}
