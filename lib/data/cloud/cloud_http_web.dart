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

class UnsupportedCloudHttp implements CloudHttp {
  @override
  Future<CloudHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) => throw UnsupportedError('Cloud provider HTTP is unavailable on web.');
}

CloudHttp createCloudHttp() => UnsupportedCloudHttp();
