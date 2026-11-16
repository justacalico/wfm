import 'dart:convert';
import 'package:http/http.dart' as http;

class Release {
  final String tag, name, url;
  final List<ReleaseAsset> assets;
  const Release(this.tag, this.name, this.url, this.assets);
}

class ReleaseAsset {
  final String name, url;
  const ReleaseAsset(this.name, this.url);
}

class ReleaseFetcher {
  static const apiUrl =
      'https://gitlab.com/api/v4/projects/HttpAnimations%2Fwfm/releases?per_page=5';
  static const pageUrl = 'https://gitlab.com/HttpAnimations/wfm/-/releases';

  final http.Client client;
  final String url;
  const ReleaseFetcher(this.client, {this.url = apiUrl});

  Future<List<Release>> fetch() async {
    final r = await client.get(Uri.parse(url));
    if (r.statusCode != 200) throw Exception('releases: ${r.statusCode}');
    return [
      for (final e in jsonDecode(r.body) as List)
        Release(
          '${e['tag_name'] ?? ''}',
          '${e['name'] ?? e['tag_name'] ?? ''}',
          '${e['_links']?['self'] ?? pageUrl}',
          [
            for (final a in (e['assets']?['links'] as List? ?? []))
              ReleaseAsset('${a['name'] ?? ''}',
                  '${a['direct_asset_url'] ?? a['url'] ?? ''}'),
          ],
        ),
    ];
  }
}
