class Detection {
  final String className;
  final double confidence;
  final int x1, y1, x2, y2;

  Detection({
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    final bbox = json['bbox'];
    return Detection(
      className: json['class_name'],
      confidence: (json['confidence'] as num).toDouble(),
      x1: bbox['x1'],
      y1: bbox['y1'],
      x2: bbox['x2'],
      y2: bbox['y2'],
    );
  }
}

class YoloResponse {
  final bool success;
  final List<Detection> detections;
  final int width;
  final int height;

  YoloResponse({
    required this.success,
    required this.detections,
    required this.width,
    required this.height,
  });

  factory YoloResponse.fromJson(Map<String, dynamic> json) {
    return YoloResponse(
      success: json['success'],
      detections: (json['detections'] as List)
          .map((e) => Detection.fromJson(e))
          .toList(),
      width: json['image_size']['width'],
      height: json['image_size']['height'],
    );
  }
}
