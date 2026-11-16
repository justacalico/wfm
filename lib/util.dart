import 'l10n/app_localizations.dart';

String fmtBytes(int n) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = n.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

String fmtTime(AppLocalizations l10n, int ts) {
  if (ts <= 0) return l10n.never;
  final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

String fmtAgo(AppLocalizations l10n, int ts) {
  if (ts <= 0) return l10n.never;
  final d =
      DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts * 1000));
  if (d.inMinutes < 1) return l10n.justNow;
  if (d.inHours < 1) return l10n.minutesAgo(d.inMinutes);
  if (d.inDays < 1) return l10n.hoursAgo(d.inHours);
  if (d.inDays < 30) return l10n.daysAgo(d.inDays);
  return fmtTime(l10n, ts);
}

String extOf(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 ? '' : name.substring(i + 1).toLowerCase();
}

bool isMedia(String name) => const {
      'mp4',
      'mov',
      'mkv',
      'webm',
      'avi',
      'm4v',
      'mpg',
      'mpeg',
      'mp3',
      'wav',
      'aac',
      'flac',
      'ogg',
      'm4a',
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'bmp',
      'tif',
      'tiff',
    }.contains(extOf(name));
