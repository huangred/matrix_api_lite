import 'package:http/http.dart';

class UserAgentClient extends BaseClient {
  final String userAgent;
  final Client _inner;

  UserAgentClient(this.userAgent, this._inner);

  Future<StreamedResponse> send(BaseRequest request) {
    request.headers['user-agent'] = userAgent;
    return _inner.send(request);
  }
}
