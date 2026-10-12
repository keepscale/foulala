/// Mise en forme en français, sans dépendance (pas besoin d'intl pour si peu).
library;

const _days = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// 8412 → « 8 412 » (espace fine insécable, comme en typographie française).
String formatCount(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// 3 → « 3 soutiens », 1 → « 1 soutien ».
String plural(int n, String singular, [String? pluralForm]) =>
    '${formatCount(n)} ${n > 1 ? (pluralForm ?? '${singular}s') : singular}';

/// « 14:00 », heure locale du téléphone.
String formatTime(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// « Aujourd'hui », « Demain », « Hier » ou « Mar. 20 oct. ».
String formatDay(DateTime t, {required DateTime now}) {
  final l = t.toLocal();
  // En UTC : au changement d'heure, deux minuits locaux peuvent être à 23 h d'écart.
  final day = DateTime.utc(l.year, l.month, l.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  switch (day.difference(today).inDays) {
    case 0:
      return "Aujourd'hui";
    case 1:
      return 'Demain';
    case -1:
      return 'Hier';
  }
  return '${_days[l.weekday - 1]} ${l.day} ${_months[l.month - 1]}';
}
