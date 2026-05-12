import 'package:flutter/material.dart';

class ExpressiveLoadingIndicator extends StatelessWidget {
  const ExpressiveLoadingIndicator({
    super.key,
    this.size = 44,
    this.strokeWidth = 4.5,
    this.semanticsLabel = 'Loading',
  });

  final double size;
  final double strokeWidth;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        semanticsLabel: semanticsLabel,
        strokeWidth: strokeWidth,
        strokeCap: StrokeCap.round,
        trackGap: strokeWidth <= 2 ? 2 : 4,
        constraints: const BoxConstraints(),
        // ignore: deprecated_member_use
        year2023: false,
      ),
    );
  }
}
