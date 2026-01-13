import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/diagnostic_plan.dart';
import '../services/yolo_service.dart';

// Component Status Enum
enum ComponentStatus {
  critical,  // Red - Crucial, needs immediate attention
  warning,   // Yellow - Needs to be checked
  ok,        // Green - All OK
}

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

  List<StableDetection> _stableDetections = [];
  final Map<String, StableDetection> _detectionHistory = {};

  // Track checked components and their status
  final Map<String, ComponentStatus> _componentStatus = {};
  final Set<String> _checkedComponents = {};

  bool _isDetecting = false;
  bool _isInitialized = false;
  int _currentStepIndex = 0;
  Timer? _detectionTimer;

  String _serverStatus = 'Connecting...';
  int _framesSent = 0;
  bool _showDebugPanel = false;

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
      const Duration(milliseconds: 600),
          (_) => _captureAndDetect(),
    );
  }

  Future<void> _captureAndDetect() async {
    if (_isDetecting ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    _isDetecting = true;

    try {
      final XFile image = await _cameraController!.takePicture();
      final Uint8List bytes = await image.readAsBytes();

      setState(() => _framesSent++);

      final response =
      await _yoloService.detectFromBytes(bytes, confidence: 0.15);

      if (response != null && mounted) {
        _updateStableDetections(response.detections);

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

  void _updateStableDetections(List<Detection> newDetections) {
    final now = DateTime.now();

    for (final det in newDetections) {
      final key = det.className;

      if (_detectionHistory.containsKey(key)) {
        _detectionHistory[key]!.update(det, now);
      } else {
        _detectionHistory[key] = StableDetection.fromDetection(det, now);
      }
    }

    _detectionHistory.removeWhere(
          (key, det) => now.difference(det.lastSeen).inMilliseconds > 2000,
    );

    _stableDetections =
        _detectionHistory.values.where((d) => d.hitCount >= 2).toList();
  }

  void _checkCurrentStepComponent() {
    if (_currentStepIndex >= widget.plan.steps.length) return;

    final currentStep = widget.plan.steps[_currentStepIndex];
    final targetComponent = currentStep.cameraFocus.toLowerCase();

    _componentFound = _stableDetections
        .any((d) => d.className.toLowerCase().contains(targetComponent));
  }

  // Get component status based on current step and check history
  ComponentStatus _getComponentStatus(String componentName) {
    final lowerName = componentName.toLowerCase();

    // If already set by user, return that status
    if (_componentStatus.containsKey(lowerName)) {
      return _componentStatus[lowerName]!;
    }

    final currentStep = widget.plan.steps[_currentStepIndex];
    final targetComponent = currentStep.cameraFocus.toLowerCase();

    // Current target = Yellow (needs checking)
    if (lowerName.contains(targetComponent)) {
      return ComponentStatus.warning;
    }

    // Already checked = Green
    if (_checkedComponents.contains(lowerName)) {
      return ComponentStatus.ok;
    }

    // Not yet checked and not current target = Red (crucial)
    return ComponentStatus.critical;
  }

  // Mark component as checked with status
  void _markComponentStatus(String componentName, ComponentStatus status) {
    setState(() {
      final lowerName = componentName.toLowerCase();
      _componentStatus[lowerName] = status;
      _checkedComponents.add(lowerName);
    });
  }

  void _showComponentStatusDialog(StableDetection detection) {
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
            // Component name
            Row(
              children: [
                Icon(
                  _getIconForClass(detection.className),
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  detection.className.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Set Component Status:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Status buttons
            Row(
              children: [
                Expanded(
                  child: _statusButton(
                    'CRITICAL',
                    'Needs Fix',
                    Colors.red,
                    Icons.error,
                        () {
                      _markComponentStatus(detection.className, ComponentStatus.critical);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statusButton(
                    'WARNING',
                    'Check Later',
                    Colors.orange,
                    Icons.warning,
                        () {
                      _markComponentStatus(detection.className, ComponentStatus.warning);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statusButton(
                    'OK',
                    'All Good',
                    Colors.green,
                    Icons.check_circle,
                        () {
                      _markComponentStatus(detection.className, ComponentStatus.ok);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(
      String title,
      String subtitle,
      Color color,
      IconData icon,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStepIndex < widget.plan.steps.length - 1) {
      // Mark current target as checked if not already
      final currentStep = widget.plan.steps[_currentStepIndex];
      final target = currentStep.cameraFocus.toLowerCase();
      if (!_componentStatus.containsKey(target)) {
        _checkedComponents.add(target);
      }

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
    // Count status summary
    int critical = 0, warning = 0, ok = 0;
    _componentStatus.forEach((key, status) {
      if (status == ComponentStatus.critical) critical++;
      if (status == ComponentStatus.warning) warning++;
      if (status == ComponentStatus.ok) ok++;
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Row(
          children: [
            Icon(Icons.flag, color: Colors.white),
            SizedBox(width: 8),
            Text('Diagnostic Summary', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow(Icons.error, 'Critical', critical, Colors.red),
            _summaryRow(Icons.warning, 'Warning', warning, Colors.orange),
            _summaryRow(Icons.check_circle, 'OK', ok, Colors.green),
          ],
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

  Widget _summaryRow(IconData icon, String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

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
        StableDetection(
          className: 'SSD',
          confidence: 0.85,
          x1: screenSize.width * 0.15,
          y1: screenSize.height * 0.45,
          x2: screenSize.width * 0.5,
          y2: screenSize.height * 0.58,
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
          const Text('Initializing camera...',
              style: TextStyle(color: Colors.white)),
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
    final targetComponent = currentStep.cameraFocus.toLowerCase();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Preview
        if (_cameraController != null) CameraPreview(_cameraController!),

        // AR Bounding Boxes with Flags
        ..._stableDetections.map((det) {
          final isTarget =
          det.className.toLowerCase().contains(targetComponent);
          final status = _getComponentStatus(det.className);

          return ARBoundingBoxWithFlag(
            key: ValueKey(det.className),
            detection: det,
            imageSize: _imageSize,
            screenSize: screenSize,
            isTarget: isTarget,
            status: status,
            onTap: () => _showComponentStatusDialog(det),
          );
        }),

        // Top Bar
        _buildTopBar(),

        // Debug Panel
        if (_showDebugPanel) _buildDebugPanel(),

        // Legend
        _buildLegend(),

        // Bottom Panel
        _buildBottomPanel(currentStep),
      ],
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            _legendItem(Colors.red, 'Critical'),
            _legendItem(Colors.orange, 'Check'),
            _legendItem(Colors.green, 'OK'),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
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
              onPressed: () =>
                  setState(() => _showDebugPanel = !_showDebugPanel),
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
            Text('Server: $_serverStatus',
                style: const TextStyle(color: Colors.white, fontSize: 11)),
            Text('Frames: $_framesSent',
                style: const TextStyle(color: Colors.white, fontSize: 11)),
            Text('Detected: ${_stableDetections.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11)),
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
            if (_componentFound)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${currentStep.cameraFocus} FOUND! Tap to set status',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

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

            Text(
              currentStep.description,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

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
                        style:
                        const TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

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
                    _currentStepIndex < widget.plan.steps.length - 1
                        ? 'Next'
                        : 'Done',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    _componentFound ? Colors.green : Colors.blue,
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

// ============================================
// AR BOUNDING BOX WITH 3D FLAG
// ============================================

class ARBoundingBoxWithFlag extends StatefulWidget {
  final StableDetection detection;
  final Size imageSize;
  final Size screenSize;
  final bool isTarget;
  final ComponentStatus status;
  final VoidCallback onTap;

  const ARBoundingBoxWithFlag({
    super.key,
    required this.detection,
    required this.imageSize,
    required this.screenSize,
    required this.isTarget,
    required this.status,
    required this.onTap,
  });

  @override
  State<ARBoundingBoxWithFlag> createState() => _ARBoundingBoxWithFlagState();
}

class _ARBoundingBoxWithFlagState extends State<ARBoundingBoxWithFlag>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.status) {
      case ComponentStatus.critical:
        return Colors.red;
      case ComponentStatus.warning:
        return Colors.orange;
      case ComponentStatus.ok:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final det = widget.detection;
    final scaleX = widget.screenSize.width / widget.imageSize.width;
    final scaleY = widget.screenSize.height / widget.imageSize.height;

    final x = (det.x1 * scaleX).clamp(0.0, widget.screenSize.width - 60);
    final y = (det.y1 * scaleY).clamp(0.0, widget.screenSize.height - 60);
    final width =
    ((det.x2 - det.x1) * scaleX).clamp(80.0, widget.screenSize.width - x);
    final height =
    ((det.y2 - det.y1) * scaleY).clamp(80.0, widget.screenSize.height - y);

    final boxColor = widget.isTarget ? _statusColor : _getColorForClass(det.className);

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final pulseValue = _pulseAnimation.value;

            return SizedBox(
              width: width,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Glow effect
                  if (widget.isTarget)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: _statusColor.withOpacity(0.3 + pulseValue * 0.2),
                              blurRadius: 15 + pulseValue * 10,
                              spreadRadius: pulseValue * 5,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Main border
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: boxColor.withOpacity(0.7 + pulseValue * 0.3),
                          width: widget.isTarget ? 3 : 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  // Corner brackets
                  ..._buildCorners(width, height, boxColor, pulseValue),

                  // Label
                  Positioned(
                    top: -30,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: boxColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getIconForClass(det.className),
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
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
                    child: Transform.scale(
                      scale: 1.0 + pulseValue * 0.1,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: boxColor.withOpacity(0.7 + pulseValue * 0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _getIconForClass(det.className),
                          color: boxColor,
                          size: 24,
                        ),
                      ),
                    ),
                  ),

                  // 3D Flag
                  Positioned(
                    top: -70,
                    right: 0,
                    child: Flag3D(
                      status: widget.status,
                      pulseValue: pulseValue,
                    ),
                  ),

                  // Tap hint
                  Positioned(
                    bottom: -20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Tap to set status',
                          style: TextStyle(color: Colors.white54, fontSize: 9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildCorners(double w, double h, Color color, double pulse) {
    const size = 20.0;
    final opacity = 0.7 + pulse * 0.3;

    Widget corner(Alignment align) {
      return Positioned(
        top: align == Alignment.topLeft || align == Alignment.topRight
            ? 0
            : null,
        bottom: align == Alignment.bottomLeft || align == Alignment.bottomRight
            ? 0
            : null,
        left: align == Alignment.topLeft || align == Alignment.bottomLeft
            ? 0
            : null,
        right: align == Alignment.topRight || align == Alignment.bottomRight
            ? 0
            : null,
        child: CustomPaint(
          size: const Size(size, size),
          painter: CornerPainter(
            alignment: align,
            color: color.withOpacity(opacity),
            strokeWidth: 3,
          ),
        ),
      );
    }

    return [
      corner(Alignment.topLeft),
      corner(Alignment.topRight),
      corner(Alignment.bottomLeft),
      corner(Alignment.bottomRight),
    ];
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

// ============================================
// 3D FLAG WIDGET
// ============================================

class Flag3D extends StatefulWidget {
  final ComponentStatus status;
  final double pulseValue;

  const Flag3D({
    super.key,
    required this.status,
    required this.pulseValue,
  });

  @override
  State<Flag3D> createState() => _Flag3DState();
}

class _Flag3DState extends State<Flag3D> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Color get _flagColor {
    switch (widget.status) {
      case ComponentStatus.critical:
        return Colors.red;
      case ComponentStatus.warning:
        return Colors.orange;
      case ComponentStatus.ok:
        return Colors.green;
    }
  }

  IconData get _flagIcon {
    switch (widget.status) {
      case ComponentStatus.critical:
        return Icons.error;
      case ComponentStatus.warning:
        return Icons.warning;
      case ComponentStatus.ok:
        return Icons.check;
    }
  }

  String get _flagLabel {
    switch (widget.status) {
      case ComponentStatus.critical:
        return '!';
      case ComponentStatus.warning:
        return '?';
      case ComponentStatus.ok:
        return '✓';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final waveValue = _waveController.value;

        return SizedBox(
          width: 50,
          height: 60,
          child: Stack(
            children: [
              // Flag pole (3D effect)
              Positioned(
                left: 5,
                top: 0,
                child: Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.grey[600]!,
                        Colors.grey[400]!,
                        Colors.grey[600]!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 2,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Pole top ball
              Positioned(
                left: 2,
                top: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.grey[300]!,
                        Colors.grey[600]!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),

              // 3D Flag with wave effect
              Positioned(
                left: 9,
                top: 5,
                child: Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002) // perspective
                    ..rotateY(waveValue * 0.2 - 0.1), // wave
                  child: Container(
                    width: 40,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _flagColor,
                          _flagColor.withOpacity(0.8),
                          _flagColor.withOpacity(0.6),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _flagColor.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Wave effect overlay
                        Positioned.fill(
                          child: CustomPaint(
                            painter: FlagWavePainter(
                              waveValue: waveValue,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),

                        // Icon in center
                        Center(
                          child: Icon(
                            _flagIcon,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Flag tail (triangle)
              Positioned(
                left: 49,
                top: 5,
                child: Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002)
                    ..rotateY(waveValue * 0.3 - 0.15),
                  child: CustomPaint(
                    size: const Size(8, 28),
                    painter: FlagTailPainter(color: _flagColor.withOpacity(0.6)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Flag wave pattern painter
class FlagWavePainter extends CustomPainter {
  final double waveValue;
  final Color color;

  FlagWavePainter({required this.waveValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);

    for (double x = 0; x <= size.width; x++) {
      final y = math.sin((x / size.width * 2 * math.pi) + (waveValue * math.pi * 2)) * 3;
      path.lineTo(x, y + size.height / 2);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FlagWavePainter oldDelegate) {
    return oldDelegate.waveValue != waveValue;
  }
}

// Flag tail triangle painter
class FlagTailPainter extends CustomPainter {
  final Color color;

  FlagTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FlagTailPainter oldDelegate) => false;
}

// ============================================
// CORNER PAINTER
// ============================================

class CornerPainter extends CustomPainter {
  final Alignment alignment;
  final Color color;
  final double strokeWidth;

  CornerPainter({
    required this.alignment,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (alignment == Alignment.topLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CornerPainter oldDelegate) => false;
}

// ============================================
// STABLE DETECTION CLASS
// ============================================

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
    x1 = x1 * 0.7 + det.x1 * 0.3;
    y1 = y1 * 0.7 + det.y1 * 0.3;
    x2 = x2 * 0.7 + det.x2 * 0.3;
    y2 = y2 * 0.7 + det.y2 * 0.3;
    confidence = det.confidence;
    hitCount++;
    lastSeen = now;
  }
}