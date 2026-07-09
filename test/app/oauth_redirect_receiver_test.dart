import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/oauth_redirect_receiver.dart';

void main() {
  test(
    'loopback receiver completes with the provider redirect query',
    () async {
      final receiver = await LoopbackOAuthRedirectReceiver.start();
      addTearDown(receiver.close);

      expect(receiver.redirectUri.scheme, 'http');
      expect(receiver.redirectUri.host, '127.0.0.1');

      final client = HttpClient();
      addTearDown(client.close);
      final redirect = receiver.waitForRedirect();

      final request = await client.getUrl(
        receiver.redirectUri.replace(
          queryParameters: {'code': 'c0de', 'state': 'state-1'},
        ),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);

      final uri = await redirect;
      expect(uri.queryParameters['code'], 'c0de');
      expect(uri.queryParameters['state'], 'state-1');
    },
  );
}
