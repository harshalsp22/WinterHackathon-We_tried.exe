import 'dart:math';
import 'package:flutter/material.dart';
import '../services/detection_stabilizer.dart';

class ARComponentOverlay extends StatefulWidget {
  final StabilizedDetection detection;
  final bool isTarget;
  final Size imageSize;
  final Size screenSize;
  final VoidCallback? onTap;

  const ARComponentOverlay({
    super.key,
    required this.detection,
    required this.isTarget,
    required this.imageSize,
    required this.screenSize,
    this.onTap,
  });

  @override
  State<ARComponentOverlay> createState() => _ARComponentOverlayState();
}

class _ARComponentOverlayState extends State<ARComponentOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Scanning line animation
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_scanController);

    // Rotation animation for corners
    _rotateController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final det = widget.detection;
    final scaleX = widget.screenSize.width / widget.imageSize.width;
    final scaleY = widget.screenSize.height / widget.imageSize.height;

    final x = det.x1 * scaleX;
    final y = det.y1 * scaleY;
    final width = det.width * scaleX;
    final height = det.height * scaleY;

    final color = _getColorForClass(det.className);
    final isTarget = widget.isTarget;

    return Positioned(
      left: x.clamp(0, widget.screenSize.width - 60),
      top: y.clamp(0, widget.screenSize.height - 60),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _scanAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: isTarget ? _pulseAnimation.value : 1.0,
              child: SizedBox(
                width: width.clamp(80, widget.screenSize.width - x),
                height: height.clamp(80, widget.screenSize.height - y),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Glow effect for target
                    if (isTarget)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Main container with gradient border
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isTarget ? Colors.green : color,
                            width: isTarget ? 3 : 2,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withOpacity(0.1),
                              color.withOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Scanning line effect
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CustomPaint(
                          painter: ScanLinePainter(
                            progress: _scanAnimation.value,
                            color: isTarget ? Colors.green : color,
                          ),
                        ),
                      ),
                    ),

                    // Animated corners
                    ...buildAnimatedCorners(width, height, isTarget ? Colors.green : color),

                    // Component info card
                    Positioned(
                      top: -45,
                      left: 0,
                      right: 0,
                      child: _buildInfoCard(det, color, isTarget),
                    ),

                    // Target indicator
                    if (isTarget) _buildTargetIndicator(),

                    // Component icon
                    Center(
                      child: _buildComponentIcon(det.className, isTarget),
                    ),

                    // Stability indicator
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: _buildStabilityIndicator(det),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard(StabilizedDetection det, Color color, bool isTarget) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isTarget ? Colors.green : color).withOpacity(0.9),
            (isTarget ? Colors.green : color).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIconForClass(det.className),
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              det.className.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Quantico',
                letterSpacing: 1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${(det.confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetIndicator() {
    return Positioned(
      top: -70,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'TARGET',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.green, size: 24),
        ],
      ),
    );
  }

  Widget _buildComponentIcon(String className, bool isTarget) {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.5),
            border: Border.all(
              color: isTarget ? Colors.green.withOpacity(0.5) : Colors.white24,
              width: 2,
            ),
          ),
          child: Icon(
            _getIconForClass(className),
            color: isTarget ? Colors.green : Colors.white70,
            size: 28,
          ),
        );
      },
    );
  }

  Widget _buildStabilityIndicator(StabilizedDetection det) {
    final stability = (det.frameCount / 10).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            det.isStable ? Icons.lock : Icons.sync,
            color: det.isStable ? Colors.green : Colors.orange,
            size: 12,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 30,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: stability,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(
                  det.isStable ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> buildAnimatedCorners(double width, double height, Color color) {
    const cornerSize = 20.0;
    const thickness = 3.0;

    Widget corner(Alignment alignment) {
      return Positioned(
        left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? 0 : null,
        right: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? 0 : null,
        top: alignment == Alignment.topLeft || alignment == Alignment.topRight ? 0 : null,
        bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight ? 0 : null,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(cornerSize, cornerSize),
              painter: CornerPainter(
                alignment: alignment,
                color: color,
                thickness: thickness,
                glowIntensity: _pulseAnimation.value,
              ),
            );
          },
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
    if (name.contains('ram')) return const Color(0xFF00D4FF);
    if (name.contains('cpu')) return const Color(0xFFFF4444);
    if (name.contains('ssd') || name.contains('hdd')) return const Color(0xFFFF8800);
    if (name.contains('battery')) return const Color(0xFFFFDD00);
    if (name.contains('fan')) return const Color(0xFF00FFAA);
    if (name.contains('gpu')) return const Color(0xFFFF00AA);
    if (name.contains('wifi')) return const Color(0xFF00AAFF);
    if (name.contains('motherboard')) return const Color(0xFFAA00FF);
    return const Color(0xFFFFFFFF);
  }

  IconData _getIconForClass(String className) {
    final name = className.toLowerCase();
    if (name.contains('ram')) return Icons.memory;
    if (name.contains('cpu')) return Icons.developer_board;
    if (name.contains('ssd') || name.contains('hdd')) return Icons.storage;
    if (name.contains('battery')) return Icons.battery_full;
    if (name.contains('fan')) return Icons.toys;
    if (name.contains('gpu')) return Icons.videogame_asset;
    if (name.contains('wifi')) return Icons.wifi;
    if (name.contains('motherboard')) return Icons.dashboard;
    return Icons.memory;
  }
}

// Scanning line effect painter
class ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          color.withOpacity(0.5),
          color.withOpacity(0.8),
          color.withOpacity(0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 20, size.width, 40));

    canvas.drawRect(
      Rect.fromLTWH(0, y - 20, size.width, 40),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Corner bracket painter with glow
class CornerPainter extends CustomPainter {
  final Alignment alignment;
  final Color color;
  final double thickness;
  final double glowIntensity;

  CornerPainter({
    required this.alignment,
    required this.color,
    required this.thickness,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3 * glowIntensity)
      ..strokeWidth = thickness + 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

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

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CornerPainter oldDelegate) {
    return oldDelegate.glowIntensity != glowIntensity;
  }
}