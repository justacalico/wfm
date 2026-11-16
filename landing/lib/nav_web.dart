import 'package:web/web.dart' as web;

void goApp() => web.window.location.href = '/app/';

void openExternal(String url) => web.window.open(url, '_blank');
