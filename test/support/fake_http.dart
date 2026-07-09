import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/cloud/cloud_http.dart';

/// Scripted HTTP double for the cloud layer: each expectation matches on
/// method + URL prefix and hands back a canned response, recording what
/// was sent. String responses pass through raw (XML for WebDAV); other
/// objects are JSON-encoded; byte lists pass through as-is.
class FakeHttp implements CloudHttp {
  final _script = <(bool Function(String, Uri), CloudHttpResponse)>[];
  final requests =
      <
        (String method, Uri url, Map<String, String> headers, List<int>? body)
      >[];

  void on(
    String method,
    String urlPrefix,
    Object response, {
    int status = 200,
  }) {
    _script.add((
      (m, u) => m == method && u.toString().startsWith(urlPrefix),
      CloudHttpResponse(status, switch (response) {
        final List<int> bytes => bytes,
        final String text => utf8.encode(text),
        _ => utf8.encode(jsonEncode(response)),
      }),
    ));
  }

  @override
  Future<CloudHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    requests.add((method, url, headers, body));
    for (final (matches, response) in _script) {
      if (matches(method, url)) return response;
    }
    fail('Unscripted request: $method $url');
  }
}
