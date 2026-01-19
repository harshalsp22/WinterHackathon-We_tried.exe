import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

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
    final bbox = json['bbox'] ?? {};
    return Detection(
      className: json['class_name'] ?? json['name'] ?? 'Unknown',
      confidence: (json['confidence'] ?? 0).toDouble(),
      x1: (bbox['x1'] ?? 0).toInt(),
      y1: (bbox['y1'] ?? 0).toInt(),
      x2: (bbox['x2'] ?? 0).toInt(),
      y2: (bbox['y2'] ?? 0).toInt(),
    );
  }
}

class YoloResponse {
  final bool success;
  final List<Detection> detections;
  final int imageWidth;
  final int imageHeight;

  YoloResponse({
    required this.success,
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  factory YoloResponse.fromJson(Map<String, dynamic> json) {
    final imgSize = json['image_size'] ?? {};
    return YoloResponse(
      success: json['success'] ?? true,
      imageWidth: imgSize['width'] ?? 640,
      imageHeight: imgSize['height'] ?? 480,
      detections: (json['detections'] as List<dynamic>?)
          ?.map((d) => Detection.fromJson(d))
          .toList() ??
          [],
    );
  }
}

class YoloService {
  final String baseUrl;

  YoloService({required this.baseUrl});

  Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<YoloResponse?> detectFromBytes(
      Uint8List imageBytes, {
        double confidence = 0.15,  // ⬅️ Lower default confidence
      }) async {
    try {
      final uri = Uri.parse('$baseUrl/detect');

      final request = http.MultipartRequest('POST', uri)
        ..fields['confidence'] = confidence.toString()
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'frame.jpg',
        ));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 8),
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('YOLO: ${response.statusCode} - ${response.body.length} bytes');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return YoloResponse.fromJson(json);
      }
      return null;
    } catch (e) {
      print('YOLO Error: $e');
      return null;
    }
  }
}