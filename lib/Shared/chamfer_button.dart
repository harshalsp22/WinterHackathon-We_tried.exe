import 'package:flutter/material.dart';

class ChamferButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final double width;
  final double height;
  final Color color;

  const ChamferButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.width = 260,
    this.height = 56,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: CustomPaint(
        painter: _ChamferPainter(color),
        child: SizedBox(
          width: width,
          height: height,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _ChamferPainter extends CustomPainter {
  final Color color;
  _ChamferPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const double cut = 18.0; // matches your image

    final path = Path()
    // top-left chamfer
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)

    // right side
      ..lineTo(size.width, size.height - cut)

    // bottom-right chamfer
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)

    // left side
      ..lineTo(0, cut)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
