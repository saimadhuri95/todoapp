class LoopbackOAuthRedirectReceiver {
  LoopbackOAuthRedirectReceiver._();

  Uri get redirectUri => throw UnsupportedError(
    'Loopback OAuth redirects are unavailable on this platform.',
  );

  static Future<LoopbackOAuthRedirectReceiver> start() async =>
      throw UnsupportedError(
        'Loopback OAuth redirects are unavailable on this platform.',
      );

  Future<Uri> waitForRedirect({
    Duration timeout = const Duration(minutes: 5),
  }) async => throw UnsupportedError(
    'Loopback OAuth redirects are unavailable on this platform.',
  );

  Future<void> close() async {}
}
