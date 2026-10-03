/// Date helpers. The app works in *local* calendar days and stores dates as
/// `yyyy-MM-dd` keys, which sort correctly as plain strings.
library;

String two(int n) => n.toString().padLeft(2, '0');

/// `yyyy-MM-dd` for the local calendar day of [d].
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

DateTime parseDateKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The calendar day that [now] belongs to when days roll over at
/// [dayStartMinutes] past midnight instead of at midnight. With a 3 AM
/// boundary, 00:30 on the 5th still counts as the 4th.
DateTime logicalDay(DateTime now, int dayStartMinutes) =>
    dateOnly(now.subtract(Duration(minutes: dayStartMinutes)));

/// Minutes elapsed since the current logical day began.
int minutesIntoLogicalDay(DateTime now, int dayStartMinutes) {
  final shifted = now.subtract(Duration(minutes: dayStartMinutes));
  return shifted.hour * 60 + shifted.minute;
}

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// Monday of the week that contains [d].
DateTime startOfWeek(DateTime d) =>
    addDays(dateOnly(d), -(d.weekday - DateTime.monday));

DateTime endOfWeek(DateTime d) => addDays(startOfWeek(d), 6);

String weekKey(DateTime d) => dateKey(startOfWeek(d));

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

DateTime endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${two(d.month)}';

/// Formats minutes-since-midnight as `h:mm AM/PM`.
String formatMinutes(int minutes) {
  final h24 = minutes ~/ 60;
  final m = minutes % 60;
  final suffix = h24 >= 12 ? 'PM' : 'AM';
  var h = h24 % 12;
  if (h == 0) h = 12;
  return '$h:${two(m)} $suffix';
}

const List<String> weekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
const List<String> weekdayLetter = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
