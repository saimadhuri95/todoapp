import 'dart:async';
import 'dart:io';

/// RFC 8252 loopback redirect receiver for desktop OAuth flows.
///
/// Providers redirect to `http://127.0.0.1:<ephemeral>/oauth?...`; this
/// helper completes the waiting sign-in and renders a tiny browser page so
/// the user is not left staring at a blank tab.
class LoopbackOAuthRedirectReceiver {
  LoopbackOAuthRedirectReceiver._(this._server)
    : redirectUri = Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: _server.port,
        path: '/oauth',
      ) {
    _subscription = _server.listen(_handle);
  }

  final HttpServer _server;
  final Uri redirectUri;
  final _completer = Completer<Uri>();
  late final StreamSubscription<HttpRequest> _subscription;
  var _closed = false;

  static Future<LoopbackOAuthRedirectReceiver> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return LoopbackOAuthRedirectReceiver._(server);
  }

  Future<Uri> waitForRedirect({Duration timeout = const Duration(minutes: 5)}) {
    return _completer.future.timeout(
      timeout,
      onTimeout: () {
        close();
        throw TimeoutException('Sign-in was not completed');
      },
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.uri.path != redirectUri.path) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      if (!_completer.isCompleted) {
        _completer.complete(
          redirectUri.replace(
            query: request.uri.query,
            fragment: request.uri.fragment,
          ),
        );
      }

      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<!doctype html><title>Knot sign-in complete</title>'
        '<body style="font-family:sans-serif;margin:3rem">'
        '<h1>Knot sign-in complete</h1>'
        '<p>You can close this tab and return to Knot.</p>'
        '</body>',
      );
      await request.response.close();
      await close();
    } catch (e, st) {
      if (!_completer.isCompleted) _completer.completeError(e, st);
    }
  }
}
