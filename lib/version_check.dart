import 'dart:convert';
import 'package:http/http.dart' as http;

class Version implements Comparable<Version> {
  final int major, minor, patch;
  const Version(this.major, this.minor, this.patch);

  static Version? tryParse(String s) {
    var v = s.trim();
    if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
    final core = v.split(RegExp('[-+]')).first;
    final parts = core.split('.');
    if (parts.length < 2 || parts.length > 3) return null;
    final n = parts.map((p) => int.tryParse(p)).toList();
    if (n.any((e) => e == null)) return null;
    return Version(n[0]!, n[1]!, n.length > 2 ? n[2]! : 0);
  }

  @override
  int compareTo(Version o) =>
      major != o.major ? major.compareTo(o.major) : minor != o.minor ? minor.compareTo(o.minor) : patch.compareTo(o.patch);

  @override
  String toString() => '$major.$minor.$patch';
}

class AppUpdate {
  final String version, tag, url;
  const AppUpdate(this.version, this.tag, this.url);
}

class UpdateChecker {
  static const projectPath = 'HttpAnimations/wfm';
  static const defaultApi =
      'https://gitlab.com/api/v4/projects/HttpAnimations%2Fwfm/releases';
  static const releasesPage = 'https://gitlab.com/HttpAnimations/wfm/-/releases';

  final http.Client client;
  final String apiUrl, pageUrl;
  const UpdateChecker(this.client, {this.apiUrl = defaultApi, this.pageUrl = releasesPage});

  static UpdateChecker Function()? factoryForTesting;

  Future<AppUpdate?> check(String current) async {
    final r = await client
        .get(Uri.parse('$apiUrl?per_page=100&order_by=released_at&sort=desc'));
    if (r.statusCode != 200) throw Exception('releases: ${r.statusCode}');
    final now = Version.tryParse(current);
    Version? best;
    String? bestTag;
    for (final e in jsonDecode(r.body) as List) {
      final tag = '${(e as Map)['tag_name'] ?? ''}';
      final v = Version.tryParse(tag);
      if (v != null && (best == null || v.compareTo(best) > 0)) {
        best = v;
        bestTag = tag;
      }
    }
    if (best == null || bestTag == null) return null;
    if (now != null && best.compareTo(now) <= 0) return null;
    return AppUpdate('$best', bestTag, '$pageUrl/$bestTag');
  }
}
