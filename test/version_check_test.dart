import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wfm/version_check.dart';

MockClient releasesClient(String json, [int status = 200]) =>
    MockClient((_) async => http.Response(json, status));

void main() {
  group('Version', () {
    test('parse', () {
      expect(Version.tryParse('1.2.3').toString(), '1.2.3');
      expect('${Version.tryParse('v2.0')}', '2.0.0');
      expect('${Version.tryParse('V2.0.1')}', '2.0.1');
      expect('${Version.tryParse('1.2.3-beta+5')}', '1.2.3');
      expect(Version.tryParse('nope'), isNull);
      expect(Version.tryParse('1'), isNull);
      expect(Version.tryParse('1.2.3.4'), isNull);
      expect(Version.tryParse('1.x.3'), isNull);
      expect('${Version.tryParse(' 1.5 ')}', '1.5.0');
    });

    test('compare', () {
      expect(
          const Version(1, 0, 0).compareTo(const Version(2, 0, 0)), isNegative);
      expect(
          const Version(1, 2, 0).compareTo(const Version(1, 3, 0)), isNegative);
      expect(
          const Version(1, 2, 3).compareTo(const Version(1, 2, 4)), isNegative);
      expect(const Version(1, 2, 3).compareTo(const Version(1, 2, 3)), 0);
      expect('${const Version(9, 8, 7)}', '9.8.7');
    });
  });

  group('UpdateChecker', () {
    test('newer release available', () async {
      final c = releasesClient(
          '[{"tag_name":"v1.0.0"},{"tag_name":"v1.4.0"},{"tag_name":"nightly"}]');
      final u = await UpdateChecker(c,
              apiUrl: 'https://x/releases', pageUrl: 'https://x/p')
          .check('1.0.0');
      expect(u, isNotNull);
      expect(u!.version, '1.4.0');
      expect(u.tag, 'v1.4.0');
      expect(u.url, 'https://x/p/v1.4.0');
    });

    test('no update when current is latest', () async {
      final c = releasesClient('[{"tag_name":"v1.0.0"}]');
      expect(
          await UpdateChecker(c, apiUrl: 'https://x').check('1.0.0'), isNull);
    });

    test('unparseable current still reports latest', () async {
      final c = releasesClient('[{"tag_name":"v2.0.0"}]');
      expect((await UpdateChecker(c, apiUrl: 'https://x').check(''))?.version,
          '2.0.0');
    });

    test('empty releases', () async {
      final c = MockClient((_) async => http.Response('[]', 200));
      expect(await UpdateChecker(c, apiUrl: 'https://x').check('1.0'), isNull);
      final c2 = releasesClient('[{"name":"no tag"}]');
      expect(await UpdateChecker(c2, apiUrl: 'https://x').check('1.0'), isNull);
    });

    test('http error throws', () {
      final c = releasesClient('boom', 500);
      expect(
          UpdateChecker(c, apiUrl: 'https://x').check('1.0'), throwsException);
    });

    test('default urls are the wfm project', () {
      expect(UpdateChecker.projectPath, 'HttpAnimations/wfm');
      expect(UpdateChecker.defaultApi, contains('gitlab.com'));
      expect(UpdateChecker.releasesPage, contains('gitlab.com'));
    });
  });
}
