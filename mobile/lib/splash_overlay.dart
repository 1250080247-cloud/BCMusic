import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Orbit Glow launch splash overlay (~1050ms) that smoothly reveals [child]
/// and removes itself completely once finished.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1050);
  static const _logoAsset = 'assets/images/logo.png';
  static const _logoSize = 92.0;
  static const _orbitPadding = 7.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );
  final GlobalKey _childKey = GlobalKey();

  bool _finished = false;
  bool _started = false;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleStatus);
    if (!widget.enabled) {
      _finished = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (!widget.enabled || disableAnimations) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _finished = true;
      return;
    }

    if (!_finished && !_started) {
      _started = true;
      if (!_precached) {
        _precached = true;
        unawaited(precacheImage(const AssetImage(_logoAsset), context));
      }
      unawaited(_controller.forward());
    }
  }

  @override
  void didUpdateWidget(covariant SplashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && !_finished) {
      _controller.stop();
      _finished = true;
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_finished && mounted) {
      setState(() => _finished = true);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (!widget.enabled || disableAnimations) {
      return _started
          ? KeyedSubtree(key: _childKey, child: widget.child)
          : widget.child;
    }
    if (_finished) {
      return _started
          ? KeyedSubtree(key: _childKey, child: widget.child)
          : widget.child;
    }

    final light = Theme.of(context).brightness == Brightness.light;
    final palette = context.palette;
    final background = light
        ? const Color(0xfff6f7fb)
        : const Color(0xff0b0b10);
    final titleColor = light ? palette.text : const Color(0xfff4f5fa);
    final accentDotColor = light ? palette.action : const Color(0xffc2abf3);
    final subtitleColor = light ? palette.muted : const Color(0xff9b91ad);

    final keyedChild = KeyedSubtree(key: _childKey, child: widget.child);

    return AnimatedBuilder(
      animation: _controller,
      child: keyedChild,
      builder: (context, child) {
        final t = _controller.value;

        // Phase 1 (0% -> 40%, 0-420ms): Logo entrance.
        final logoT = const Interval(
          0.0,
          0.40,
          curve: Curves.easeOutCubic,
        ).transform(t);
        final logoOpacity = logoT;
        final logoScale = lerpDouble(0.86, 1.0, logoT)!;

        // Orbit Glow (0% -> 74%, 0-780ms): SweepGradient ring around logo.
        final orbitT = const Interval(
          0.0,
          0.74,
          curve: Curves.easeOutCubic,
        ).transform(t);
        final orbitFadeIn = const Interval(
          0.0,
          0.16,
          curve: Curves.easeOut,
        ).transform(t);
        final orbitFadeOut = 1.0 -
            const Interval(
              0.56,
              0.74,
              curve: Curves.easeInCubic,
            ).transform(t);
        final orbitOpacity = (orbitFadeIn * orbitFadeOut).clamp(0.0, 1.0);

        // Phase 2 (18% -> 52%, 190-550ms): Brand title + subtitle.
        final brandT = const Interval(
          0.18,
          0.52,
          curve: Curves.easeOutCubic,
        ).transform(t);
        final brandOpacity = brandT;
        final brandOffsetY = lerpDouble(10.0, 0.0, brandT)!;
        final brandLetterSpacing = lerpDouble(2.2, -0.5, brandT)!;

        // Phase 3 (72% -> 100%, 756-1050ms): Reveal home.
        final exitT = const Interval(
          0.72,
          1.0,
          curve: Curves.easeOutCubic,
        ).transform(t);
        final splashScale = lerpDouble(1.0, 1.05, exitT)!;
        final splashOpacity = lerpDouble(1.0, 0.0, exitT)!;
        final childScale = lerpDouble(0.97, 1.0, exitT)!;

        final orbitCanvasSize = _logoSize + (_orbitPadding * 2) + 8;

        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: childScale,
              child: child,
            ),
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Opacity(
                  opacity: splashOpacity,
                  child: Transform.scale(
                    scale: splashScale,
                    child: ColoredBox(
                      color: background,
                      child: Material(
                        type: MaterialType.transparency,
                        child: SafeArea(
                          child: Center(
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Opacity(
                                    opacity: logoOpacity,
                                    child: Transform.scale(
                                      scale: logoScale,
                                      child: SizedBox(
                                        width: orbitCanvasSize + 44,
                                        height: orbitCanvasSize + 44,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Soft ambient RadialGradient glow behind logo.
                                            Container(
                                              width: orbitCanvasSize + 44,
                                              height: orbitCanvasSize + 44,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: RadialGradient(
                                                  colors: light
                                                      ? const [
                                                          Color(0x286f4ca8),
                                                          Color(0x108bc5d5),
                                                          Color(0x00f6f7fb),
                                                        ]
                                                      : const [
                                                          Color(0x3dc2abf3),
                                                          Color(0x188bc5d5),
                                                          Color(0x000b0b10),
                                                        ],
                                                  stops: const [0.0, 0.55, 1.0],
                                                ),
                                              ),
                                            ),
                                            // Crisp vector Orbit Glow ring.
                                            CustomPaint(
                                              size: Size.square(
                                                orbitCanvasSize,
                                              ),
                                              painter: _OrbitGlowPainter(
                                                progress: orbitT,
                                                opacity: orbitOpacity,
                                                radius:
                                                    (_logoSize / 2) +
                                                    _orbitPadding,
                                                light: light,
                                              ),
                                            ),
                                            // Crisp unblurred logo badge.
                                            Container(
                                              width: _logoSize,
                                              height: _logoSize,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xff0b0b10),
                                                border: Border.all(
                                                  color: light
                                                      ? const Color(0x2a6f4ca8)
                                                      : const Color(0x38ffffff),
                                                  width: 1,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: light
                                                        ? const Color(
                                                            0x1f6f4ca8,
                                                          )
                                                        : const Color(
                                                            0x42c2abf3,
                                                          ),
                                                    blurRadius: 24,
                                                  ),
                                                ],
                                              ),
                                              child: ClipOval(
                                                child: Image.asset(
                                                  _logoAsset,
                                                  width: _logoSize,
                                                  height: _logoSize,
                                                  fit: BoxFit.cover,
                                                  filterQuality:
                                                      FilterQuality.high,
                                                  isAntiAlias: true,
                                                  gaplessPlayback: true,
                                                  errorBuilder: (_, _, _) =>
                                                      const Center(
                                                        child: EqualizerBars(
                                                          active: false,
                                                          color: Color(
                                                            0xffd6cafa,
                                                          ),
                                                          size: 36,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Opacity(
                                    opacity: brandOpacity,
                                    child: Transform.translate(
                                      offset: Offset(0, brandOffsetY),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text.rich(
                                              TextSpan(
                                                text: 'BCMusic',
                                                style: TextStyle(
                                                  fontFamily: 'BeVietnamPro',
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing:
                                                      brandLetterSpacing,
                                                  color: titleColor,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: '.',
                                                    style: TextStyle(
                                                      color: accentDotColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'ÂM NHẠC CHO RIÊNG BẠN',
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'BeVietnamPro',
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 2.0,
                                              color: subtitleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrbitGlowPainter extends CustomPainter {
  const _OrbitGlowPainter({
    required this.progress,
    required this.opacity,
    required this.radius,
    required this.light,
  });

  final double progress;
  final double opacity;
  final double radius;
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.001) return;

    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Subtle static base ring for visual grounding.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true
      ..color = (light ? const Color(0xff6f4ca8) : const Color(0xffd6cafa))
          .withValues(alpha: 0.12 * opacity);
    canvas.drawCircle(center, radius, trackPaint);

    // Rotate ~330 degrees clockwise around the logo perimeter.
    const totalSweep = (330.0 * math.pi) / 180.0;
    final startAngle = (-math.pi / 2) + (totalSweep * progress);
    const arcSweep = math.pi * 1.35;

    final primary = light
        ? const Color(0xff6f4ca8)
        : const Color(0xffd6cafa);
    final secondary = light
        ? const Color(0xff4c9bb0)
        : const Color(0xff8bc5d5);

    final gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: math.pi * 2,
      colors: [
        Colors.transparent,
        primary.withValues(alpha: 0.95 * opacity),
        secondary.withValues(alpha: 0.90 * opacity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.36, 0.64, 0.72],
      transform: GradientRotation(startAngle),
    );

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..shader = gradient.createShader(rect);

    canvas.drawArc(rect, startAngle + 0.08, arcSweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitGlowPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.opacity != opacity ||
      oldDelegate.radius != radius ||
      oldDelegate.light != light;
}
