import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'detection_stabilizer.dart';

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
        double confidence = 0.25,
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
        const Duration(seconds: 10),
      );

      final response = await http.Response.fromStream(streamedResponse);

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

class YoloResponse {
  final bool success;
  final List<RawDetection> detections;
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
          ?.map((d) => RawDetection(
        className: d['class_name'] ?? d['name'] ?? 'Unknown',
        confidence: (d['confidence'] ?? 0).toDouble(),
        x1: (d['bbox']?['x1'] ?? 0).toInt(),
        y1: (d['bbox']?['y1'] ?? 0).toInt(),
        x2: (d['bbox']?['x2'] ?? 0).toInt(),
        y2: (d['bbox']?['y2'] ?? 0).toInt(),
      ))
          .toList() ??
          [],
    );
  }
}