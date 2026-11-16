void goApp() {}

void Function(String url)? openExternalForTesting;

void openExternal(String url) => openExternalForTesting?.call(url);
