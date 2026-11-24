import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Antigüedad relativa como en el mockup: "hace 15 min", "hace 3 h", "ayer", "hace 2 días".
String timeAgo(AppLocalizations l, DateTime date, {DateTime? now}) {
  final ref = (now ?? DateTime.now()).toLocal();
  final local = date.toLocal();
  final diff = ref.difference(local);
  if (diff.inMinutes < 1) return l.timeNow;
  if (diff.inMinutes < 60) return l.timeMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l.timeHours(diff.inHours);
  // Días naturales en hora local (antes se usaban los componentes UTC de `date`, y cerca de
  // medianoche una publicación de ayer podía salir como «hace 2 días» o al revés).
  final days = DateTime(
    ref.year,
    ref.month,
    ref.day,
  ).difference(DateTime(local.year, local.month, local.day)).inDays;
  if (days <= 1) return l.timeYesterday;
  if (days < 7) return l.timeDays(days);
  return DateFormat('d MMM y', 'es').format(local);
}

/// "23 oct 2026"
String shortDate(DateTime d) => DateFormat('d MMM y', 'es').format(d.toLocal()).replaceAll('.', '');

/// "jue., 19 nov · 19:00"
String eventDate(DateTime d) => DateFormat('EEE d MMM · HH:mm', 'es').format(d.toLocal());
