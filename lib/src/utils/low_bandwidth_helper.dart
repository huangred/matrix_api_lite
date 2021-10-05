/* MIT License
*
* Copyright (C) 2021 Famedly GmbH
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:coap/coap.dart';
import 'package:http/http.dart' as http;

import 'low_bandwidth_cbor.dart';
import 'streamed_response_extension.dart';
import '../config/coap_config.dart';
import '../model/matrix_connection_exception.dart';
import '../model/matrix_exception.dart';
import '../matrix_api.dart';

class LowBandwidthHelper {
  final int coapVersion;
  final int port;
  final String host;
  late final CoapClient client;
  final CborHelper cbor;
  final MatrixApi api;
  static final DefaultCoapConfig coapConfig = CoapConfig();
  int failedMessagesCount = 0;
  bool connectionDead = false;
  String? bearerToken;
  String? get accessToken => bearerToken;
  set accessToken(String? token) {
    bearerToken = token;
    firstRequest = true;
  }

  bool firstRequest = true;
  LowBandwidthHelper(
      {int coapVersion = -1,
      int cborVersion = -1,
      required this.port,
      required this.host,
      CoapClient? client,
      String? accessToken,
      required this.api})
      : coapVersion = min(coapVersion, _coapPathEnums.keys.reduce(max)),
        cbor = CborHelper(cborVersion),
        bearerToken = accessToken {
    this.client =
        client ?? CoapClient(Uri(scheme: 'coap', host: host, port: port), coapConfig);
  }

  static const _coapPathEnums = <int, Map<String, String>>{
    1: {
      '0': '/_matrix/client/versions',
      '1': '/_matrix/client/r0/login',
      '2': '/_matrix/client/r0/capabilities',
      '3': '/_matrix/client/r0/logout',
      '4': '/_matrix/client/r0/register',
      '5': '/_matrix/client/r0/user/{userId}/filter',
      '6': '/_matrix/client/r0/user/{userId}/filter/{filterId}',
      '7': '/_matrix/client/r0/sync',
      '8': '/_matrix/client/r0/rooms/{roomId}/state/{eventType}/{stateKey}',
      '9': '/_matrix/client/r0/rooms/{roomId}/send/{eventType}/{txnId}',
      'A': '/_matrix/client/r0/rooms/{roomId}/event/{eventId}',
      'B': '/_matrix/client/r0/rooms/{roomId}/state',
      'C': '/_matrix/client/r0/rooms/{roomId}/members',
      'D': '/_matrix/client/r0/rooms/{roomId}/joined_members',
      'E': '/_matrix/client/r0/rooms/{roomId}/messages',
      'F': '/_matrix/client/r0/rooms/{roomId}/redact/{eventId}/{txnId}',
      'G': '/_matrix/client/r0/createRoom',
      'H': '/_matrix/client/r0/directory/room/{roomAlias}',
      'I': '/_matrix/client/r0/joined_rooms',
      'J': '/_matrix/client/r0/rooms/{roomId}/invite',
      'K': '/_matrix/client/r0/rooms/{roomId}/join',
      'L': '/_matrix/client/r0/join/{roomIdOrAlias}',
      'M': '/_matrix/client/r0/rooms/{roomId}/leave',
      'N': '/_matrix/client/r0/rooms/{roomId}/forget',
      'O': '/_matrix/client/r0/rooms/{roomId}/kick',
      'P': '/_matrix/client/r0/rooms/{roomId}/ban',
      'Q': '/_matrix/client/r0/rooms/{roomId}/unban',
      'R': '/_matrix/client/r0/directory/list/room/{roomId}',
      'S': '/_matrix/client/r0/publicRooms',
      'T': '/_matrix/client/r0/user_directory/search',
      'U': '/_matrix/client/r0/profile/{userId}/displayname',
      'V': '/_matrix/client/r0/profile/{userId}/avatar_url',
      'W': '/_matrix/client/r0/profile/{userId}',
      'X': '/_matrix/client/r0/voip/turnServer',
      'Y': '/_matrix/client/r0/rooms/{roomId}/typing/{userId}',
      'Z': '/_matrix/client/r0/rooms/{roomId}/receipt/{receiptType}/{eventId}',
      'a': '/_matrix/client/r0/rooms/{roomId}/read_markers',
      'b': '/_matrix/client/r0/presence/{userId}/status',
      'c': '/_matrix/client/r0/sendToDevice/{eventType}/{txnId}',
      'd': '/_matrix/client/r0/devices',
      'e': '/_matrix/client/r0/devices/{deviceId}',
      'f': '/_matrix/client/r0/delete_devices',
      'g': '/_matrix/client/r0/keys/upload',
      'h': '/_matrix/client/r0/keys/query',
      'i': '/_matrix/client/r0/keys/claim',
      'j': '/_matrix/client/r0/keys/changes',
      'k': '/_matrix/client/r0/pushers',
      'l': '/_matrix/client/r0/pushers/set',
      'm': '/_matrix/client/r0/notifications',
      'n': '/_matrix/client/r0/pushrules/',
      'o': '/_matrix/client/r0/search',
      'p': '/_matrix/client/r0/user/{userId}/rooms/{roomId}/tags',
      'q': '/_matrix/client/r0/user/{userId}/rooms/{roomId}/tags/{tag}',
      'r': '/_matrix/client/r0/user/{userId}/account_data/{type}',
      's':
          '/_matrix/client/r0/user/{userId}/rooms/{roomId}/account_data/{type}',
      't': '/_matrix/client/r0/rooms/{roomId}/context/{eventId}',
      'u': '/_matrix/client/r0/rooms/{roomId}/report/{eventId}',
    },
  };

  Map<String, String> get _coapEnumMap {
    final map = <String, String>{};
    var ver = coapVersion;
    while (ver > 0) {
      if (_coapPathEnums[ver] != null) {
        map.addAll(_coapPathEnums[ver]!);
      }
      ver--;
    }
    return map;
  }

  Uri mapPath(Uri url) {
    final path = url.path;
    for (final entry in _coapEnumMap.entries) {
      final pathGlob = entry.value;
      // pathGlob has the path parameters in form /path/{parameter}, so we want to repalace
      // those with (^[^/]*) to be able to just regex-match the paths instead
      final pathRegexFragment =
          pathGlob.replaceAll(RegExp(r'{\w+}'), '([^/]*)');
      // and now we also have to make sure that we correctly match the start and the end
      // of the path
      final pathRegex = RegExp(r'^' + pathRegexFragment + r'$');
      final match = pathRegex.firstMatch(path);
      if (match != null) {
        // for the new path, we just put in the path replace key, followed by all matches
        var newPath = '/${entry.key}';
        for (var i = 0; i < match.groupCount; i++) {
          final pathSegment =
              Uri.decodeComponent(match[i + 1]!).replaceAll('/', '%2F');
          newPath += '/$pathSegment';
        }
        return url.replace(path: newPath, port: port);
      }
    }
    return url.replace(port: port);
  }

  Future<Map<String, dynamic>> doRequest(
      {required String method,
      required Uri url,
      Map<String, dynamic>? json}) async {
    final retryHttp = () async {
      final response = await api.doRawRequest(
        request: http.Request(method, url),
        json: json,
        authenticated: accessToken != null,
      );
      return await response.toJson();
    };
    if (connectionDead) {
      return await retryHttp();
    }
    print('>>> Low-bandwidth request to $url');
    final request = {
      'delete': () => CoapRequest.newDelete(),
      'get': () => CoapRequest.newGet(),
      'post': () => CoapRequest.newPost(),
      'put': () => CoapRequest.newPut(),
    }[method.toLowerCase()]
        ?.call();
    if (request == null) {
      throw 'Unknown coap method $method';
    }
    final mappedUrl = mapPath(url);
    request.addUriPath(mappedUrl.path);
    if (mappedUrl.queryParametersAll.isNotEmpty) {
      for (final entry in mappedUrl.queryParametersAll.entries) {
        for (final val in entry.value) {
          request.addUriQuery(
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(val)}');
        }
      }
    }
    print('>>> Mapped url to $mappedUrl');
    if (firstRequest) {
      if (accessToken != null) {
        // 256 = access token
        request.setOption(CoapOption.createString(256, accessToken!));
      }
      // 257 = cbor version
      request.setOption(CoapOption.createVal(257, cbor.version));
      firstRequest = false;
    }
    if (json != null) {
      // content-type of 60 is application/cbor
      // https://www.iana.org/assignments/core-parameters/core-parameters.xhtml#content-formats
      final buff = cbor.encode(json);
      if (buff.length > coapConfig.maxMessageSize) {
        print(
            '=== Payload is larger than ${CoapConfig().maxMessageSize} bytes, trying http instead');
        return await retryHttp();
      }
      request.setPayloadMediaRaw(buff, 60);
    }
    //client.timeout = 35000;
    late final CoapResponse response;
    try {
      response = await client.send(request).onError<TimeoutException>((e, s) => CoapResponse(CoapCode.empty));
    } catch (e, s) {
      print('=== Error fetching request: $e');
      print(s);
      connectionDead = true;
      return await retryHttp();
    }
    print(
        '<<< got response (${response.statusCode}) ${response.statusCodeString}');
    if (response.isEmpty ||
        response.statusCode == null ||
        response.statusCode! == 0) {
      failedMessagesCount++;
      // response is empty.....time to re-try with http instead
      print(
          '=== Empty response (timeout), failed messages count $failedMessagesCount');
      if (failedMessagesCount > 2) {
        /*if (failedMessagesCount > 10) {
          print('=== Connection is probably dead at this point');
          connectionDead = true;
        }*/
        print('=== Re-trying http request');
        return await retryHttp();
      }
      throw MatrixConnectionException(
          Exception('coap timeout'), StackTrace.current);
    }
    failedMessagesCount = 0;
    if (response.statusCode! >= 0xa0) {
      // 5xx errors
      String? body = null;
      try {
        body = cbor.decode(response.payload!).toString();
      } catch (_) {
        try {
          body = utf8.decode(response.payload!);
        } catch (_) {
          // do nothing
        }
      }
      if (body != null) {
        throw Exception('${response.statusCodeString} - $body');
      } else {
        throw Exception(response.statusCodeString);
      }
    }
    Map<String, dynamic> body;
    try {
      body = response.payload == null
          ? <String, dynamic>{}
          : cbor.decode(response.payload!);
    } catch (_) {
      String? body = null;
      try {
        body = utf8.decode(response.payload!);
      } catch (_) {
        // do nothing
      }
      if (body != null) {
        throw Exception('${response.statusCodeString} - $body');
      } else {
        throw Exception(response.statusCodeString);
      }
    }
    if (response.statusCode! >= 0x80 && response.statusCode! < 0xa0) {
      // 4xx errors
      throw MatrixException.fromJson(body);
    }
    return body;
  }
}
