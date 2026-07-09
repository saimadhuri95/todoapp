import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart' show Sha256;

import '../../core/clock.dart';
import 'cloud_http.dart';

/// OAuth 2.0 authorization-code + PKCE for native apps (RFC 8252/7636) —
/// how the Dropbox/Google Drive/OneDrive login screen signs in without a
/// client secret. The browser leg happens in the system browser; the
/// custom-scheme redirect comes back through OAuthCallbackChannel.
///
/// No central server is involved (CLAUDE.md): the app talks directly to
/// the provider the *user* chose, holding tokens in the device keychain.
class OAuthConfig {
  const OAuthConfig({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.clientId,
    required this.redirectUri,
    required this.scopes,
    this.extraAuthParams = const {},
  });

  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final String clientId;
  final Uri redirectUri;
  final List<String> scopes;

  /// Provider quirks (e.g. Dropbox `token_access_type=offline`).
  final Map<String, String> extraAuthParams;

  bool get isConfigured => clientId.isNotEmpty;

  OAuthConfig copyWith({Uri? redirectUri, List<String>? scopes}) => OAuthConfig(
    authorizationEndpoint: authorizationEndpoint,
    tokenEndpoint: tokenEndpoint,
    clientId: clientId,
    redirectUri: redirectUri ?? this.redirectUri,
    scopes: scopes ?? this.scopes,
    extraAuthParams: extraAuthParams,
  );
}

/// Issued tokens; serialized as JSON into the keychain.
class TokenSet {
  const TokenSet({
    required this.accessToken,
    this.refreshToken,
    this.expiresAtMs,
  });

  final String accessToken;
  final String? refreshToken;

  /// Epoch ms after which [accessToken] is stale; null = unknown lifetime.
  final int? expiresAtMs;

  bool isExpired(DateTime now, {Duration slack = const Duration(minutes: 2)}) {
    final at = expiresAtMs;
    if (at == null) return false;
    return now.add(slack).millisecondsSinceEpoch >= at;
  }

  String encode() => jsonEncode({
    'access': accessToken,
    if (refreshToken != null) 'refresh': refreshToken,
    if (expiresAtMs != null) 'expiresAtMs': expiresAtMs,
  });

  static TokenSet? decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return TokenSet(
        accessToken: map['access'] as String,
        refreshToken: map['refresh'] as String?,
        expiresAtMs: map['expiresAtMs'] as int?,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

/// One in-flight authorization attempt: hold on to it between opening the
/// browser and receiving the redirect.
class PkceAttempt {
  PkceAttempt._(this.authorizationUrl, this.codeVerifier, this.state);

  final Uri authorizationUrl;
  final String codeVerifier;
  final String state;
}

class OAuthException implements Exception {
  OAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PkceFlow {
  PkceFlow({required this.http, required this.clock, Random? random})
    : _random = random ?? Random.secure();

  final CloudHttp http;
  final Clock clock;
  final Random _random;

  /// Builds the browser URL for [config]; keep the attempt to finish later.
  Future<PkceAttempt> begin(OAuthConfig config) async {
    final verifier = _randomUrlSafe(64);
    final hash = await Sha256().hash(ascii.encode(verifier));
    final challenge = base64UrlEncode(hash.bytes).replaceAll('=', '');
    final state = _randomUrlSafe(16);
    final url = config.authorizationEndpoint.replace(
      queryParameters: {
        ...config.authorizationEndpoint.queryParameters,
        'response_type': 'code',
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri.toString(),
        if (config.scopes.isNotEmpty) 'scope': config.scopes.join(' '),
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': state,
        ...config.extraAuthParams,
      },
    );
    return PkceAttempt._(url, verifier, state);
  }

  /// Exchanges the redirect for tokens. [redirect] is the full callback
  /// URI (`knot://oauth?code=...&state=...`).
  Future<TokenSet> finish(
    OAuthConfig config,
    PkceAttempt attempt,
    Uri redirect,
  ) async {
    final params = redirect.queryParameters;
    if (params['state'] != attempt.state) {
      throw OAuthException('State mismatch — possible interception');
    }
    final error = params['error'];
    if (error != null) {
      throw OAuthException('Provider refused: $error');
    }
    final code = params['code'];
    if (code == null) throw OAuthException('Redirect carried no code');
    return _token(config, {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': config.redirectUri.toString(),
      'code_verifier': attempt.codeVerifier,
    });
  }

  Future<TokenSet> refresh(OAuthConfig config, String refreshToken) => _token(
    config,
    {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
    // Providers may omit the refresh token on rotation-less refreshes;
    // keep using the one we have.
    fallbackRefreshToken: refreshToken,
  );

  Future<TokenSet> _token(
    OAuthConfig config,
    Map<String, String> params, {
    String? fallbackRefreshToken,
  }) async {
    final response = await http.send(
      'POST',
      config.tokenEndpoint,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: utf8.encode(
        Uri(queryParameters: {...params, 'client_id': config.clientId}).query,
      ),
    );
    if (!response.ok) {
      throw OAuthException('Token endpoint ${response.status}');
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw OAuthException('Token endpoint returned non-JSON');
    }
    final expiresIn = json['expires_in'];
    return TokenSet(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? fallbackRefreshToken,
      expiresAtMs: expiresIn is num
          ? clock
                .now()
                .add(Duration(seconds: expiresIn.toInt()))
                .millisecondsSinceEpoch
          : null,
    );
  }

  String _randomUrlSafe(int bytes) => base64UrlEncode(
    List<int>.generate(bytes, (_) => _random.nextInt(256)),
  ).replaceAll('=', '');
}
