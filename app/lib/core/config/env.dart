/// Build-time configuration supplied with
/// `--dart-define-from-file=env/<flavor>.json` (see docs/08-deployment.md).
///
/// Only the public anon key belongs here: every table is protected by Row
/// Level Security, and the service-role key must never ship in the app.
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Deep link used by password-reset e-mails.
  static const authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'com.sanad.sanad://auth-callback',
  );

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
