/// Compile-time configuration from `env/<flavor>.json`.
abstract final class Env {
  /// Tolgee Content Delivery link, e.g. `https://cdn.tolg.ee/<hash>`.
  /// Files are served at `<link>/<languageCode>.json`.
  static const String tolgeeCdnUrl = String.fromEnvironment('TOLGEE_CDN_URL');
}
