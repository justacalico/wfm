import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wfm/api.dart';
import 'package:wfm/version_check.dart';
import 'helpers.dart';

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
    Api api(Map<String, dynamic> body) =>
        Api(FakeClient({'GET /api/update-check': (_) => body}));

    test('newer release available', () async {
      final u = await UpdateChecker(api(
              {'latest': '1.4.0', 'tag': 'v1.4.0', 'url': 'https://x/v1.4.0'}))
          .check();
      expect(u, isNotNull);
      expect(u!.version, '1.4.0');
      expect(u.tag, 'v1.4.0');
      expect(u.url, 'https://x/v1.4.0');
    });

    test('up to date reports null', () async {
      expect(await UpdateChecker(api({'upToDate': true})).check(), isNull);
    });

    test('missing latest reports null', () async {
      expect(await UpdateChecker(api({})).check(), isNull);
    });

    test('http error throws', () {
      final a = Api(FakeClient({
        'GET /api/update-check': (_) => http.Response('{"error":"boom"}', 502)
      }));
      expect(UpdateChecker(a).check(), throwsA(isA<ApiException>()));
    });
  });
}
