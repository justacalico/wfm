import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/l10n/app_localizations_en.dart';
import 'package:wfm/platform.dart';
import 'package:wfm/util.dart';
import 'helpers.dart';

void main() {
  setUp(
      () => SharedPreferences.setMockInitialValues({'server': 'http://test'}));
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
    expect(fmtAgo(l10n, now - 86400 * 40), l10n.weeksAgo(5));
    expect(fmtAgo(l10n, now - 86400 * 100), l10n.monthsAgo(3));
    expect(fmtAgo(l10n, now - 86400 * 800), l10n.yearsAgo(2));
  });

  test('extOf', () {
    expect(extOf('a.mp4'), 'mp4');
    expect(extOf('A.MP4'), 'mp4');
    expect(extOf('nodot'), '');
  });

  test('platform_io hooks', () async {
    var opened = '';
    openExternalForTesting = (u) => opened = u;
    await openExternal('https://example.com');
    expect(opened, 'https://example.com');
    pickFilesForTesting = () async => [
          PickedFile('a.txt', Uint8List.fromList([1]))
        ];
    final files = await pickFiles();
    expect(files.single.name, 'a.txt');
    expect(files.single.bytes, [1]);
    openExternalForTesting = null;
    pickFilesForTesting = null;
  });

  test('openExternal handoffs api urls', () async {
    final api = Api(FakeClient({
      'POST /api/handoff': (_) => {'t': 'tk'},
    }));
    Api.i = api;
    try {
      await openExternal('/api/projects/p1/zip?paths=Raw');
    } catch (_) {}
    expect(lastRequest!.url.path, '/api/handoff');
    try {
      await openExternal('https://example.com');
    } catch (_) {}
    expect(lastRequest!.url.path, '/api/handoff');
  });

  testWidgets('openEditor launches the handoff url', (t) async {
    final api = Api(FakeClient({
      'POST /api/handoff': (_) => {'t': 'tk'},
    }));
    Api.i = api;
    late BuildContext ctx;
    await t.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    try {
      await openEditor(ctx, api, '/filmcraft/wfm.html?project=p1');
    } catch (_) {}
    expect(lastRequest!.url.path, '/api/handoff');
    await t.pumpWidget(const SizedBox());
  });

  test('uploadPicked and avatar, bytes and disk', () async {
    final uploads = <List<int>>[];
    var avatarBytes = 0;
    final api = Api(FakeClient({
      'PUT /api/projects/p1/files': (req) {
        uploads.add(req.bodyBytes);
        return {'ok': true};
      },
      'POST /api/projects/p1/files/upload': (_) => {'id': 'u1'},
      'PUT /api/uploads/u1/chunk': (req) {
        uploads.add(req.bodyBytes);
        return {'received': 0};
      },
      'POST /api/uploads/u1/complete': (_) => {'ok': true},
      'PUT /api/me/avatar': (req) {
        avatarBytes = req.bodyBytes.length;
        return {'ok': true};
      },
    }));
    final prog = <List<int>>[];
    await uploadPicked(
        api,
        'p1',
        'a.bin',
        PickedFile('a.bin', Uint8List.fromList([1, 2])),
        (s, t) => prog.add([s, t]));
    expect(uploads.single, [1, 2]);
    expect(prog.last, [2, 2]);

    final dir = await Directory.systemTemp.createTemp();
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}/b.bin');
    await f.writeAsBytes([9, 8, 7, 6, 5, 4, 3, 2, 1]);
    api.chunkSize = 4;
    await uploadPicked(api, 'p1', 'b.bin',
        PickedFile('b.bin', Uint8List(0), path: f.path, size: 9));
    expect(uploads.sublist(1), [
      [9, 8, 7, 6],
      [5, 4, 3, 2],
      [1]
    ]);

    await uploadAvatarPicked(api, PickedFile('a.png', Uint8List.fromList([1])));
    expect(avatarBytes, 1);
    await uploadAvatarPicked(
        api, PickedFile('b.bin', Uint8List(0), path: f.path));
    expect(avatarBytes, 9);

    installDropHandler((_) {});
  });
}
