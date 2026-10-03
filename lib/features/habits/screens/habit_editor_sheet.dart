import 'package:flutter/material.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_theme.dart';
import '../data/habit_controller.dart';
import '../models/habit.dart';
import '../widgets/gold_widgets.dart';

const List<String> kEmojiChoices = [
  '💧', '🏃', '📖', '🧘', '💪', '🥗', '😴', '✍️',
  '🎯', '🧹', '💊', '🚶', '🎸', '💰', '🧠', '🌿',
  '☀️', '🙏', '🚭', '📵', '🎨', '🪥', '🍎', '✨',
];

/// Bottom sheet for creating or editing a habit.
class HabitEditorSheet extends StatefulWidget {
  const HabitEditorSheet({super.key, this.habit});

  final Habit? habit;

  static Future<void> show(BuildContext context, {Habit? habit}) {
    final controller = ControllerScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ControllerScope(
        controller: controller,
        child: HabitEditorSheet(habit: habit),
      ),
    );
  }

  @override
  State<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends State<HabitEditorSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.habit?.name ?? '');
  late String _emoji = widget.habit?.emoji ?? kEmojiChoices.first;
  late ScheduleType _type = widget.habit?.scheduleType ?? ScheduleType.weekdays;
  late Set<int> _days = {...(widget.habit?.weekdays ?? {1, 2, 3, 4, 5, 6, 7})};
  late int _timesPerWeek = widget.habit?.timesPerWeek ?? 3;
  late int? _reminder = widget.habit?.reminderMinutes;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.habit != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _customEmoji() async {
    final controller = TextEditingController();
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Any emoji'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 8,
          decoration: const InputDecoration(hintText: 'Type or paste an emoji'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Use'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = picked?.trim() ?? '';
    if (trimmed.isEmpty) return;
    // Keep just the first grapheme so flags and skin tones stay intact.
    setState(() => _emoji = trimmed.characters.first);
  }

  Future<void> _pickTime() async {
    final initial = _reminder ?? 8 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    if (picked != null) {
      setState(() => _reminder = picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the habit a name.');
      return;
    }
    if (_type == ScheduleType.weekdays && _days.isEmpty) {
      setState(() => _error = 'Pick at least one day.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final c = ControllerScope.of(context);
    final days = _type == ScheduleType.weekdays ? _days : {1, 2, 3, 4, 5, 6, 7};
    try {
      if (_isEdit) {
        await c.updateHabit(widget.habit!.copyWith(
          name: name,
          emoji: _emoji,
          scheduleType: _type,
          weekdays: days,
          timesPerWeek: _timesPerWeek,
          reminderMinutes: _reminder,
          clearReminder: _reminder == null,
        ));
      } else {
        await c.createHabit(
          name: name,
          emoji: _emoji,
          scheduleType: _type,
          weekdays: days,
          timesPerWeek: _timesPerWeek,
          reminderMinutes: _reminder,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save: $e';
        });
      }
    }
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive habit?'),
        content: const Text(
          'It stops being scheduled from today. Your history, tokens and '
          'milestones stay. You can restore it any time from the Habits tab.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ControllerScope.of(context).archiveHabit(widget.habit!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final weekly = _type == ScheduleType.weekly;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Edit habit' : 'New habit', style: t.headlineSmall),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.goldPale,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: !_isEdit,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Read 10 pages',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in {
                  if (!kEmojiChoices.contains(_emoji)) _emoji,
                  ...kEmojiChoices,
                })
                  GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: e == _emoji ? AppColors.goldPale : AppColors.champagne,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: e == _emoji ? AppColors.gold : Colors.transparent,
                          width: 1.6,
                        ),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                GestureDetector(
                  onTap: _customEmoji,
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line, width: 1.6),
                    ),
                    child: const Icon(Icons.keyboard_alt_outlined,
                        size: 20, color: AppColors.inkMuted),
                  ),
                ),
              ],
            ),
            const SectionTitle('Repeat'),
            Row(
              children: [
                _QuickChip(
                  label: 'Specific days',
                  selected: !weekly,
                  onTap: () => setState(() => _type = ScheduleType.weekdays),
                ),
                const SizedBox(width: 8),
                _QuickChip(
                  label: 'Days a week',
                  selected: weekly,
                  onTap: () => setState(() => _type = ScheduleType.weekly),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (weekly) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var n = 1; n <= 6; n++)
                    _DayDot(
                      label: '$n',
                      selected: _timesPerWeek == n,
                      onTap: () => setState(() => _timesPerWeek = n),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '$_timesPerWeek day${_timesPerWeek == 1 ? '' : 's'} a week, any days you '
                'like. The streak only breaks after more than ${7 - _timesPerWeek} '
                'skipped day${7 - _timesPerWeek == 1 ? '' : 's'} in a week, and a '
                'broken week can be repaired for the extra days missed.',
                style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            ] else ...[
              Row(
                children: [
                  _QuickChip(
                    label: 'Every day',
                    selected: _days.length == 7,
                    onTap: () => setState(() => _days = {1, 2, 3, 4, 5, 6, 7}),
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: 'Weekdays',
                    selected: _days.length == 5 && !_days.contains(6) && !_days.contains(7),
                    onTap: () => setState(() => _days = {1, 2, 3, 4, 5}),
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: 'Weekends',
                    selected: _days.length == 2 && _days.contains(6) && _days.contains(7),
                    onTap: () => setState(() => _days = {6, 7}),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var d = 1; d <= 7; d++)
                    _DayDot(
                      label: weekdayLetter[d - 1],
                      selected: _days.contains(d),
                      onTap: () => setState(() {
                        if (_days.contains(d)) {
                          _days = {..._days}..remove(d);
                        } else {
                          _days = {..._days, d};
                        }
                      }),
                    ),
                ],
              ),
            ],
            const SectionTitle('Reminder'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Notify me'),
                    subtitle: Text(
                      _reminder == null
                          ? 'No reminder for this habit'
                          : weekly
                              ? 'Daily at ${formatMinutes(_reminder!)} until the week\'s target is met'
                              : 'On scheduled days at ${formatMinutes(_reminder!)}',
                    ),
                    value: _reminder != null,
                    onChanged: (on) {
                      if (on) {
                        _pickTime();
                      } else {
                        setState(() => _reminder = null);
                      }
                    },
                  ),
                  if (_reminder != null) ...[
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(formatMinutes(_reminder!)),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.inkFaint),
                      onTap: _pickTime,
                    ),
                  ],
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: t.bodySmall?.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 22),
            GoldButton(
              label: _isEdit ? 'Save changes' : 'Create habit',
              loading: _saving,
              onPressed: _save,
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving ? null : _archive,
                style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Archive habit'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ChoiceChip(
        label: SizedBox(
          width: double.infinity,
          child: Text(label, textAlign: TextAlign.center),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selected ? AppColors.goldGradient : null,
          color: selected ? null : AppColors.white,
          border: selected ? null : Border.all(color: AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.white : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}
