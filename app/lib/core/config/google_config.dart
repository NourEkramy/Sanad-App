/// Google sign-in settings that identify this app to Google. Client IDs are
/// public identifiers, not secrets.
abstract final class GoogleConfig {
  /// The **Web application** OAuth client ID from the app's Google Cloud
  /// project. With it, Sanad signs in to a Google account first and then
  /// asks for Drive access for that account (Google's main Android flow).
  /// Set at build time: `--dart-define=GOOGLE_WEB_CLIENT_ID=…`.
  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
}
