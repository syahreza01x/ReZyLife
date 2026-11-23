import 'package:intl/intl.dart';

final NumberFormat _idNumber = NumberFormat('#,##0', 'id_ID');

const List<String> _monthsFull = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const List<String> _monthsShort = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MEI',
  'JUN',
  'JUL',
  'AGU',
  'SEP',
  'OKT',
  'NOV',
  'DES',
];

const List<String> _weekdaysShort = [
  'SEN',
  'SEL',
  'RAB',
  'KAM',
  'JUM',
  'SAB',
  'MIN',
];

const List<String> _weekdaysTitle = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

String formatRupiah(
  int amount, {
  bool withSign = false,
  bool compact = false,
}) {
  final isNegative = amount < 0;
  final abs = amount.abs();
  final sign = isNegative
      ? '-'
      : (withSign && amount > 0 ? '+' : '');

  if (compact) {
    if (abs >= 1000000000) {
      final v = (abs / 1000000000).toStringAsFixed(1).replaceAll('.0', '');
      return '${sign}Rp${v.replaceAll('.', ',')} M';
    }
    if (abs >= 1000000) {
      final v = (abs / 1000000).toStringAsFixed(1).replaceAll('.0', '');
      return '${sign}Rp${v.replaceAll('.', ',')} jt';
    }
    if (abs >= 100000) {
      final v = (abs / 1000).round();
      return '${sign}Rp$v rb';
    }
  }

  return '${sign}Rp${_idNumber.format(abs)}';
}

String formatDigitsGrouped(String digits) {
  if (digits.isEmpty) return '0';
  final parsed = int.tryParse(digits) ?? 0;
  return _idNumber.format(parsed);
}

class PersonaCalendarInfo {
  const PersonaCalendarInfo({
    required this.dayNumber,
    required this.monthShort,
    required this.weekdayShort,
    required this.weekdayFull,
    required this.phaseLabel,
  });

  final String dayNumber;
  final String monthShort;
  final String weekdayShort;
  final String weekdayFull;
  final String phaseLabel;
}

PersonaCalendarInfo personaCalendarFrom(DateTime dateTime) {
  final hour = dateTime.hour;
  final String phase;
  if (hour >= 5 && hour < 11) {
    phase = 'Pagi';
  } else if (hour >= 11 && hour < 15) {
    phase = 'Siang';
  } else if (hour >= 15 && hour < 19) {
    phase = 'Sore';
  } else {
    phase = 'Malam';
  }

  return PersonaCalendarInfo(
    dayNumber: dateTime.day.toString().padLeft(2, '0'),
    monthShort: _monthsShort[dateTime.month - 1],
    weekdayShort: _weekdaysShort[dateTime.weekday - 1],
    weekdayFull: _weekdaysTitle[dateTime.weekday - 1],
    phaseLabel: phase,
  );
}

String formatMonthYear(DateTime date) =>
    '${_monthsFull[date.month - 1]} ${date.year}';

String formatTimeHm(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String formatDaySectionHeader(DateTime date, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final target = DateTime(date.year, date.month, date.day);
  final diffDays = today.difference(target).inDays;

  if (diffDays == 0) {
    return 'Hari Ini · ${date.day} ${_monthsShort[date.month - 1]}';
  }
  if (diffDays == 1) {
    return 'Kemarin · ${date.day} ${_monthsShort[date.month - 1]}';
  }
  final dayName = _weekdaysTitle[date.weekday - 1];
  final monthName = _monthsFull[date.month - 1];
  return '$dayName, ${date.day} $monthName';
}

String formatShortDate(DateTime date) =>
    '${date.day} ${_monthsShort[date.month - 1]} ${date.year}';
