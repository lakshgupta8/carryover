import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/rewards.dart';
import '../../../core/theme/app_theme.dart';
import 'gold_widgets.dart';

/// Shown when one or more milestones are reached.
class CelebrationDialog extends StatefulWidget {
  const CelebrationDialog({super.key, required this.milestones});

  final List<Milestone> milestones;

  static Future<void> show(BuildContext context, List<Milestone> milestones) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.55),
      builder: (_) => CelebrationDialog(milestones: milestones),
    );
  }

  @override
  State<CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<CelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = widget.milestones.fold<int>(0, (s, m) => s + m.reward);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, _) => CustomPaint(
                  painter: _SparklePainter(_controller.value),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0, 0.5, curve: Curves.elasticOut),
                  ),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.goldGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        size: 44, color: AppColors.white),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.milestones.length == 1
                      ? 'Milestone reached'
                      : '${widget.milestones.length} milestones reached',
                  style: t.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                ...widget.milestones.map(
                  (m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.goldDeep, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(m.title,
                              style: t.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        TokenAmount(m.reward),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.champagne,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Bonus tokens',
                          style: t.labelLarge
                              ?.copyWith(color: AppColors.inkMuted)),
                      const SizedBox(width: 12),
                      TokenAmount(total, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GoldButton(
                  label: 'Lovely',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.progress);

  final double progress;
  static final _random = math.Random(7);
  static final List<_Particle> _particles = List.generate(
    36,
    (_) => _Particle(
      angle: _random.nextDouble() * math.pi * 2,
      distance: 60 + _random.nextDouble() * 120,
      size: 2 + _random.nextDouble() * 4,
      delay: _random.nextDouble() * 0.3,
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, 70);
    for (final p in _particles) {
      final local = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local == 0) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final pos = origin +
          Offset(math.cos(p.angle), math.sin(p.angle)) * p.distance * eased +
          Offset(0, 40 * local * local);
      final paint = Paint()
        ..color = Color.lerp(AppColors.goldBright, AppColors.goldDeep, local)!
            .withValues(alpha: (1 - local).clamp(0.0, 1.0));
      canvas.drawCircle(pos, p.size * (1 - local * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.progress != progress;
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
  });

  final double angle;
  final double distance;
  final double size;
  final double delay;
}
