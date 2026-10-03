import 'package:flutter/material.dart';

class StreakStatusWidget extends StatelessWidget {
  final String status;
  const StreakStatusWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }
}
