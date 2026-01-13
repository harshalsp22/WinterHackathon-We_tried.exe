import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/diagnostic_plan.dart';
import '../services/yolo_service.dart';
import '../widgets/ar_3d_indicator.dart';

enum ComponentStatus { critical, warning, ok }

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

      final response = await _yoloService.detectFromBytes(bytes, confidence: 0.15);

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

  ComponentStatus _getComponentStatus(String componentName) {
    final lowerName = componentName.toLowerCase();
    if (_componentStatus.containsKey(lowerName)) {
      return _componentStatus[lowerName]!;
    }
    final currentStep = widget.plan.steps[_currentStepIndex];
    final targetComponent = currentStep.cameraFocus.toLowerCase();
    if (lowerName.contains(targetComponent)) return ComponentStatus.warning;
    if (_checkedComponents.contains(lowerName)) return ComponentStatus.ok;
    return ComponentStatus.critical;
  }

  IndicatorStatus _toIndicatorStatus(ComponentStatus status) {
    switch (status) {
      case ComponentStatus.critical:
        return IndicatorStatus.critical;
      case ComponentStatus.warning:
        return IndicatorStatus.warning;
      case ComponentStatus.ok:
        return IndicatorStatus.ok;
    }
  }

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
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Component info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForClass(detection.className),
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detection.className.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'SET COMPONENT STATUS',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),

            // Status buttons
            Row(
              children: [
                Expanded(
                  child: _StatusButton(
                    label: 'CRITICAL',
                    subtitle: 'Needs Fix',
                    color: Colors.red,
                    icon: Icons.error,
                    onTap: () {
                      _markComponentStatus(detection.className, ComponentStatus.critical);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatusButton(
                    label: 'WARNING',
                    subtitle: 'Check Later',
                    color: Colors.orange,
                    icon: Icons.warning_amber,
                    onTap: () {
                      _markComponentStatus(detection.className, ComponentStatus.warning);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatusButton(
                    label: 'OK',
                    subtitle: 'All Good',
                    color: Colors.green,
                    icon: Icons.check_circle,
                    onTap: () {
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
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStepIndex < widget.plan.steps.length - 1) {
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
    int critical = 0, warning = 0, ok = 0;
    _componentStatus.forEach((_, status) {
      if (status == ComponentStatus.critical) critical++;
      if (status == ComponentStatus.warning) warning++;
      if (status == ComponentStatus.ok) ok++;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'DIAGNOSTIC COMPLETE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 24),
              _SummaryRow(icon: Icons.error, label: 'Critical', count: critical, color: Colors.red),
              _SummaryRow(icon: Icons.warning, label: 'Warning', count: warning, color: Colors.orange),
              _SummaryRow(icon: Icons.check_circle, label: 'OK', count: ok, color: Colors.green),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
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
          x1: screenSize.width * 0.08,
          y1: screenSize.height * 0.28,
          x2: screenSize.width * 0.42,
          y2: screenSize.height * 0.42,
          hitCount: 5,
          lastSeen: DateTime.now(),
        ),
        StableDetection(
          className: 'CPU',
          confidence: 0.88,
          x1: screenSize.width * 0.52,
          y1: screenSize.height * 0.25,
          x2: screenSize.width * 0.88,
          y2: screenSize.height * 0.40,
          hitCount: 5,
          lastSeen: DateTime.now(),
        ),
        StableDetection(
          className: 'SSD',
          confidence: 0.85,
          x1: screenSize.width * 0.12,
          y1: screenSize.height * 0.48,
          x2: screenSize.width * 0.48,
          y2: screenSize.height * 0.62,
          hitCount: 5,
          lastSeen: DateTime.now(),
        ),
      ];
      _imageSize = screenSize;
      _serverStatus = '🧪 Mock';
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
          const SizedBox(height: 20),
          const Text('Initializing camera...', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 30),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _isInitialized = true);
              _addMockDetections();
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('DEMO MODE'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
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
        // Camera preview
        if (_cameraController != null) CameraPreview(_cameraController!),

        // AR Overlays with 3D indicators
        ..._stableDetections.map((det) {
          final isTarget = det.className.toLowerCase().contains(targetComponent);
          final status = _getComponentStatus(det.className);

          return _ARComponentOverlay(
            key: ValueKey(det.className),
            detection: det,
            imageSize: _imageSize,
            screenSize: screenSize,
            isTarget: isTarget,
            status: status,
            onTap: () => _showComponentStatusDialog(det),
          );
        }),

        // Top bar
        _buildTopBar(),

        // Debug panel
        if (_showDebugPanel) _buildDebugPanel(),

        // Legend
        _buildLegend(),

        // Bottom panel
        _buildBottomPanel(currentStep),
      ],
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
          left: 12,
          right: 12,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            _GlassButton(
              icon: Icons.arrow_back,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'STEP ${_currentStepIndex + 1} / ${widget.plan.steps.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _GlassButton(
              icon: Icons.science,
              color: Colors.orange,
              onPressed: _addMockDetections,
            ),
            const SizedBox(width: 8),
            _GlassButton(
              icon: Icons.bug_report,
              color: _showDebugPanel ? Colors.green : Colors.white54,
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
      left: 12,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server: $_serverStatus', style: const TextStyle(color: Colors.white, fontSize: 11)),
            Text('Frames: $_framesSent', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text('Detected: ${_stableDetections.length}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('STATUS', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
            const SizedBox(height: 8),
            _LegendItem(color: Colors.red, label: 'Critical'),
            _LegendItem(color: Colors.orange, label: 'Check'),
            _LegendItem(color: Colors.green, label: 'OK'),
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
          top: 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black, Colors.transparent],
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
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 15),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      '${currentStep.cameraFocus} DETECTED',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            Text(
              currentStep.title,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              currentStep.description,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Target
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.cyan),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '🎯 TARGET: ${currentStep.cameraFocus}',
                style: TextStyle(color: Colors.cyan[400], fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 20),

            // Navigation
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _currentStepIndex > 0 ? _previousStep : null,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('PREVIOUS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _nextStep,
                    icon: Icon(
                      _currentStepIndex < widget.plan.steps.length - 1 ? Icons.arrow_forward : Icons.check,
                      size: 18,
                    ),
                    label: Text(_currentStepIndex < widget.plan.steps.length - 1 ? 'NEXT STEP' : 'COMPLETE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _componentFound ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
// AR COMPONENT OVERLAY WITH 3D INDICATOR
// ============================================

class _ARComponentOverlay extends StatefulWidget {
  final StableDetection detection;
  final Size imageSize;
  final Size screenSize;
  final bool isTarget;
  final ComponentStatus status;
  final VoidCallback onTap;

  const _ARComponentOverlay({
    super.key,
    required this.detection,
    required this.imageSize,
    required this.screenSize,
    required this.isTarget,
    required this.status,
    required this.onTap,
  });

  @override
  State<_ARComponentOverlay> createState() => _ARComponentOverlayState();
}

class _ARComponentOverlayState extends State<_ARComponentOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
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

  IndicatorStatus get _indicatorStatus {
    switch (widget.status) {
      case ComponentStatus.critical:
        return IndicatorStatus.critical;
      case ComponentStatus.warning:
        return IndicatorStatus.warning;
      case ComponentStatus.ok:
        return IndicatorStatus.ok;
    }
  }

  Color _getColorForClass(String className) {
    final name = className.toLowerCase();
    if (name.contains('ram')) return const Color(0xFF2196F3);
    if (name.contains('cpu')) return const Color(0xFFE91E63);
    if (name.contains('ssd') || name.contains('hdd')) return const Color(0xFFFF9800);
    if (name.contains('battery')) return const Color(0xFFFFEB3B);
    if (name.contains('fan')) return const Color(0xFF00BCD4);
    if (name.contains('gpu')) return const Color(0xFF9C27B0);
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

  @override
  Widget build(BuildContext context) {
    final det = widget.detection;
    final scaleX = widget.screenSize.width / widget.imageSize.width;
    final scaleY = widget.screenSize.height / widget.imageSize.height;

    final x = (det.x1 * scaleX).clamp(0.0, widget.screenSize.width - 60);
    final y = (det.y1 * scaleY).clamp(0.0, widget.screenSize.height - 60);
    final width = ((det.x2 - det.x1) * scaleX).clamp(80.0, widget.screenSize.width - x);
    final height = ((det.y2 - det.y1) * scaleY).clamp(80.0, widget.screenSize.height - y);

    final boxColor = widget.isTarget ? _statusColor : _getColorForClass(det.className);

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final pulse = _pulseAnimation.value;

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
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _statusColor.withOpacity(0.3 + pulse * 0.2),
                              blurRadius: 20 + pulse * 10,
                              spreadRadius: pulse * 5,
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
                          color: boxColor.withOpacity(0.6 + pulse * 0.4),
                          width: widget.isTarget ? 3 : 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  // Corners
                  ..._buildCorners(width, height, boxColor, pulse),

                  // Component label
                  Positioned(
                    top: -32,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: boxColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getIconForClass(det.className), color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '${det.className} ${(det.confidence * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Center icon
                  Center(
                    child: Transform.scale(
                      scale: 1.0 + pulse * 0.08,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                          border: Border.all(color: boxColor.withOpacity(0.6 + pulse * 0.4), width: 2),
                        ),
                        child: Icon(_getIconForClass(det.className), color: boxColor, size: 26),
                      ),
                    ),
                  ),

                  // ========== 3D ARROW INDICATOR ==========
                  Positioned(
                    top: -140,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AR3DIndicator(
                        status: _indicatorStatus,
                        componentName: det.className,
                        size: 100,
                        onTap: widget.onTap,
                      ),
                    ),
                  ),
                  // =========================================

                  // Tap hint
                  Positioned(
                    bottom: -22,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'TAP TO SET STATUS',
                          style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1),
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
    const size = 24.0;
    final opacity = 0.6 + pulse * 0.4;

    Widget corner(Alignment align) {
      return Positioned(
        top: align == Alignment.topLeft || align == Alignment.topRight ? 0 : null,
        bottom: align == Alignment.bottomLeft || align == Alignment.bottomRight ? 0 : null,
        left: align == Alignment.topLeft || align == Alignment.bottomLeft ? 0 : null,
        right: align == Alignment.topRight || align == Alignment.bottomRight ? 0 : null,
        child: CustomPaint(
          size: const Size(size, size),
          painter: _CornerPainter(alignment: align, color: color.withOpacity(opacity), strokeWidth: 3),
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
}

// ============================================
// HELPER WIDGETS
// ============================================

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const _GlassButton({required this.icon, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 22),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SummaryRow({required this.icon, required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ============================================
// CORNER PAINTER
// ============================================

class _CornerPainter extends CustomPainter {
  final Alignment alignment;
  final Color color;
  final double strokeWidth;

  _CornerPainter({required this.alignment, required this.color, required this.strokeWidth});

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
  bool shouldRepaint(covariant _CornerPainter oldDelegate) => false;
}

// ============================================
// DATA CLASS
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