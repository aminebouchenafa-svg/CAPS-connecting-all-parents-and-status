extension DateTimeX on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  String get frenchRelative {
    if (isToday) return "Aujourd'hui";
    if (isTomorrow) return 'Demain';
    final diff = difference(DateTime.now());
    if (diff.inDays > 0 && diff.inDays <= 7) return 'Dans ${diff.inDays} jours';
    return '$day/${month.toString().padLeft(2, '0')}/$year';
  }

  Duration get timeUntil => difference(DateTime.now());

  String get countdownDisplay {
    final remaining = timeUntil;
    if (remaining.isNegative) return 'Disponible';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 24) return '${remaining.inDays}j ${hours % 24}h';
    return '${hours}h ${minutes}min';
  }
}
