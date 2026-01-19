import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

enum IndicatorStatus { critical, warning, ok }

class AR3DIndicator extends StatefulWidget {
  final IndicatorStatus status;
  final String componentName;
  final double size;
  final VoidCallback? onTap;

  const AR3DIndicator({
    super.key,
    required this.status,
    required this.componentName,
    this.size = 100,
    this.onTap,
  });

  @override
  State<AR3DIndicator> createState() => _AR3DIndicatorState();
}

class _AR3DIndicatorState extends State<AR3DIndicator>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _glowController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Bounce animation
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Color get _primaryColor {
    switch (widget.status) {
      case IndicatorStatus.critical:
        return const Color(0xFFFF1744);
      case IndicatorStatus.warning:
        return const Color(0xFFFF9100);
      case IndicatorStatus.ok:
        return const Color(0xFF00E676);
    }
  }

  Color get _secondaryColor {
    switch (widget.status) {
      case IndicatorStatus.critical:
        return const Color(0xFFFF5252);
      case IndicatorStatus.warning:
        return const Color(0xFFFFAB40);
      case IndicatorStatus.ok:
        return const Color(0xFF69F0AE);
    }
  }

  String get _statusLabel {
    switch (widget.status) {
      case IndicatorStatus.critical:
        return 'CRITICAL';
      case IndicatorStatus.warning:
        return 'CHECK';
      case IndicatorStatus.ok:
        return 'OK';
    }
  }

  IconData get _statusIcon {
    switch (widget.status) {
      case IndicatorStatus.critical:
        return Icons.error;
      case IndicatorStatus.warning:
        return Icons.warning_amber_rounded;
      case IndicatorStatus.ok:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bounceAnimation, _glowAnimation]),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _bounceAnimation.value),
            child: SizedBox(
              width: widget.size,
              height: widget.size + 30,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Glow effect behind the model
                  Positioned(
                    top: widget.size * 0.2,
                    child: Container(
                      width: widget.size * 0.5,
                      height: widget.size * 0.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(_glowAnimation.value * 0.6),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ========== YOUR 3D MODEL ==========
                  Positioned(
                    top: 0,
                    child: SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: ModelViewer(
                        src: 'assets/models/arrow_indicator.glb',
                        alt: "3D Arrow Indicator",
                        autoPlay: true,
                        autoRotate: true,
                        rotationPerSecond: "45deg",
                        cameraControls: false,
                        disableZoom: true,
                        disablePan: true,
                        disableTap: true,
                        backgroundColor: Colors.transparent,
                        exposure: 1.2,
                      ),
                    ),
                  ),
                  // ====================================

                  // Color tint overlay
                  Positioned(
                    top: widget.size * 0.15,
                    child: IgnorePointer(
                      child: Container(
                        width: widget.size * 0.7,
                        height: widget.size * 0.7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _primaryColor.withOpacity(_glowAnimation.value * 0.3),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.8],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Status label at bottom
                  Positioned(
                    bottom: 0,
                    child: Transform.scale(
                      scale: 1.0 + (_glowAnimation.value - 0.65) * 0.1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_primaryColor, _secondaryColor],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcon, color: Colors.white, size: 14),
                            const SizedBox(width: 5),
                            Text(
                              _statusLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}