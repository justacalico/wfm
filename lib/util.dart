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
  if (d.inDays < 63) return l10n.weeksAgo(d.inDays ~/ 7);
  if (d.inDays < 365) return l10n.monthsAgo(d.inDays ~/ 30);
  return l10n.yearsAgo(d.inDays ~/ 365);
}

bool validUsername(String s) =>
    s.length >= 2 &&
    s.length <= 32 &&
    !s.contains('..') &&
    RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(s);

bool validPassword(String s) => s.length >= 8 && s.length <= 256;

bool validDisplayName(String s) => s.trim().isNotEmpty && s.trim().length <= 64;

const _thumbExts = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'tif',
  'tiff',
  'mp4',
  'mov',
  'mkv',
  'webm',
  'avi',
  'm4v',
  'mts',
  'm2ts',
  'mxf',
};

bool thumbable(String name) => _thumbExts.contains(extOf(name));

/// Extensions the project upload endpoints accept: video, audio, images,
/// subtitles/interchange, the managed doc formats and fonts.
const uploadExts = {
  'mp4',
  'mov',
  'mkv',
  'webm',
  'avi',
  'm4v',
  'mts',
  'm2ts',
  'mxf',
  'mpg',
  'mpeg',
  'ts',
  'vob',
  'wmv',
  '3gp',
  'wav',
  'mp3',
  'm4a',
  'aac',
  'flac',
  'ogg',
  'oga',
  'opus',
  'aif',
  'aiff',
  'wma',
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'tif',
  'tiff',
  'dng',
  'exr',
  'hdr',
  'srt',
  'vtt',
  'ass',
  'edl',
  'ale',
  'otio',
  'xml',
  'fcpxml',
  'fcproj',
  'fountain',
  'fdx',
  'deckcraft',
  'json',
  'txt',
  'md',
  'pdf',
  'pptx',
  'potx',
  'ppsx',
  'mogrt',
  'ttf',
  'otf',
  'woff',
  'woff2',
};

bool uploadable(String name) => uploadExts.contains(extOf(name));

bool playableMedia(String name) => switch (extOf(name)) {
      'mp4' ||
      'mov' ||
      'webm' ||
      'm4v' ||
      'mp3' ||
      'wav' ||
      'aac' ||
      'ogg' ||
      'oga' ||
      'm4a' ||
      'opus' ||
      'flac' =>
        true,
      _ => false,
    };

bool audioMedia(String name) => switch (extOf(name)) {
      'mp3' ||
      'wav' ||
      'aac' ||
      'ogg' ||
      'oga' ||
      'm4a' ||
      'opus' ||
      'flac' =>
        true,
      _ => false,
    };

String extOf(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 ? '' : name.substring(i + 1).toLowerCase();
}
