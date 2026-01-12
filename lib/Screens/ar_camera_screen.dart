import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/diagnostic_plan.dart';
import '../services/yolo_service.dart';
import '../services/detection_stabilizer.dart';
import '../widgets/ar_component_overlay.dart';

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

class _ARCameraScreenState extends State<ARCameraScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  late YoloService _yoloService;
  late DetectionStabilizer _stabilizer;

  bool _isDetecting = false;
  bool _isInitialized = false;
  int _currentStepIndex = 0;
  Timer? _detectionTimer;

  // Debug
  String _serverStatus = 'Connecting...';
  int _framesSent = 0;
  bool _showDebugPanel = false;
  bool _demoMode = false;

  Size _imageSize = const Size(640, 480);
  bool _componentFound = false;

  // Scanning animation
  late AnimationController _gridAnimController;

  @override
  void initState() {
    super.initState();
    _yoloService = YoloService(baseUrl: widget.yoloServerUrl);
    _stabilizer = DetectionStabilizer(
      minFramesToStabilize: 3,
      iouThreshold: 0.3,
      maxAge: const Duration(milliseconds: 2000),
      smoothingFactor: 0.4,
    );

    _gridAnimController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

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
      const Duration(milliseconds: 500),
          (_) => _captureAndDetect(),
    );
  }

  Future<void> _captureAndDetect() async {
    if (_demoMode || _isDetecting || _cameraController == null) return;

    _isDetecting = true;

    try {
      final XFile image = await _cameraController!.takePicture();
      final Uint8List bytes = await image.readAsBytes();

      setState(() => _framesSent++);

      final response = await _yoloService.detectFromBytes(bytes);

      if (response != null && mounted) {
        _stabilizer.update(response.detections);

        setState(() {
          _imageSize = Size(
            response.imageWidth.toDouble(),
            response.imageHeight.toDouble(),
          );
          _serverStatus = '✅ Active';
          _checkCurrentStepComponent();
        });
      }
    } catch (e) {
      setState(() => _serverStatus = '❌ Error');
    } finally {
      _isDetecting = false;
    }
  }

  void _checkCurrentStepComponent() {
    if (_currentStepIndex >= widget.plan.steps.length) return;

    final currentStep = widget.plan.steps[_currentStepIndex];
    final targetComponent = currentStep.cameraFocus.toLowerCase();

    _componentFound = _stabilizer.detections.any(
          (d) => d.className.toLowerCase().contains(targetComponent),
    );
  }

  void _addMockDetections() {
    final screenSize = MediaQuery.of(context).size;
    final random = Random();

    final mockDetections = [
      RawDetection(
        className: 'RAM',
        confidence: 0.92,
        x1: (screenSize.width * 0.1).toInt(),
        y1: (screenSize.height * 0.25).toInt(),
        x2: (screenSize.width * 0.45).toInt(),
        y2: (screenSize.height * 0.42).toInt(),
      ),
      RawDetection(
        className: 'CPU',
        confidence: 0.88,
        x1: (screenSize.width * 0.5).toInt(),
        y1: (screenSize.height * 0.2).toInt(),
        x2: (screenSize.width * 0.9).toInt(),
        y2: (screenSize.height * 0.4).toInt(),
      ),
      RawDetection(
        className: 'SSD',
        confidence: 0.85,
        x1: (screenSize.width * 0.15).toInt(),
        y1: (screenSize.height * 0.5).toInt(),
        x2: (screenSize.width * 0.5).toInt(),
        y2: (screenSize.height * 0.65).toInt(),
      ),
    ];

    _stabilizer.update(mockDetections);
    // Update multiple times to stabilize
    _stabilizer.update(mockDetections);
    _stabilizer.update(mockDetections);

    setState(() {
      _imageSize = screenSize;
      _serverStatus = '🧪 Demo';
      _demoMode = true;
      _checkCurrentStepComponent();
    });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text(
              'Complete!',
              style: TextStyle(color: Colors.white, fontFamily: 'Quantico'),
            ),
          ],
        ),
        content: const Text(
          'All diagnostic steps completed successfully.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('DONE', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _gridAnimController.dispose();
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
          const CircularProgressIndicator(color: Colors.cyan),
          const SizedBox(height: 20),
          const Text(
            'Initializing AR Camera...',
            style: TextStyle(color: Colors.white, fontFamily: 'Quantico'),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _isInitialized = true);
              _addMockDetections();
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Demo Mode'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildARView() {
    final currentStep = widget.plan.steps[_currentStepIndex];
    final screenSize = MediaQuery.of(context).size;
    final targetComponent = currentStep.cameraFocus.toLowerCase();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera
        if (_cameraController != null)
          CameraPreview(_cameraController!),

        // Scanning grid overlay
        AnimatedBuilder(
          animation: _gridAnimController,
          builder: (context, _) {
            return CustomPaint(
              size: Size.infinite,
              painter: ScanGridPainter(
                progress: _gridAnimController.value,
                color: _componentFound ? Colors.green : Colors.cyan,
              ),
            );
          },
        ),

        // AR Component Overlays
        ..._stabilizer.detections.map((detection) {
          final isTarget = detection.className.toLowerCase().contains(targetComponent);
          return ARComponentOverlay(
            key: ValueKey('${detection.className}_${detection.x1}'),
            detection: detection,
            isTarget: isTarget,
            imageSize: _imageSize,
            screenSize: screenSize,
            onTap: () => _showComponentInfo(detection),
          );
        }),

        // Top bar
        _buildTopBar(),

        // Debug panel
        if (_showDebugPanel) _buildDebugPanel(),

        // Bottom panel
        _buildBottomPanel(currentStep),

        // Status indicators
        _buildStatusIndicators(),
      ],
    );
  }

  void _showComponentInfo(StabilizedDetection detection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getColorForClass(detection.className).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForClass(detection.className),
                    color: _getColorForClass(detection.className),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detection.className.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Quantico',
                        ),
                      ),
                      Text(
                        'Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildComponentDetails(detection.className),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getColorForClass(detection.className),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('CLOSE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentDetails(String className) {
    final details = _getComponentDetails(className);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            details['description'] ?? 'No description available',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoChip(Icons.warning, details['warning'] ?? 'Handle with care'),
              const SizedBox(width: 8),
              _infoChip(Icons.build, details['tool'] ?? 'Screwdriver'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Map<String, String> _getComponentDetails(String className) {
    final name = className.toLowerCase();
    if (name.contains('ram')) {
      return {
        'description': 'Random Access Memory - Temporary storage for active programs.',
        'warning': 'ESD sensitive',
        'tool': 'No tools needed',
      };
    }
    if (name.contains('cpu')) {
      return {
        'description': 'Central Processing Unit - The brain of the computer.',
        'warning': 'Apply thermal paste',
        'tool': 'Thermal paste',
      };
    }
    if (name.contains('ssd') || name.contains('hdd')) {
      return {
        'description': 'Storage drive for permanent data storage.',
        'warning': 'Backup data first',
        'tool': 'Screwdriver',
      };
    }
    return {
      'description': 'Computer component',
      'warning': 'Handle carefully',
      'tool': 'Screwdriver',
    };
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
          bottom: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.9), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'STEP ${_currentStepIndex + 1} OF ${widget.plan.steps.length}',
                    style: TextStyle(
                      color: Colors.cyan[300],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: (_currentStepIndex + 1) / widget.plan.steps.length,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(
                      _componentFound ? Colors.green : Colors.cyan,
                    ),
                  ),
                ],
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
      top: MediaQuery.of(context).padding.top + 70,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.cyan.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SERVER: $_serverStatus', style: const TextStyle(color: Colors.white, fontSize: 11)),
            Text('FRAMES: $_framesSent', style: const TextStyle(color: Colors.white, fontSize: 11)),
            Text('STABLE: ${_stabilizer.detections.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
            Text('TRACKING: ${_stabilizer.allDetections.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
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
          left: 20,
          right: 20,
          top: 24,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black, Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Found indicator
            if (_componentFound)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C853), Color(0xFF00E676)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      '${currentStep.cameraFocus} DETECTED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Quantico',
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

            // Step info
            Text(
              currentStep.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Quantico',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              currentStep.description,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Target badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.cyan),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gps_fixed, color: Colors.cyan, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'TARGET: ${currentStep.cameraFocus}',
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontFamily: 'Quantico',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Navigation
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _currentStepIndex > 0 ? _previousStep : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back, size: 18),
                        SizedBox(width: 8),
                        Text('BACK'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _componentFound ? Colors.green : Colors.cyan,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentStepIndex < widget.plan.steps.length - 1
                              ? 'NEXT STEP'
                              : 'COMPLETE',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Quantico',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _currentStepIndex < widget.plan.steps.length - 1
                              ? Icons.arrow_forward
                              : Icons.check,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicators() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 80,
      child: Column(
        children: [
          _statusIndicator(
            icon: Icons.wifi,
            label: 'SERVER',
            isActive: _serverStatus.contains('✅'),
            color: Colors.green,
          ),
          const SizedBox(height: 8),
          _statusIndicator(
            icon: Icons.remove_red_eye,
            label: '${_stabilizer.detections.length}',
            isActive: _stabilizer.detections.isNotEmpty,
            color: Colors.cyan,
          ),
        ],
      ),
    );
  }

  Widget _statusIndicator({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? color : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isActive ? color : Colors.white24),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? color : Colors.white24,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForClass(String className) {
    final name = className.toLowerCase();
    if (name.contains('ram')) return const Color(0xFF00D4FF);
    if (name.contains('cpu')) return const Color(0xFFFF4444);
    if (name.contains('ssd')) return const Color(0xFFFF8800);
    if (name.contains('battery')) return const Color(0xFFFFDD00);
    if (name.contains('fan')) return const Color(0xFF00FFAA);
    return Colors.white;
  }

  IconData _getIconForClass(String className) {
    final name = className.toLowerCase();
    if (name.contains('ram')) return Icons.memory;
    if (name.contains('cpu')) return Icons.developer_board;
    if (name.contains('ssd')) return Icons.storage;
    if (name.contains('battery')) return Icons.battery_full;
    if (name.contains('fan')) return Icons.toys;
    return Icons.memory;
  }
}

// Scanning grid overlay
class ScanGridPainter extends CustomPainter {
  final double progress;
  final Color color;

  ScanGridPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..strokeWidth = 1;

    // Horizontal lines
    const spacing = 50.0;
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Scanning line
    final scanY = size.height * progress;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          color.withOpacity(0.5),
          color,
          color.withOpacity(0.5),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, scanY - 30, size.width, 60));

    canvas.drawRect(Rect.fromLTWH(0, scanY - 30, size.width, 60), scanPaint);
  }

  @override
  bool shouldRepaint(covariant ScanGridPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}