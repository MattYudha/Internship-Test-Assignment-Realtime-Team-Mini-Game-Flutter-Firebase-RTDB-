import 'package:flutter/material.dart';

class BouncingDotsIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const BouncingDotsIndicator({
    super.key,
    this.color = Colors.blue,
    this.size = 8.0,
  });

  @override
  State<BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<BouncingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Create an offset delay for each dot to cascade the bounce
        double val = _controller.value;
        double offset = index * 0.2;
        double progress = (val - offset) % 1.0;
        if (progress < 0) progress += 1.0;

        // Sine wave for smooth up and down bounce (only happens in first half of cycle)
        double bounce = 0.0;
        if (progress < 0.5) {
          bounce = -10.0 * (0.5 - (progress - 0.25).abs()) * 4;
        }

        return Transform.translate(
          offset: Offset(0, bounce),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.0),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) => _buildDot(index)),
    );
  }
}
