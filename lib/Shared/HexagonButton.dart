import 'package:flutter/material.dart';

class HexagonButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color color;
  final double width;
  final double height;

  const HexagonButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color = Colors.white,
    this.width = 200,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: ClipPath(
        clipper: HexagonClipper(),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: color,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: width,
              height: height,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cut = h * 0.5;

    return Path()
      ..moveTo(cut, 0)
      ..lineTo(w - cut, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w - cut, h)
      ..lineTo(cut, h)
      ..lineTo(0, h / 2)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
