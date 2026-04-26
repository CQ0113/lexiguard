/// Simple in-memory singleton to pass the selected role (Client/Lawyer)
/// across a Google Sign-In redirect on web.
///
/// Because [signInWithRedirect] navigates the browser away and back,
/// any local Flutter state is lost. We store the intended role here before
/// the redirect and read it in [main.dart] via [getRedirectResult].
///
/// NOTE: This only works within a single browser session — if the user hard-
/// refreshes before clicking Google sign-in, the role defaults to 'Client'.
class GoogleRedirectState {
  GoogleRedirectState._();

  /// The role ('Client' or 'Lawyer') selected on the login screen before redirect.
  static String pendingRole = 'Client';
}
