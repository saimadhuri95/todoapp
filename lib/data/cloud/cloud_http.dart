import 'dart:io';

/// Minimal injectable HTTP for the cloud provider layer. dart:io only —
/// no new dependency — and tiny enough that tests fake it with a map of
/// canned responses. All provider/API errors surface as [HttpException]
/// (an [IOException]) so the sync orchestrator treats them as soft.
class CloudHttpResponse {
  const CloudHttpResponse(this.status, this.bodyBytes, {this.headers});

  final int status;
  final List<int> bodyBytes;
  final Map<String, String>? headers;

  String get body => String.fromCharCodes(bodyBytes);
  bool get ok => status >= 200 && status < 300;
}

abstract interface class CloudHttp {
  Future<CloudHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers,
    List<int>? body,
  });
}

class IoCloudHttp implements CloudHttp {
  IoCloudHttp([HttpClient? client]) : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<CloudHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    final request = await _client.openUrl(method, url);
    headers.forEach(request.headers.set);
    if (body != null) {
      request.contentLength = body.length;
      request.add(body);
    }
    final response = await request.close();
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return CloudHttpResponse(response.statusCode, bytes);
  }
}
