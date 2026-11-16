import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm/l10n/app_localizations_en.dart';
import 'package:wfm/platform.dart';
import 'package:wfm/util.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('fmtBytes', () {
    expect(fmtBytes(0), '0 B');
    expect(fmtBytes(1023), '1023 B');
    expect(fmtBytes(2048), '2.0 KB');
    expect(fmtBytes(5 * 1024 * 1024), '5.0 MB');
    expect(fmtBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
    expect(fmtBytes(2 * 1024 * 1024 * 1024 * 1024), '2.0 TB');
    expect(fmtBytes(2 * 1024 * 1024 * 1024 * 1024 * 1024), '2048.0 TB');
  });

  test('fmtTime', () {
    expect(fmtTime(l10n, 0), l10n.never);
    expect(fmtTime(l10n, -5), l10n.never);
    expect(fmtTime(l10n, 86400),
        matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')));
  });

  test('fmtAgo', () {
    expect(fmtAgo(l10n, 0), l10n.never);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    expect(fmtAgo(l10n, now), l10n.justNow);
    expect(fmtAgo(l10n, now - 120), l10n.minutesAgo(2));
    expect(fmtAgo(l10n, now - 3600 * 3), l10n.hoursAgo(3));
    expect(fmtAgo(l10n, now - 86400 * 5), l10n.daysAgo(5));
    expect(fmtAgo(l10n, now - 86400 * 40), isNot(l10n.daysAgo(40)));
  });

  test('extOf/isMedia', () {
    expect(extOf('a.mp4'), 'mp4');
    expect(extOf('A.MP4'), 'mp4');
    expect(extOf('nodot'), '');
    expect(isMedia('x.mp4'), isTrue);
    expect(isMedia('x.wav'), isTrue);
    expect(isMedia('x.png'), isTrue);
    expect(isMedia('x.txt'), isFalse);
    expect(isMedia('nodot'), isFalse);
  });

  test('platform_io hooks and throws', () async {
    expect(() => openExternal('https://x'), throwsUnsupportedError);
    expect(() => pickFiles(), throwsUnsupportedError);
    var opened = '';
    openExternalForTesting = (u) => opened = u;
    openExternal('https://example.com');
    expect(opened, 'https://example.com');
    pickFilesForTesting = () async => [
          PickedFile('a.txt', Uint8List.fromList([1]))
        ];
    final files = await pickFiles();
    expect(files.single.name, 'a.txt');
    expect(files.single.bytes, [1]);
    openExternalForTesting = null;
    pickFilesForTesting = null;
    expect(() => openExternal('x'), throwsUnsupportedError);
  });
}
