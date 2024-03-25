enum AuthenticationResponse {
  /// When the authentication process was successful.
  verificationSuccessful,

  /// Response sent when the authentication process was a failure.
  verificationFailed,

  /// This represents the absence of a response.
  /// This is mainly the initial state.
  init,
}
