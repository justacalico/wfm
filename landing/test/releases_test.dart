import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wfm_landing/releases.dart';

void main() {
  test('release url links to the release page, not the API', () async {
    final fetcher = ReleaseFetcher(MockClient((_) async => http.Response(
        '[{"tag_name":"v1.0.0","name":"WFM 1.0","_links":{"self":"https://gitlab.com/api/v4/projects/HttpAnimations%2Fwfm/releases/v1.0.0"},"assets":{"links":[{"name":"wfm-linux.tar.gz","direct_asset_url":"https://gitlab.com/x/dl"}]}}]',
        200)));
    final releases = await fetcher.fetch();
    expect(releases.single.tag, 'v1.0.0');
    expect(releases.single.name, 'WFM 1.0');
    expect(releases.single.url,
        'https://gitlab.com/HttpAnimations/wfm/-/releases/v1.0.0');
    expect(releases.single.assets.single.name, 'wfm-linux.tar.gz');
    expect(releases.single.assets.single.url, 'https://gitlab.com/x/dl');
  });

  test('missing fields fall back to defaults', () async {
    final fetcher = ReleaseFetcher(MockClient((_) async => http.Response(
        '[{"assets":{"links":[{"url":"https://gitlab.com/x/a"}]}}]', 200)));
    final releases = await fetcher.fetch();
    expect(releases.single.tag, '');
    expect(releases.single.url, ReleaseFetcher.pageUrl);
    expect(releases.single.assets.single.name, '');
    expect(releases.single.assets.single.url, 'https://gitlab.com/x/a');
  });

  test('non-200 response throws', () async {
    final fetcher =
        ReleaseFetcher(MockClient((_) async => http.Response('nope', 500)));
    expect(fetcher.fetch, throwsException);
  });
}
