import 'dart:math';

class StabilizedDetection {
  String className;
  double confidence;
  double x1, y1, x2, y2;
  int frameCount;
  DateTime lastSeen;
  bool isStable;

  StabilizedDetection({
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.frameCount = 1,
    DateTime? lastSeen,
    this.isStable = false,
  }) : lastSeen = lastSeen ?? DateTime.now();

  // Center point
  double get centerX => (x1 + x2) / 2;
  double get centerY => (y1 + y2) / 2;
  double get width => x2 - x1;
  double get height => y2 - y1;
}

class DetectionStabilizer {
  final List<StabilizedDetection> _stableDetections = [];
  final int minFramesToStabilize;
  final double iouThreshold;
  final Duration maxAge;
  final double smoothingFactor;

  DetectionStabilizer({
    this.minFramesToStabilize = 3,
    this.iouThreshold = 0.3,
    this.maxAge = const Duration(milliseconds: 1500),
    this.smoothingFactor = 0.3,
  });

  List<StabilizedDetection> get detections => _stableDetections
      .where((d) => d.isStable)
      .toList();

  List<StabilizedDetection> get allDetections => _stableDetections;

  void update(List<RawDetection> newDetections) {
    final now = DateTime.now();

    // Remove old detections
    _stableDetections.removeWhere(
          (d) => now.difference(d.lastSeen) > maxAge,
    );

    // Match new detections to existing ones
    final matched = <int>{};

    for (final newDet in newDetections) {
      int bestMatchIdx = -1;
      double bestIou = 0;

      for (int i = 0; i < _stableDetections.length; i++) {
        if (matched.contains(i)) continue;
        if (_stableDetections[i].className != newDet.className) continue;

        final iou = _calculateIoU(
          _stableDetections[i],
          newDet,
        );

        if (iou > bestIou && iou > iouThreshold) {
          bestIou = iou;
          bestMatchIdx = i;
        }
      }

      if (bestMatchIdx >= 0) {
        // Update existing detection with smoothing
        matched.add(bestMatchIdx);
        final existing = _stableDetections[bestMatchIdx];

        existing.x1 = _smooth(existing.x1, newDet.x1.toDouble());
        existing.y1 = _smooth(existing.y1, newDet.y1.toDouble());
        existing.x2 = _smooth(existing.x2, newDet.x2.toDouble());
        existing.y2 = _smooth(existing.y2, newDet.y2.toDouble());
        existing.confidence = _smooth(existing.confidence, newDet.confidence);
        existing.frameCount++;
        existing.lastSeen = now;
        existing.isStable = existing.frameCount >= minFramesToStabilize;
      } else {
        // Add new detection
        _stableDetections.add(StabilizedDetection(
          className: newDet.className,
          confidence: newDet.confidence,
          x1: newDet.x1.toDouble(),
          y1: newDet.y1.toDouble(),
          x2: newDet.x2.toDouble(),
          y2: newDet.y2.toDouble(),
          lastSeen: now,
        ));
      }
    }

    // Decrease frame count for unmatched detections
    for (int i = 0; i < _stableDetections.length; i++) {
      if (!matched.contains(i)) {
        _stableDetections[i].frameCount =
            (_stableDetections[i].frameCount - 1).clamp(0, 100);
        if (_stableDetections[i].frameCount < minFramesToStabilize) {
          _stableDetections[i].isStable = false;
        }
      }
    }
  }

  double _smooth(double oldVal, double newVal) {
    return oldVal + (newVal - oldVal) * smoothingFactor;
  }

  double _calculateIoU(StabilizedDetection a, RawDetection b) {
    final xA = max(a.x1, b.x1.toDouble());
    final yA = max(a.y1, b.y1.toDouble());
    final xB = min(a.x2, b.x2.toDouble());
    final yB = min(a.y2, b.y2.toDouble());

    final interArea = max(0, xB - xA) * max(0, yB - yA);
    final boxAArea = (a.x2 - a.x1) * (a.y2 - a.y1);
    final boxBArea = (b.x2 - b.x1) * (b.y2 - b.y1);

    return interArea / (boxAArea + boxBArea - interArea);
  }

  void clear() {
    _stableDetections.clear();
  }
}

class RawDetection {
  final String className;
  final double confidence;
  final int x1, y1, x2, y2;

  RawDetection({
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
}