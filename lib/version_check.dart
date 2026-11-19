import 'api.dart';

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
  int compareTo(Version o) => major != o.major
      ? major.compareTo(o.major)
      : minor != o.minor
          ? minor.compareTo(o.minor)
          : patch.compareTo(o.patch);

  @override
  String toString() => '$major.$minor.$patch';
}

class AppUpdate {
  final String version, tag, url;
  const AppUpdate(this.version, this.tag, this.url);
}

class UpdateChecker {
  final Api api;
  const UpdateChecker(this.api);

  static UpdateChecker Function()? factoryForTesting;

  /// The server proxies the releases feed and does the version compare, so
  /// this only renders `{latest, tag, url}` or reports up-to-date.
  Future<AppUpdate?> check() async {
    final j = await api.get('/update-check');
    if (j['upToDate'] == true) return null;
    final latest = '${j['latest'] ?? ''}';
    if (latest.isEmpty) return null;
    return AppUpdate(latest, '${j['tag'] ?? ''}', '${j['url'] ?? ''}');
  }
}
