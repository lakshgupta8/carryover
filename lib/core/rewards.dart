/// Reward rules.
///
/// Two kinds of token:
///  * **Habit tokens** live in a wallet per habit. Every check-in of that
///    habit earns them, and so do that habit's own milestones. They repair
///    that habit's streak only, or can be exchanged into shared tokens.
///  * **Shared tokens** are earned by perfect days, global milestones and
///    exchanges. They repair any habit.
///
/// Repairs always draw from the habit's own wallet first and top up from the
/// shared wallet.
library;

class RewardRules {
  RewardRules._();

  /// Habit tokens for every check-in.
  static const int perCompletion = 2;

  /// Shared tokens for a perfect day (everything required that day done).
  static const int perPerfectDay = 5;

  /// Cost, in tokens, to repair one missed day of one habit.
  static const int repairCostPerDay = 10;

  /// A miss can be repaired for this many days after it happened (for weekly
  /// habits: after the week ended).
  static const int repairWindowDays = 7;

  /// Habit tokens needed to mint one shared token.
  static const int exchangeRate = 2;
}

enum MilestoneKind { daily, weekly, monthly, completions, habit }

class Milestone {
  const Milestone({
    required this.key,
    required this.kind,
    required this.threshold,
    required this.reward,
    required this.title,
  });

  final String key;
  final MilestoneKind kind;
  final int threshold;
  final int reward;
  final String title;

  /// For per-habit milestones, the habit the reward belongs to.
  String? get habitId => habitIdFromKey(key);

  static String? habitIdFromKey(String key) {
    if (!key.startsWith('habit:')) return null;
    final parts = key.split(':');
    return parts.length >= 3 ? parts[1] : null;
  }
}

typedef HabitTier = ({int threshold, int reward, String title});

class Milestones {
  Milestones._();

  static const List<Milestone> daily = [
    Milestone(key: 'daily:3', kind: MilestoneKind.daily, threshold: 3, reward: 10, title: '3-day streak'),
    Milestone(key: 'daily:7', kind: MilestoneKind.daily, threshold: 7, reward: 25, title: 'One golden week'),
    Milestone(key: 'daily:14', kind: MilestoneKind.daily, threshold: 14, reward: 40, title: 'Two weeks strong'),
    Milestone(key: 'daily:21', kind: MilestoneKind.daily, threshold: 21, reward: 60, title: '21 days: habit forged'),
    Milestone(key: 'daily:30', kind: MilestoneKind.daily, threshold: 30, reward: 100, title: '30-day streak'),
    Milestone(key: 'daily:50', kind: MilestoneKind.daily, threshold: 50, reward: 150, title: '50-day streak'),
    Milestone(key: 'daily:100', kind: MilestoneKind.daily, threshold: 100, reward: 300, title: 'Century'),
    Milestone(key: 'daily:200', kind: MilestoneKind.daily, threshold: 200, reward: 500, title: '200-day streak'),
    Milestone(key: 'daily:365', kind: MilestoneKind.daily, threshold: 365, reward: 1000, title: 'A full year'),
  ];

  static const List<Milestone> weekly = [
    Milestone(key: 'weekly:2', kind: MilestoneKind.weekly, threshold: 2, reward: 30, title: '2 perfect weeks'),
    Milestone(key: 'weekly:4', kind: MilestoneKind.weekly, threshold: 4, reward: 50, title: '4 perfect weeks'),
    Milestone(key: 'weekly:8', kind: MilestoneKind.weekly, threshold: 8, reward: 100, title: '8 perfect weeks'),
    Milestone(key: 'weekly:12', kind: MilestoneKind.weekly, threshold: 12, reward: 150, title: 'A perfect quarter'),
    Milestone(key: 'weekly:26', kind: MilestoneKind.weekly, threshold: 26, reward: 300, title: 'Half a year of weeks'),
    Milestone(key: 'weekly:52', kind: MilestoneKind.weekly, threshold: 52, reward: 750, title: '52 perfect weeks'),
  ];

  static const List<Milestone> monthly = [
    Milestone(key: 'monthly:1', kind: MilestoneKind.monthly, threshold: 1, reward: 75, title: 'First perfect month'),
    Milestone(key: 'monthly:3', kind: MilestoneKind.monthly, threshold: 3, reward: 200, title: '3 perfect months'),
    Milestone(key: 'monthly:6', kind: MilestoneKind.monthly, threshold: 6, reward: 400, title: '6 perfect months'),
    Milestone(key: 'monthly:12', kind: MilestoneKind.monthly, threshold: 12, reward: 1000, title: 'A perfect year'),
  ];

  static const List<Milestone> completions = [
    Milestone(key: 'done:10', kind: MilestoneKind.completions, threshold: 10, reward: 10, title: '10 check-ins'),
    Milestone(key: 'done:50', kind: MilestoneKind.completions, threshold: 50, reward: 30, title: '50 check-ins'),
    Milestone(key: 'done:100', kind: MilestoneKind.completions, threshold: 100, reward: 50, title: '100 check-ins'),
    Milestone(key: 'done:250', kind: MilestoneKind.completions, threshold: 250, reward: 100, title: '250 check-ins'),
    Milestone(key: 'done:500', kind: MilestoneKind.completions, threshold: 500, reward: 200, title: '500 check-ins'),
    Milestone(key: 'done:1000', kind: MilestoneKind.completions, threshold: 1000, reward: 500, title: '1,000 check-ins'),
  ];

  /// Per-habit streak tiers, paid into that habit's wallet.
  /// Keys are `habit:<habitId>:<threshold>`.
  static const List<HabitTier> habitTiers = [
    (threshold: 7, reward: 10, title: '7-day streak'),
    (threshold: 30, reward: 40, title: '30-day streak'),
    (threshold: 100, reward: 150, title: '100-day streak'),
  ];

  static List<Milestone> get global => [
        ...daily,
        ...weekly,
        ...monthly,
        ...completions,
      ];

  static Milestone habitMilestone(String habitId, String habitName, HabitTier tier) {
    return Milestone(
      key: 'habit:$habitId:${tier.threshold}',
      kind: MilestoneKind.habit,
      threshold: tier.threshold,
      reward: tier.reward,
      title: '$habitName · ${tier.title}',
    );
  }
}
