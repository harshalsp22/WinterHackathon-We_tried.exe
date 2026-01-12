import 'package:flutter/material.dart';
import '../models/yolo_models.dart';

class AROverlayPainter extends CustomPainter {
  final List<Detection> detections;
  final Size imageSize;
  final Size screenSize;
  final String highlightComponent;

  AROverlayPainter({
    required this.detections,
    required this.imageSize,
    required this.screenSize,
    required this.highlightComponent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (final d in detections) {
      paint.color = d.className
          .toLowerCase()
          .contains(highlightComponent.toLowerCase())
          ? Colors.green
          : Colors.red;

      final rect = Rect.fromLTRB(
        d.x1 / imageSize.width * screenSize.width,
        d.y1 / imageSize.height * screenSize.height,
        d.x2 / imageSize.width * screenSize.width,
        d.y2 / imageSize.height * screenSize.height,
      );

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
