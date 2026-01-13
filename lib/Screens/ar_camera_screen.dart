import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/diagnostic_plan.dart';
import '../services/yolo_service.dart';

class ARCameraScreen extends StatefulWidget {
  final DiagnosticPlan plan;
  final String yoloServerUrl;

  const ARCameraScreen({
    super.key,
    required this.plan,
    this.yoloServerUrl = 'https://q7gx07kb-5000.inc1.devtunnels.ms',
  });

  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen> {
  CameraController? _cameraController;
  late YoloService _yoloService;

  // Detection with stabilization
  List<StableDetection> _stableDetections = [];
  Map<String, StableDetection> _detectionHistory = {};

  bool _isDetecting = false;
  bool _isInitialized = false;
  int _currentStepIndex = 0;
  Timer? _detectionTimer;

  String _serverStatus = 'Connecting...';
  int _framesSent = 0;
  bool _showDebugPanel = true;

  Size _imageSize = const Size(640, 480);
  bool _componentFound = false;

  @override
  void initState() {
    super.initState();
    _yoloService = YoloService(baseUrl: widget.yoloServerUrl);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() => _isInitialized = true);
      _startDetectionLoop();
    } catch (e) {
      print('Camera error: $e');
    }
  }

  void _startDetectionLoop() {
    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 600), // Slower = more stable
          (_) => _captureAndDetect(),
    );
  }

  Future<void> _captureAndDetect() async {
    if (_isDetecting || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _isDetecting = true;

    try {
      final XFile image = await _cameraController!.takePicture();
      final Uint8List bytes = await image.readAsBytes();

      setState(() => _framesSent++);

      // Use lower confidence for better detection
      final response = await _yoloService.detectFromBytes(bytes, confidence: 0.15);

      if (response != null && mounted) {
        _updateStableDetections(response.detections);

        setState(() {
          _imageSize = Size(
            response.imageWidth.toDouble(),
            response.imageHeight.toDouble(),
          );
          _serverStatus = '✅ Active (${response.detections.length} raw)';
          _checkCurrentStepComponent();
        });
      }
    } catch (e) {
      print('Detection error: $e');
      setState(() => _serverStatus = '❌ Error');
    } finally {
      _isDetecting = false;
    }
  }

  void _updateStableDetections(List<Detection> newDetections) {
    final now = DateTime.now();

    // Update existing or add new detections
    for (final det in newDetections) {
      final key = det.className;

      if (_detectionHistory.containsKey(key)) {
        // Update existing - smooth the position
        final existing = _detectionHistory[key]!;
        existing.update(det, now);
      } else {
        // Add new
        _detectionHistory[key] = StableDetection.fromDetection(det, now);
      }
    }

    // Remove old detections (not seen for 2 seconds)
    _detectionHistory.removeWhere((key, det) {
      return now.difference(det.lastSeen).inMilliseconds > 2000;
    });

    // Get stable detections (seen at least 2 times)
    _stableDetections = _detectionHistory.values
        .where((d) => d.hitCount >= 2)
        .toList();
  }

  void _checkCurrentStepComponent() {
    if (_currentStepIndex >= widget.plan.steps.length) return;

    final currentStep = widget.plan.steps[_currentStepIndex];
    final targetComponent = currentStep.cameraFocus.toLowerCase();

    _componentFound = _stableDetections.any(
          (d) => d.className.toLowerCase().contains(targetComponent),
    );
  }

  void _nextStep() {
    if (_currentStepIndex < widget.plan.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _componentFound = false;
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
        _componentFound = false;
      });
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Complete!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'All diagnostic steps completed.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  // Mock detections for testing
  void _addMockDetections() {
    final screenSize = MediaQuery.of(context).size;

    setState(() {
      _stableDetections = [
        StableDetection(
          className: 'RAM',
          confidence: 0.92,
          x1: screenSize.width * 0.1,
          y1: screenSize.height * 0.25,
          x2: screenSize.width * 0.45,
          y2: screenSize.height * 0.40,
          hitCount: 5,
          lastSeen: DateTime.now(),
        ),
        StableDetection(
          className: 'CPU',
          confidence: 0.88,
          x1: screenSize.width * 0.5,
          y1: screenSize.height * 0.2,
          x2: screenSize.width * 0.85,
          y2: screenSize.height * 0.38,
          hitCount: 5,
          lastSeen: DateTime.now(),
        ),
      ];
      _imageSize = screenSize;
      _serverStatus = '🧪 Mock Mode';
      _checkCurrentStepComponent();
    });
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized ? _buildARView() : _buildLoadingView(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          const Text('Initializing camera...', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() => _isInitialized = true);
              _addMockDetections();
            },
            child: const Text('Use Demo Mode'),
          ),
        ],
      ),
    );
  }

  Widget _buildARView() {
    final currentStep = widget.plan.steps[_currentStepIndex];
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Preview
        if (_cameraController != null) CameraPreview(_cameraController!),

        // Simple Bounding Boxes
        ..._buildSimpleBoundingBoxes(screenSize, currentStep),

        // Top Bar
        _buildTopBar(),

        // Debug Panel
        if (_showDebugPanel) _buildDebugPanel(),

        // Detected List
        _buildDetectedList(),

        // Bottom Panel
        _buildBottomPanel(currentStep),
      ],
    );
  }

  List<Widget> _buildSimpleBoundingBoxes(Size screenSize, DiagnosticStep currentStep) {
    if (_stableDetections.isEmpty) return [];

    final targetComponent = currentStep.cameraFocus.toLowerCase();
    final scaleX = screenSize.width / _imageSize.width;
    final scaleY = screenSize.height / _imageSize.height;

    return _stableDetections.map((det) {
      final x = det.x1 * scaleX;
      final y = det.y1 * scaleY;
      final width = (det.x2 - det.x1) * scaleX;
      final height = (det.y2 - det.y1) * scaleY;

      final isTarget = det.className.toLowerCase().contains(targetComponent);
      final color = isTarget ? Colors.green : _getColorForClass(det.className);

      return Positioned(
        left: x.clamp(0, screenSize.width - 50),
        top: y.clamp(0, screenSize.height - 50),
        child: Container(
          width: width.clamp(60, screenSize.width - x),
          height: height.clamp(60, screenSize.height - y),
          decoration: BoxDecoration(
            border: Border.all(
              color: color,
              width: isTarget ? 3 : 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Label at top
              Positioned(
                top: -28,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getIconForClass(det.className),
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${det.className} ${(det.confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Center icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    _getIconForClass(det.className),
                    color: color,
                    size: 24,
                  ),
                ),
              ),

              // Target arrow
              if (isTarget)
                Positioned(
                  top: -50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'TARGET',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.green, size: 20),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 8,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                'Step ${_currentStepIndex + 1} / ${widget.plan.steps.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.science, color: Colors.orange),
              onPressed: _addMockDetections,
            ),
            IconButton(
              icon: Icon(
                Icons.bug_report,
                color: _showDebugPanel ? Colors.green : Colors.white54,
              ),
              onPressed: () => setState(() => _showDebugPanel = !_showDebugPanel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server: $_serverStatus', style: const TextStyle(color: Colors.white, fontSize: 11)),
            Text('Frames: $_framesSent', style: const TextStyle(color: Colors.white, fontSize: 11)),
            Text('Stable: ${_stableDetections.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
            Text('Tracking: ${_detectionHistory.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectedList() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: 10,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detected:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            const Divider(color: Colors.white24),
            if (_stableDetections.isEmpty)
              const Text('Scanning...', style: TextStyle(color: Colors.white54, fontSize: 11))
            else
              ..._stableDetections.map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      _getIconForClass(d.className),
                      color: _getColorForClass(d.className),
                      size: 12,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        d.className,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(DiagnosticStep currentStep) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.95), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Found badge
            if (_componentFound)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${currentStep.cameraFocus} FOUND!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // Title
            Text(
              currentStep.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // Description
            Text(
              currentStep.description,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Target hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '📷 Find: ${currentStep.cameraFocus}',
                style: const TextStyle(color: Colors.blue, fontSize: 12),
              ),
            ),

            // Safety warning
            if (currentStep.safetyWarning.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentStep.safetyWarning,
                        style: const TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Navigation buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentStepIndex > 0 ? _previousStep : null,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _nextStep,
                  icon: Icon(
                    _currentStepIndex < widget.plan.steps.length - 1
                        ? Icons.arrow_forward
                        : Icons.check,
                    size: 16,
                  ),
                  label: Text(
                    _currentStepIndex < widget.plan.steps.length - 1 ? 'Next' : 'Done',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _componentFound ? Colors.green : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForClass(String className) {
    final name = className.toLowerCase();
    if (name.contains('ram')) return Colors.blue;
    if (name.contains('cpu')) return Colors.red;
    if (name.contains('ssd') || name.contains('hdd')) return Colors.orange;
    if (name.contains('battery')) return Colors.yellow;
    if (name.contains('fan')) return Colors.cyan;
    if (name.contains('gpu')) return Colors.pink;
    return Colors.white;
  }

  IconData _getIconForClass(String className) {
    final name = className.toLowerCase();
    if (name.contains('ram')) return Icons.memory;
    if (name.contains('cpu')) return Icons.developer_board;
    if (name.contains('ssd') || name.contains('hdd')) return Icons.storage;
    if (name.contains('battery')) return Icons.battery_full;
    if (name.contains('fan')) return Icons.toys;
    if (name.contains('gpu')) return Icons.videogame_asset;
    return Icons.memory;
  }
}

// Simple stable detection class
class StableDetection {
  String className;
  double confidence;
  double x1, y1, x2, y2;
  int hitCount;
  DateTime lastSeen;

  StableDetection({
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.hitCount,
    required this.lastSeen,
  });

  factory StableDetection.fromDetection(Detection det, DateTime now) {
    return StableDetection(
      className: det.className,
      confidence: det.confidence,
      x1: det.x1.toDouble(),
      y1: det.y1.toDouble(),
      x2: det.x2.toDouble(),
      y2: det.y2.toDouble(),
      hitCount: 1,
      lastSeen: now,
    );
  }

  void update(Detection det, DateTime now) {
    // Smooth position (70% old, 30% new)
    x1 = x1 * 0.7 + det.x1 * 0.3;
    y1 = y1 * 0.7 + det.y1 * 0.3;
    x2 = x2 * 0.7 + det.x2 * 0.3;
    y2 = y2 * 0.7 + det.y2 * 0.3;
    confidence = det.confidence;
    hitCount++;
    lastSeen = now;
  }
}