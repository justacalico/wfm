window.flutterConfiguration = {
  fontFallbackBaseUrl: "fonts/",
};

window._flutter = window._flutter || {};
let _flutterLoader;
Object.defineProperty(window._flutter, "loader", {
  get() {
    return _flutterLoader;
  },
  set(loader) {
    const original = loader.load.bind(loader);
    loader.load = (options = {}) =>
      original({
        ...options,
        config: {
          fontFallbackBaseUrl: "fonts/",
          ...(options.config || {}),
        },
      });
    _flutterLoader = loader;
  },
});
