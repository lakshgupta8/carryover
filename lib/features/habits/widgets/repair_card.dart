import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_theme.dart';
import '../engine/streak_engine.dart';
import '../models/day_record.dart';
import 'gold_widgets.dart';

/// Repairs for one missed day (weekday habits), one row per habit.
class DayRepairCard extends StatelessWidget {
  const DayRepairCard({
    super.key,
    required this.dateKey,
    required this.options,
    required this.sharedBalance,
    required this.onRepair,
    required this.onRepairAll,
  });

  final String dateKey;
  final List<RepairOption> options;
  final int sharedBalance;
  final Future<void> Function(RepairOption option) onRepair;
  final Future<void> Function() onRepairAll;

  @override
  Widget build(BuildContext context) {
    final date = parseDateKey(dateKey);
    final total = options.fold<Payment>(
        const Payment(), (p, o) => p + o.payment);
    final allAffordable = total.external <= sharedBalance;

    return SoftCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.gold.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            icon: Icons.history_rounded,
            title: 'Missed ${DateFormat('EEEE, d MMM').format(date)}',
            subtitle: options.length == 1
                ? 'Buy the day back and the streak carries on.'
                : '${options.length} habits missed. Repair one or all.',
          ),
          const SizedBox(height: 10),
          for (final o in options) _RepairRow(option: o, onRepair: onRepair),
          if (options.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GoldButton(
                    height: 44,
                    icon: Icons.auto_fix_high_rounded,
                    label: 'Repair all · ${total.total}',
                    onPressed: allAffordable ? () => onRepairAll() : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _PaymentNote(payment: total, affordable: allAffordable, sharedBalance: sharedBalance)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Repair of a weekly habit's week: buys back the extra skipped days.
class WeekRepairCard extends StatelessWidget {
  const WeekRepairCard({
    super.key,
    required this.option,
    required this.sharedBalance,
    required this.onRepair,
  });

  final RepairOption option;
  final int sharedBalance;
  final Future<void> Function(RepairOption option) onRepair;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final h = option.habit;
    final weekLabel = DateFormat('d MMM').format(option.date);
    return SoftCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.gold.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            icon: Icons.event_repeat_rounded,
            title: '${h.emoji} ${h.name} · week of $weekLabel',
            subtitle:
                'Skipped ${option.units} day${option.units == 1 ? '' : 's'} more '
                'than the ${h.allowedSkipsPerWeek} allowed. Repair to keep the '
                'streak at ${option.habitStreakAfter}.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GoldButton(
                  height: 44,
                  icon: Icons.build_circle_outlined,
                  label: 'Repair · ${option.cost}',
                  onPressed: option.affordable ? () => onRepair(option) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PaymentNote(
                  payment: option.payment,
                  affordable: option.affordable,
                  sharedBalance: sharedBalance,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Daily streak afterwards: ${option.dailyStreakAfter}',
            style: t.labelSmall?.copyWith(color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _RepairRow extends StatelessWidget {
  const _RepairRow({required this.option, required this.onRepair});

  final RepairOption option;
  final Future<void> Function(RepairOption option) onRepair;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final h = option.habit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(h.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name,
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${_paySummary(option.payment)} · streak → ${option.habitStreakAfter}',
                  style: t.labelSmall?.copyWith(
                    color: option.affordable ? AppColors.inkMuted : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 124,
            child: GoldButton(
              height: 38,
              label: 'Repair · ${option.cost}',
              onPressed: option.affordable ? () => onRepair(option) : null,
            ),
          ),
        ],
      ),
    );
  }
}

String _paySummary(Payment p) {
  final parts = <String>[];
  if (p.internal > 0) parts.add('${p.internal} habit');
  if (p.external > 0) parts.add('${p.external} shared');
  return parts.isEmpty ? 'free' : 'pays ${parts.join(' + ')}';
}

class _PaymentNote extends StatelessWidget {
  const _PaymentNote({
    required this.payment,
    required this.affordable,
    required this.sharedBalance,
  });

  final Payment payment;
  final bool affordable;
  final int sharedBalance;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Text(
      affordable
          ? _paySummary(payment)
          : 'Need ${payment.external - sharedBalance} more shared tokens',
      style: t.labelMedium?.copyWith(
        color: affordable ? AppColors.inkMuted : AppColors.error,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.goldPale,
          ),
          child: Icon(icon, color: AppColors.goldDark, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: t.bodySmall?.copyWith(color: AppColors.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
