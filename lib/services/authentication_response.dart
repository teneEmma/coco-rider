enum AuthenticationResponse {
  /// When the authentication process was successful.
  successful,

  /// when the authentication process was a failure.
  failed,

  /// This represents the absence of a response.
  /// This is mainly the initial state.
  init,
}
