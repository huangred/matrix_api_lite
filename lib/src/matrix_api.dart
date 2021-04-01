/* MIT License
*
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
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
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:json_rest_api_client/json_rest_api_client.dart';
import 'package:mime/mime.dart';

import '../matrix_api_lite.dart';
import 'model/auth/authentication_data.dart';
import 'model/auth/authentication_types.dart';
import 'model/device.dart';
import 'model/event_context.dart';
import 'model/events_sync_update.dart';
import 'model/filter.dart';
import 'model/keys_query_response.dart';
import 'model/login_response.dart';
import 'model/login_types.dart';
import 'model/matrix_connection_exception.dart';
import 'model/matrix_event.dart';
import 'model/matrix_exception.dart';
import 'model/matrix_keys.dart';
import 'model/notifications_query_response.dart';
import 'model/one_time_keys_claim_response.dart';
import 'model/open_graph_data.dart';
import 'model/open_id_credentials.dart';
import 'model/presence_content.dart';
import 'model/profile.dart';
import 'model/public_rooms_response.dart';
import 'model/push_rule_set.dart';
import 'model/pusher.dart';
import 'model/request_token_response.dart';
import 'model/room_alias_information.dart';
import 'model/room_keys_info.dart';
import 'model/room_keys_keys.dart';
import 'model/server_capabilities.dart';
import 'model/supported_protocol.dart';
import 'model/supported_versions.dart';
import 'model/sync_update.dart';
import 'model/tag.dart';
import 'model/third_party_identifier.dart';
import 'model/third_party_location.dart';
import 'model/third_party_user.dart';
import 'model/timeline_history_response.dart';
import 'model/turn_server_credentials.dart';
import 'model/upload_key_signatures_response.dart';
import 'model/user_search_result.dart';
import 'model/well_known_information.dart';
import 'model/who_is_info.dart';

enum IdServerUnbindResult { success, no_support }
enum ThirdPartyIdentifierMedium { email, msisdn }
enum Membership { join, invite, leave, ban }
enum Direction { b, f }
enum Visibility { public, private }
enum CreateRoomPreset { private_chat, public_chat, trusted_private_chat }

String describeEnum(Object enumEntry) {
  final description = enumEntry.toString();
  final indexOfDot = description.indexOf('.');
  assert(indexOfDot != -1 && indexOfDot < description.length - 1);
  return description.substring(indexOfDot + 1);
}

class MatrixApi extends JsonRestApiClient {
  /// The homeserver this client is communicating with.
  Uri get homeserver => Uri.parse(baseUrl.origin);
  set homeserver(Uri origin) {
    baseUrl = origin?.resolveUri(Uri(path: '/_matrix'));
  }

  bool get _testMode =>
      homeserver.toString() == 'https://fakeserver.notexisting';

  MatrixApi({
    Uri homeserver,
    String bearerToken,
    http.Client httpClient,
  }) : super(
          homeserver?.resolveUri(Uri(path: '/_matrix')),
          bearerToken: bearerToken,
          httpClient: httpClient,
        );

  /// Used for all Matrix json requests using the [c2s API](https://matrix.org/docs/spec/client_server/r0.6.0.html).
  ///
  /// Throws: TimeoutException, FormatException, MatrixException
  ///
  /// You must first set [this.homeserver] and for some endpoints also
  /// [this.accessToken] before you can use this! For example to send a
  /// message to a Matrix room with the id '!fjd823j:example.com' you call:
  /// ```
  /// final resp = await request(
  ///   RequestMethod.put,
  ///   '/r0/rooms/!fjd823j:example.com/send/m.room.message/$txnId',
  ///   json: {
  ///     'msgtype': 'm.text',
  ///     'body': 'hello'
  ///   }
  ///  );
  /// ```
  ///
  @override
  Future<JsonRestApiResponse> request(
    RequestMethod method,
    String endpoint, {
    dynamic json,
    Map<String, dynamic> queryParameters,
    Duration timeout,
    Map<String, String> headers = const {},
  }) async {
    try {
      return await super.request(
        method,
        endpoint,
        json: json,
        queryParameters: queryParameters,
        timeout: timeout,
        headers: headers,
      );
    } on JsonRestApiException catch (e) {
      throw MatrixException.fromJson(e.jsonObject);
    } catch (e, s) {
      throw MatrixConnectionException(e, s);
    }
  }

  /// Gets the versions of the specification supported by the server.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-matrix-client-versions
  Future<SupportedVersions> requestSupportedVersions() async {
    final response = await request(
      RequestMethod.get,
      '/client/versions',
    );
    return SupportedVersions.fromJson(response.jsonObject);
  }

  /// Gets discovery information about the domain. The file may include additional keys.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-well-known-matrix-client
  Future<WellKnownInformation> requestWellKnownInformation() async {
    final response =
        await httpClient.get(homeserver.resolve('.well-known/matrix/client'));
    final rawJson = json.decode(response.body);
    return WellKnownInformation.fromJson(rawJson);
  }

  Future<LoginTypes> requestLoginTypes() async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/login',
    );
    return LoginTypes.fromJson(response.jsonObject);
  }

  /// Authenticates the user, and issues an access token they can use to authorize themself in subsequent requests.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-login
  /// To just login with the username 'alice' you set [identifier] to:
  /// `AuthenticationUserIdentifier(user: 'alice')`
  /// Maybe you want to set [user] to the same String to stay compatible with
  /// older server versions.
  Future<LoginResponse> login({
    String type = AuthenticationTypes.password,
    AuthenticationIdentifier identifier,
    String password,
    String token,
    String deviceId,
    String initialDeviceDisplayName,
    AuthenticationData auth,
    @Deprecated('Deprecated in favour of identifier.') String user,
    @Deprecated('Deprecated in favour of identifier.') String medium,
    @Deprecated('Deprecated in favour of identifier.') String address,
  }) async {
    final response =
        await request(RequestMethod.post, '/client/r0/login', json: {
      'type': type,
      if (identifier != null) 'identifier': identifier.toJson(),
      if (user != null) 'user': user,
      if (medium != null) 'medium': medium,
      if (address != null) 'address': address,
      if (password != null) 'password': password,
      if (token != null) 'token': token,
      if (deviceId != null) 'device_id': deviceId,
      if (initialDeviceDisplayName != null)
        'initial_device_display_name': initialDeviceDisplayName,
      if (auth != null) 'auth': auth.toJson(),
    });
    return LoginResponse.fromJson(response.jsonObject);
  }

  /// Invalidates an existing access token, so that it can no longer be used for authorization.
  /// The device associated with the access token is also deleted. Device keys for the device
  /// are deleted alongside the device.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-logout
  Future<void> logout() async {
    await request(
      RequestMethod.post,
      '/client/r0/logout',
    );
    return;
  }

  /// Invalidates all access tokens for a user, so that they can no longer be used
  /// for authorization. This includes the access token that made this request. All
  /// devices for the user are also deleted. Device keys for the device are
  /// deleted alongside the device.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-logout-all
  Future<void> logoutAll() async {
    await request(
      RequestMethod.post,
      '/client/r0/logout/all',
    );
    return;
  }

  /// Register for an account on this homeserver.
  ///
  /// There are two kinds of user account:
  ///
  /// user accounts. These accounts may use the full API described in this
  /// specification.
  /// guest accounts. These accounts may have limited permissions and may not
  /// be supported by all servers.
  ///
  /// If registration is successful, this endpoint will issue an access token
  /// the client can use to authorize itself in subsequent requests.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-register
  Future<LoginResponse> register({
    String username,
    String password,
    String deviceId,
    String initialDeviceDisplayName,
    bool inhibitLogin,
    AuthenticationData auth,
    String kind,
  }) async {
    final response = await request(RequestMethod.post, '/client/r0/register',
        queryParameters: {
          if (kind != null) 'kind': kind,
        },
        json: {
          if (username != null) 'username': username,
          if (password != null) 'password': password,
          if (deviceId != null) 'device_id': deviceId,
          if (initialDeviceDisplayName != null)
            'initial_device_display_name': initialDeviceDisplayName,
          if (inhibitLogin != null) 'inhibit_login': inhibitLogin,
          if (auth != null) 'auth': auth.toJson(),
        });
    return LoginResponse.fromJson(response.jsonObject);
  }

  /// The homeserver must check that the given email address is not already associated
  /// with an account on this homeserver. The homeserver should validate the email
  /// itself, either by sending a validation email itself or by using a service it
  /// has control over.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-register-email-requesttoken
  Future<RequestTokenResponse> requestEmailToken(
    String email,
    String clientSecret,
    int sendAttempt, {
    String nextLink,
    String idServer,
    String idAccessToken,
  }) async {
    final response = await request(
        RequestMethod.post, '/client/r0/register/email/requestToken',
        json: {
          'email': email,
          'send_attempt': sendAttempt,
          'client_secret': clientSecret,
          if (nextLink != null) 'next_link': nextLink,
          if (idServer != null) 'id_server': idServer,
          if (idAccessToken != null) 'id_access_token': idAccessToken,
        });
    return RequestTokenResponse.fromJson(response.jsonObject);
  }

  /// The homeserver must check that the given phone number is not already associated with an
  /// account on this homeserver. The homeserver should validate the phone number itself,
  /// either by sending a validation message itself or by using a service it has control over.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-register-msisdn-requesttoken
  Future<RequestTokenResponse> requestMsisdnToken(
    String country,
    String phoneNumber,
    String clientSecret,
    int sendAttempt, {
    String nextLink,
    String idServer,
    String idAccessToken,
  }) async {
    final response = await request(
        RequestMethod.post, '/client/r0/register/msisdn/requestToken',
        json: {
          'country': country,
          'phone_number': phoneNumber,
          'send_attempt': sendAttempt,
          'client_secret': clientSecret,
          if (nextLink != null) 'next_link': nextLink,
          if (idServer != null) 'id_server': idServer,
          if (idAccessToken != null) 'id_access_token': idAccessToken,
        });
    return RequestTokenResponse.fromJson(response.jsonObject);
  }

  /// Changes the password for an account on this homeserver.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-password
  Future<void> changePassword(
    String newPassword, {
    AuthenticationData auth,
  }) async {
    await request(RequestMethod.post, '/client/r0/account/password', json: {
      'new_password': newPassword,
      if (auth != null) 'auth': auth.toJson(),
    });
    return;
  }

  /// The homeserver must check that the given email address is associated with
  /// an account on this homeserver. This API should be used to request
  /// validation tokens when authenticating for the /account/password endpoint.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-password-email-requesttoken
  Future<RequestTokenResponse> resetPasswordUsingEmail(
    String email,
    String clientSecret,
    int sendAttempt, {
    String nextLink,
    String idServer,
    String idAccessToken,
  }) async {
    final response = await request(
        RequestMethod.post, '/client/r0/account/password/email/requestToken',
        json: {
          'email': email,
          'send_attempt': sendAttempt,
          'client_secret': clientSecret,
          if (nextLink != null) 'next_link': nextLink,
          if (idServer != null) 'id_server': idServer,
          if (idAccessToken != null) 'id_access_token': idAccessToken,
        });
    return RequestTokenResponse.fromJson(response.jsonObject);
  }

  /// The homeserver must check that the given phone number is associated with
  /// an account on this homeserver. This API should be used to request validation
  /// tokens when authenticating for the /account/password endpoint.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-password-msisdn-requesttoken
  Future<RequestTokenResponse> resetPasswordUsingMsisdn(
    String country,
    String phoneNumber,
    String clientSecret,
    int sendAttempt, {
    String nextLink,
    String idServer,
    String idAccessToken,
  }) async {
    final response = await request(
        RequestMethod.post, '/client/r0/account/password/msisdn/requestToken',
        json: {
          'country': country,
          'phone_number': phoneNumber,
          'send_attempt': sendAttempt,
          'client_secret': clientSecret,
          if (nextLink != null) 'next_link': nextLink,
          if (idServer != null) 'id_server': idServer,
          if (idAccessToken != null) 'id_access_token': idAccessToken,
        });
    return RequestTokenResponse.fromJson(response.jsonObject);
  }

  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-account-deactivate
  Future<IdServerUnbindResult> deactivateAccount({
    String idServer,
    AuthenticationData auth,
  }) async {
    final response = await request(
        RequestMethod.post, '/client/r0/account/deactivate',
        json: {
          if (idServer != null) 'id_server': idServer,
          if (auth != null) 'auth': auth.toJson(),
        });

    return IdServerUnbindResult.values.firstWhere(
      (i) => describeEnum(i) == response.jsonObject['id_server_unbind_result'],
    );
  }

  Future<bool> usernameAvailable(String username) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/register/available',
      queryParameters: {
        'username': username,
      },
    );
    return response.jsonObject['available'];
  }

  /// Gets a list of the third party identifiers that the homeserver has
  /// associated with the user's account.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-matrix-client-r0-register-available
  Future<List<ThirdPartyIdentifier>> requestThirdPartyIdentifiers() async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/account/3pid',
    );
    return (response.jsonObject['threepids'] as List)
        .map((item) => ThirdPartyIdentifier.fromJson(item))
        .toList();
  }

  /// Adds contact information to the user's account. Homeservers
  /// should use 3PIDs added through this endpoint for password resets
  /// instead of relying on the identity server.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-3pid-add
  Future<void> addThirdPartyIdentifier(
    String clientSecret,
    String sid, {
    AuthenticationData auth,
  }) async {
    await request(RequestMethod.post, '/client/r0/account/3pid/add', json: {
      'sid': sid,
      'client_secret': clientSecret,
      if (auth != null) 'auth': auth.toJson(),
    });
    return;
  }

  /// Binds a 3PID to the user's account through the specified identity server.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-3pid-bind
  Future<void> bindThirdPartyIdentifier(
    String clientSecret,
    String sid,
    String idServer,
    String idAccessToken,
  ) async {
    await request(RequestMethod.post, '/client/r0/account/3pid/bind', json: {
      'sid': sid,
      'client_secret': clientSecret,
      'id_server': idServer,
      'id_access_token': idAccessToken,
    });
    return;
  }

  /// Removes a third party identifier from the user's account. This might not cause an unbind of the identifier from the identity server.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-3pid-delete
  Future<IdServerUnbindResult> deleteThirdPartyIdentifier(
    String address,
    ThirdPartyIdentifierMedium medium, {
    String idServer,
  }) async {
    final response = await request(
        RequestMethod.post, '/client/r0/account/3pid/delete',
        json: {
          'address': address,
          'medium': describeEnum(medium),
          if (idServer != null) 'id_server': idServer,
        });
    return IdServerUnbindResult.values.firstWhere(
      (i) => describeEnum(i) == response.jsonObject['id_server_unbind_result'],
    );
  }

  /// Removes a user's third party identifier from the provided identity server without removing it from the homeserver.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-3pid-unbind
  Future<IdServerUnbindResult> unbindThirdPartyIdentifier(
    String address,
    ThirdPartyIdentifierMedium medium,
    String idServer,
  ) async {
    final response = await request(
        RequestMethod.post, '/client/r0/account/3pid/unbind',
        json: {
          'address': address,
          'medium': describeEnum(medium),
          'id_server': idServer,
        });
    return IdServerUnbindResult.values.firstWhere(
      (i) => describeEnum(i) == response.jsonObject['id_server_unbind_result'],
    );
  }

  /// This API should be used to request validation tokens when adding an email address to an account.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-3pid-email-requesttoken
  Future<RequestTokenResponse> requestEmailValidationToken(
    String email,
    String clientSecret,
    int sendAttempt, {
    String nextLink,
    String idServer,
    String idAccessToken,
  }) async {
    final response = await request(
        RequestMethod.post, '/client/r0/account/3pid/email/requestToken',
        json: {
          'email': email,
          'send_attempt': sendAttempt,
          'client_secret': clientSecret,
          if (nextLink != null) 'next_link': nextLink,
          if (idServer != null) 'id_server': idServer,
          if (idAccessToken != null) 'id_access_token': idAccessToken,
        });
    return RequestTokenResponse.fromJson(response.jsonObject);
  }

  /// This API should be used to request validation tokens when adding a phone number to an account.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-3pid-msisdn-requesttoken
  Future<RequestTokenResponse> requestMsisdnValidationToken(
    String country,
    String phoneNumber,
    String clientSecret,
    int sendAttempt, {
    String nextLink,
    String idServer,
    String idAccessToken,
  }) async {
    final response = await request(
        RequestMethod.post, '/client/r0/account/3pid/msisdn/requestToken',
        json: {
          'country': country,
          'phone_number': phoneNumber,
          'send_attempt': sendAttempt,
          'client_secret': clientSecret,
          if (nextLink != null) 'next_link': nextLink,
          if (idServer != null) 'id_server': idServer,
          if (idAccessToken != null) 'id_access_token': idAccessToken,
        });
    return RequestTokenResponse.fromJson(response.jsonObject);
  }

  /// Gets information about the owner of a given access token.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-matrix-client-r0-account-whoami
  Future<String> whoAmI() async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/account/whoami',
    );
    return response.jsonObject['user_id'];
  }

  /// Gets information about the server's supported feature set and other relevant capabilities.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-matrix-client-r0-capabilities
  Future<ServerCapabilities> requestServerCapabilities() async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/capabilities',
    );
    return ServerCapabilities.fromJson(response.jsonObject['capabilities']);
  }

  /// Uploads a new filter definition to the homeserver. Returns a filter ID that may be used
  /// in future requests to restrict which events are returned to the client.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-user-userid-filter
  Future<String> uploadFilter(
    String userId,
    Filter filter,
  ) async {
    final response = await request(
      RequestMethod.post,
      '/client/r0/user/${Uri.encodeComponent(userId)}/filter',
      json: filter.toJson(),
    );
    return response.jsonObject['filter_id'];
  }

  /// Download a filter
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-user-userid-filter
  Future<Filter> downloadFilter(String userId, String filterId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/user/${Uri.encodeComponent(userId)}/filter/${Uri.encodeComponent(filterId)}',
    );
    return Filter.fromJson(response.jsonObject);
  }

  /// Synchronise the client's state with the latest state on the server. Clients use this API when
  /// they first log in to get an initial snapshot of the state on the server, and then continue to
  /// call this API to get incremental deltas to the state, and to receive new messages.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-matrix-client-r0-sync
  Future<SyncUpdate> sync({
    String filter,
    String since,
    bool fullState,
    PresenceType setPresence,
    int timeout,
  }) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/sync',
      queryParameters: {
        if (filter != null) 'filter': filter,
        if (since != null) 'since': since,
        if (fullState != null) 'full_state': fullState.toString(),
        if (setPresence != null) 'set_presence': describeEnum(setPresence),
        if (timeout != null) 'timeout': timeout.toString(),
      },
    );
    return SyncUpdate.fromJson(response.jsonObject);
  }

  /// Get a single event based on roomId/eventId. You must have permission to
  /// retrieve this event e.g. by being a member in the room for this event.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-matrix-client-r0-rooms-roomid-event-eventid
  Future<MatrixEvent> requestEvent(String roomId, String eventId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/rooms/${Uri.encodeComponent(roomId)}/event/${Uri.encodeComponent(eventId)}',
    );
    return MatrixEvent.fromJson(response.jsonObject);
  }

  /// Looks up the contents of a state event in a room. If the user is joined to the room then the
  /// state is taken from the current state of the room. If the user has left the room then the
  /// state is taken from the state of the room when they left.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-matrix-client-r0-rooms-roomid-state-eventtype-statekey
  Future<Map<String, dynamic>> requestStateContent(
      String roomId, String eventType,
      [String stateKey]) async {
    var url =
        '/client/r0/rooms/${Uri.encodeComponent(roomId)}/state/${Uri.encodeComponent(eventType)}/';
    if (stateKey != null) {
      url += Uri.encodeComponent(stateKey);
    }
    final response = await request(
      RequestMethod.get,
      url,
    );
    return response.jsonObject;
  }

  /// Get the state events for the current state of a room.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-matrix-client-r0-rooms-roomid-state
  Future<List<MatrixEvent>> requestStates(String roomId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/rooms/${Uri.encodeComponent(roomId)}/state',
    );
    return response.jsonArray.map((i) => MatrixEvent.fromJson(i)).toList();
  }

  /// Get the list of members for this room.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-matrix-client-r0-rooms-roomid-members
  Future<List<MatrixEvent>> requestMembers(
    String roomId, {
    String at,
    Membership membership,
    Membership notMembership,
  }) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/rooms/${Uri.encodeComponent(roomId)}/members',
      queryParameters: {
        if (at != null) 'at': at,
        if (membership != null) 'membership': describeEnum(membership),
        if (notMembership != null)
          'not_membership': describeEnum(notMembership),
      },
    );
    return (response.jsonObject['chunk'] as List)
        .map((i) => MatrixEvent.fromJson(i))
        .toList();
  }

  /// This API returns a map of MXIDs to member info objects for members of the room.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-matrix-client-r0-rooms-roomid-joined-members
  Future<Map<String, Profile>> requestJoinedMembers(String roomId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/rooms/${Uri.encodeComponent(roomId)}/joined_members',
    );
    return (response.jsonObject['joined'] as Map).map(
      (k, v) => MapEntry(k, Profile.fromJson(v)),
    );
  }

  /// This API returns a list of message and state events for a room. It uses pagination query
  /// parameters to paginate history in the room.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-matrix-client-r0-rooms-roomid-messages
  Future<TimelineHistoryResponse> requestMessages(
    String roomId,
    String from,
    Direction dir, {
    String to,
    int limit,
    String filter,
  }) async {
    final response = await request(RequestMethod.get,
        '/client/r0/rooms/${Uri.encodeComponent(roomId)}/messages',
        queryParameters: {
          'from': from,
          'dir': describeEnum(dir),
          if (to != null) 'to': to,
          if (limit != null) 'limit': limit.toString(),
          if (filter != null) 'filter': filter,
        });
    return TimelineHistoryResponse.fromJson(response.jsonObject);
  }

  /// State events can be sent using this endpoint.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#put-matrix-client-r0-rooms-roomid-state-eventtype-statekey
  Future<String> sendState(
    String roomId,
    String eventType,
    Map<String, dynamic> content, [
    String stateKey = '',
  ]) async {
    final response = await request(RequestMethod.put,
        '/client/r0/rooms/${Uri.encodeComponent(roomId)}/state/${Uri.encodeComponent(eventType)}/${Uri.encodeComponent(stateKey)}',
        json: content);
    return response.jsonObject['event_id'];
  }

  /// This endpoint is used to send a message event to a room.
  /// Message events allow access to historical events and pagination,
  /// making them suited for "once-off" activity in a room.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#put-matrix-client-r0-rooms-roomid-send-eventtype-txnid
  Future<String> sendMessage(
    String roomId,
    String eventType,
    String txnId,
    Map<String, dynamic> content,
  ) async {
    final response = await request(RequestMethod.put,
        '/client/r0/rooms/${Uri.encodeComponent(roomId)}/send/${Uri.encodeComponent(eventType)}/${Uri.encodeComponent(txnId)}',
        json: content);
    return response.jsonObject['event_id'];
  }

  /// Strips all information out of an event which isn't critical to the integrity of
  /// the server-side representation of the room.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#put-matrix-client-r0-rooms-roomid-redact-eventid-txnid
  Future<String> redact(
    String roomId,
    String eventId,
    String txnId, {
    String reason,
  }) async {
    final response = await request(RequestMethod.put,
        '/client/r0/rooms/${Uri.encodeComponent(roomId)}/redact/${Uri.encodeComponent(eventId)}/${Uri.encodeComponent(txnId)}',
        json: {
          if (reason != null) 'reason': reason,
        });
    return response.jsonObject['event_id'];
  }

  Future<String> createRoom({
    Visibility visibility,
    String roomAliasName,
    String name,
    String topic,
    List<String> invite,
    List<Map<String, dynamic>> invite3pid,
    String roomVersion,
    Map<String, dynamic> creationContent,
    List<Map<String, dynamic>> initialState,
    CreateRoomPreset preset,
    bool isDirect,
    Map<String, dynamic> powerLevelContentOverride,
  }) async {
    final response =
        await request(RequestMethod.post, '/client/r0/createRoom', json: {
      if (visibility != null) 'visibility': describeEnum(visibility),
      if (roomAliasName != null) 'room_alias_name': roomAliasName,
      if (name != null) 'name': name,
      if (topic != null) 'topic': topic,
      if (invite != null) 'invite': invite,
      if (invite3pid != null) 'invite_3pid': invite3pid,
      if (roomVersion != null) 'room_version': roomVersion,
      if (creationContent != null) 'creation_content': creationContent,
      if (initialState != null) 'initial_state': initialState,
      if (preset != null) 'preset': describeEnum(preset),
      if (isDirect != null) 'is_direct': isDirect,
      if (powerLevelContentOverride != null)
        'power_level_content_override': powerLevelContentOverride,
    });
    return response.jsonObject['room_id'];
  }

  /// Create a new mapping from room alias to room ID.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-directory-room-roomalias
  Future<void> createRoomAlias(String alias, String roomId) async {
    await request(
      RequestMethod.put,
      '/client/r0/directory/room/${Uri.encodeComponent(alias)}',
      json: {'room_id': roomId},
    );
    return;
  }

  /// Requests that the server resolve a room alias to a room ID.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-directory-room-roomalias
  Future<RoomAliasInformation> requestRoomAliasInformation(String alias) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/directory/room/${Uri.encodeComponent(alias)}',
    );
    return RoomAliasInformation.fromJson(response.jsonObject);
  }

  /// Remove a mapping of room alias to room ID.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#delete-matrix-client-r0-directory-room-roomalias
  Future<void> removeRoomAlias(String alias) async {
    await request(
      RequestMethod.delete,
      '/client/r0/directory/room/${Uri.encodeComponent(alias)}',
    );
    return;
  }

  /// Get a list of aliases maintained by the local server for the given room.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-rooms-roomid-aliases
  Future<List<String>> requestRoomAliases(String roomId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/room/${Uri.encodeComponent(roomId)}/aliases',
    );
    return List<String>.from(response.jsonObject['aliases']);
  }

  /// This API returns a list of the user's current rooms.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-joined-rooms
  Future<List<String>> requestJoinedRooms() async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/joined_rooms',
    );
    return List<String>.from(response.jsonObject['joined_rooms']);
  }

  /// This API invites a user to participate in a particular room.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-rooms-roomid-invite
  Future<void> inviteToRoom(String roomId, String userId) async {
    await request(
      RequestMethod.post,
      '/client/r0/rooms/${Uri.encodeComponent(roomId)}/invite',
      json: {
        'user_id': userId,
      },
    );
    return;
  }

  /// This API starts a user participating in a particular room, if that user is allowed to participate in that room.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-rooms-roomid-invite
  Future<String> joinRoom(
    String roomId, {
    String thirdPidSignedSender,
    String thirdPidSignedmxid,
    String thirdPidSignedToken,
    Map<String, dynamic> thirdPidSignedSiganture,
  }) async {
    final response = await request(
      RequestMethod.post,
      '/client/r0/rooms/${Uri.encodeComponent(roomId)}/join',
      json: {
        if (thirdPidSignedSiganture != null)
          'third_party_signed': {
            'sender': thirdPidSignedSender,
            'mxid': thirdPidSignedmxid,
            'token': thirdPidSignedToken,
            'signatures': thirdPidSignedSiganture,
          }
      },
    );
    return response.jsonObject['room_id'];
  }

  /// This API starts a user participating in a particular room, if that user is allowed to participate in that room.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-join-roomidoralias
  Future<String> joinRoomOrAlias(
    String roomIdOrAlias, {
    List<String> servers,
    String thirdPidSignedSender,
    String thirdPidSignedmxid,
    String thirdPidSignedToken,
    Map<String, dynamic> thirdPidSignedSiganture,
  }) async {
    final response = await request(
      RequestMethod.post,
      '/client/r0/join/${Uri.encodeComponent(roomIdOrAlias)}',
      queryParameters: {'server_name': servers ?? []},
      json: {
        if (thirdPidSignedSiganture != null)
          'third_party_signed': {
            'sender': thirdPidSignedSender,
            'mxid': thirdPidSignedmxid,
            'token': thirdPidSignedToken,
            'signatures': thirdPidSignedSiganture,
          }
      },
    );
    return response.jsonObject['room_id'];
  }

  /// This API stops a user participating in a particular room.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-rooms-roomid-leave
  Future<void> leaveRoom(String roomId) async {
    await request(
      RequestMethod.post,
      '/client/r0/rooms/${Uri.encodeComponent(roomId)}/leave',
    );
    return;
  }

  /// This API stops a user remembering about a particular room.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-rooms-roomid-forget
  Future<void> forgetRoom(String roomId) async {
    await request(
      RequestMethod.post,
      '/client/r0/rooms/${Uri.encodeComponent(roomId)}/forget',
    );
    return;
  }

  /// Kick a user from the room.
  /// The caller must have the required power level in order to perform this operation.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-rooms-roomid-kick
  Future<void> kickFromRoom(String roomId, String userId,
      {String reason}) async {
    await request(RequestMethod.post,
        '/client/r0/rooms/${Uri.encodeComponent(roomId)}/kick',
        json: {
          'user_id': userId,
          if (reason != null) 'reason': reason,
        });
    return;
  }

  /// Ban a user in the room. If the user is currently in the room, also kick them.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-rooms-roomid-ban
  Future<void> banFromRoom(String roomId, String userId,
      {String reason}) async {
    await request(RequestMethod.post,
        '/client/r0/rooms/${Uri.encodeComponent(roomId)}/ban',
        json: {
          'user_id': userId,
          if (reason != null) 'reason': reason,
        });
    return;
  }

  /// Unban a user from the room. This allows them to be invited to the room, and join if they
  /// would otherwise be allowed to join according to its join rules.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-rooms-roomid-unban
  Future<void> unbanInRoom(String roomId, String userId) async {
    await request(RequestMethod.post,
        '/client/r0/rooms/${Uri.encodeComponent(roomId)}/unban',
        json: {
          'user_id': userId,
        });
    return;
  }

  /// Gets the visibility of a given room on the server's public room directory.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-directory-list-room-roomid
  Future<Visibility> requestRoomVisibility(String roomId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/directory/list/room/${Uri.encodeComponent(roomId)}',
    );
    return Visibility.values.firstWhere(
        (v) => describeEnum(v) == response.jsonObject['visibility']);
  }

  /// Sets the visibility of a given room in the server's public room directory.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-directory-list-room-roomid
  Future<void> setRoomVisibility(String roomId, Visibility visibility) async {
    await request(
      RequestMethod.put,
      '/client/r0/directory/list/room/${Uri.encodeComponent(roomId)}',
      json: {
        'visibility': describeEnum(visibility),
      },
    );
    return;
  }

  /// Lists the public rooms on the server.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-publicrooms
  Future<PublicRoomsResponse> requestPublicRooms({
    int limit,
    String since,
    String server,
  }) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/publicRooms',
      queryParameters: {
        if (limit != null) 'limit': limit.toString(),
        if (since != null) 'since': since,
        if (server != null) 'server': server,
      },
    );
    return PublicRoomsResponse.fromJson(response.jsonObject);
  }

  /// Lists the public rooms on the server, with optional filter.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-publicrooms
  Future<PublicRoomsResponse> searchPublicRooms({
    String genericSearchTerm,
    int limit,
    String since,
    String server,
    bool includeAllNetworks,
    String thirdPartyInstanceId,
  }) async {
    final response = await request(
      RequestMethod.post,
      '/client/r0/publicRooms',
      queryParameters: {
        if (server != null) 'server': server,
      },
      json: {
        if (limit != null) 'limit': limit,
        if (since != null) 'since': since,
        if (includeAllNetworks != null)
          'include_all_networks': includeAllNetworks,
        if (thirdPartyInstanceId != null)
          'third_party_instance_id': thirdPartyInstanceId,
        if (genericSearchTerm != null)
          'filter': {
            'generic_search_term': genericSearchTerm,
          },
      },
    );
    return PublicRoomsResponse.fromJson(response.jsonObject);
  }

  /// Performs a search for users. The homeserver may determine which subset of users are searched,
  /// however the homeserver MUST at a minimum consider the users the requesting user shares a
  /// room with and those who reside in public rooms (known to the homeserver). The search MUST
  /// consider local users to the homeserver, and SHOULD query remote users as part of the search.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-user-directory-search
  Future<UserSearchResult> searchUser(
    String searchTerm, {
    int limit,
  }) async {
    final response = await request(
      RequestMethod.post,
      '/client/r0/user_directory/search',
      json: {
        'search_term': searchTerm,
        if (limit != null) 'limit': limit,
      },
    );
    return UserSearchResult.fromJson(response.jsonObject);
  }

  /// This API sets the given user's display name. You must have permission to
  /// set this user's display name, e.g. you need to have their access_token.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-profile-userid-displayname
  Future<void> setDisplayname(String userId, String displayname) async {
    await request(
      RequestMethod.put,
      '/client/r0/profile/${Uri.encodeComponent(userId)}/displayname',
      json: {
        'displayname': displayname,
      },
    );
    return;
  }

  /// Get the user's display name. This API may be used to fetch the user's own
  /// displayname or to query the name of other users; either locally or on remote homeservers.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-profile-userid-displayname
  Future<String> requestDisplayname(String userId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/profile/${Uri.encodeComponent(userId)}/displayname',
    );
    return response.jsonObject['displayname'];
  }

  /// This API sets the given user's avatar URL. You must have permission to set
  /// this user's avatar URL, e.g. you need to have their access_token.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-profile-userid-avatar-url
  Future<void> setAvatarUrl(String userId, Uri avatarUrl) async {
    await request(
      RequestMethod.put,
      '/client/r0/profile/${Uri.encodeComponent(userId)}/avatar_url',
      json: {
        'avatar_url': avatarUrl.toString(),
      },
    );
    return;
  }

  /// Get the user's avatar URL. This API may be used to fetch the user's own avatar URL or to
  /// query the URL of other users; either locally or on remote homeservers.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-profile-userid-avatar-url
  Future<Uri> requestAvatarUrl(String userId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/profile/${Uri.encodeComponent(userId)}/avatar_url',
    );
    return Uri.parse(response.jsonObject['avatar_url']);
  }

  /// Get the combined profile information for this user. This API may be used to fetch the user's
  /// own profile information or other users; either locally or on remote homeservers.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-profile-userid-avatar-url
  Future<Profile> requestProfile(String userId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/profile/${Uri.encodeComponent(userId)}',
    );
    return Profile.fromJson(response.jsonObject);
  }

  /// This API provides credentials for the client to use when initiating calls.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-voip-turnserver
  Future<TurnServerCredentials> requestTurnServerCredentials() async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/voip/turnServer',
    );
    return TurnServerCredentials.fromJson(response.jsonObject);
  }

  /// This tells the server that the user is typing for the next N milliseconds
  /// where N is the value specified in the timeout key. Alternatively, if typing is false,
  /// it tells the server that the user has stopped typing.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-rooms-roomid-typing-userid
  Future<void> sendTypingNotification(
    String userId,
    String roomId,
    bool typing, {
    int timeout,
  }) async {
    await request(RequestMethod.put,
        '/client/r0/rooms/${Uri.encodeComponent(roomId)}/typing/${Uri.encodeComponent(userId)}',
        json: {
          'typing': typing,
          if (timeout != null) 'timeout': timeout,
        });
    return;
  }

  /// This API updates the marker for the given receipt type to the event ID specified.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-rooms-roomid-receipt-receipttype-eventid
  ///
  Future<void> sendReceiptMarker(String roomId, String eventId) async {
    await request(
      RequestMethod.post,
      '/client/r0/rooms/${Uri.encodeComponent(roomId)}/receipt/m.read/${Uri.encodeComponent(eventId)}',
    );
    return;
  }

  /// Sets the position of the read marker for a given room, and optionally the read receipt's location.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-rooms-roomid-read-markers
  Future<void> sendReadMarker(String roomId, String eventId,
      {String readReceiptLocationEventId}) async {
    await request(
      RequestMethod.post,
      '/client/r0/rooms/${Uri.encodeComponent(roomId)}/read_markers',
      json: {
        'm.fully_read': eventId,
        if (readReceiptLocationEventId != null)
          'm.read': readReceiptLocationEventId,
      },
    );
    return;
  }

  /// This API sets the given user's presence state. When setting the status,
  /// the activity time is updated to reflect that activity; the client does not need
  /// to specify the last_active_ago field. You cannot set the presence state of another user.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-presence-userid-status
  Future<void> sendPresence(
    String userId,
    PresenceType presenceType, {
    String statusMsg,
  }) async {
    await request(
      RequestMethod.put,
      '/client/r0/presence/${Uri.encodeComponent(userId)}/status',
      json: {
        'presence': describeEnum(presenceType),
        if (statusMsg != null) 'status_msg': statusMsg,
      },
    );
    return;
  }

  /// Get the given user's presence state.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-presence-userid-status
  Future<PresenceContent> requestPresence(String userId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/presence/${Uri.encodeComponent(userId)}/status',
    );
    return PresenceContent.fromJson(response.jsonObject);
  }

  /// Uploads a file with the name [fileName] as base64 encoded to the server
  /// and returns the mxc url as a string.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-media-r0-upload
  Future<String> upload(Uint8List file, String fileName,
      {String contentType}) async {
    fileName = fileName.split('/').last;
    final length = file.length;
    var headers = <String, String>{};
    headers['Authorization'] = 'Bearer $bearerToken';
    headers['Content-Type'] =
        contentType ?? lookupMimeType(fileName, headerBytes: file);
    headers['Content-Length'] = length.toString();
    fileName = Uri.encodeQueryComponent(fileName);
    final url = homeserver.resolveUri(Uri(
      path: '_matrix/media/r0/upload',
      queryParameters: {'filename': fileName},
    ));
    final streamedRequest = http.StreamedRequest('POST', url)
      ..headers.addAll(headers);
    streamedRequest.contentLength = length;
    streamedRequest.sink.add(file);
    streamedRequest.sink.close();
    var streamedResponse = _testMode ? null : await streamedRequest.send();
    Map<String, dynamic> jsonResponse = json.decode(
      String.fromCharCodes(_testMode
          ? ((fileName == 'file.jpeg')
                  ? '{"content_uri": "mxc://example.com/AQwafuaFswefuhsfAFAgsw"}'
                  : '{"errcode":"M_FORBIDDEN","error":"Cannot upload this content"}')
              .codeUnits
          : await streamedResponse.stream.first),
    );
    if (!(jsonResponse['content_uri'] is String)) {
      throw MatrixException.fromJson(jsonResponse);
    }
    return jsonResponse['content_uri'];
  }

  /// Get information about a URL for the client. Typically this is called when a client sees a
  /// URL in a message and wants to render a preview for the user.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-media-r0-preview-url
  Future<OpenGraphData> requestOpenGraphDataForUrl(Uri url, {int ts}) async {
    var action = homeserver
        .resolveUri(Uri(path: '_matrix/media/r0/preview_url', queryParameters: {
      'url': url.toString(),
      if (ts != null) 'ts': ts.toString(),
    }));
    final response = await httpClient.get(action);
    final rawJson = json.decode(response.body.isEmpty ? '{}' : response.body);
    return OpenGraphData.fromJson(rawJson);
  }

  /// This endpoint allows clients to retrieve the configuration of the content repository, such as upload limitations.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-media-r0-config
  Future<int> requestMaxUploadSize() async {
    var action = homeserver.resolve('_matrix/media/r0/config');
    final response = await httpClient.get(action);
    final rawJson = json.decode(response.body.isEmpty ? '{}' : response.body);
    return rawJson['m.upload.size'];
  }

  /// This endpoint is used to send send-to-device events to a set of client devices.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-sendtodevice-eventtype-txnid
  Future<void> sendToDevice(
    String eventType,
    String txnId,
    Map<String, Map<String, Map<String, dynamic>>> messages,
  ) async {
    await request(
      RequestMethod.put,
      '/client/r0/sendToDevice/${Uri.encodeComponent(eventType)}/${Uri.encodeComponent(txnId)}',
      json: {
        'messages': messages,
      },
    );
    return;
  }

  /// Gets information about all devices for the current user.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-devices
  Future<List<Device>> requestDevices() async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/devices',
    );
    return (response.jsonObject['devices'] as List)
        .map((i) => Device.fromJson(i))
        .toList();
  }

  /// Gets information on a single device, by device id.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-devices-deviceid
  Future<Device> requestDevice(String deviceId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/devices/${Uri.encodeComponent(deviceId)}',
    );
    return Device.fromJson(response.jsonObject);
  }

  /// Updates the metadata on the given device.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-devices-deviceid
  Future<void> setDeviceMetadata(String deviceId, {String displayName}) async {
    await request(RequestMethod.put,
        '/client/r0/devices/${Uri.encodeComponent(deviceId)}',
        json: {
          if (displayName != null) 'display_name': displayName,
        });
    return;
  }

  /// Deletes the given device, and invalidates any access token associated with it.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#delete-matrix-client-r0-devices-deviceid
  Future<void> deleteDevice(String deviceId, {AuthenticationData auth}) async {
    await request(RequestMethod.delete,
        '/client/r0/devices/${Uri.encodeComponent(deviceId)}',
        json: {
          if (auth != null) 'auth': auth.toJson(),
        });
    return;
  }

  /// Deletes the given devices, and invalidates any access token associated with them.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-delete-devices
  Future<void> deleteDevices(List<String> deviceIds,
      {AuthenticationData auth}) async {
    await request(RequestMethod.post, '/client/r0/delete_devices', json: {
      'devices': deviceIds,
      if (auth != null) 'auth': auth.toJson(),
    });
    return;
  }

  /// Publishes end-to-end encryption keys for the device.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-keys-query
  Future<Map<String, int>> uploadDeviceKeys(
      {MatrixDeviceKeys deviceKeys,
      Map<String, dynamic> oneTimeKeys,
      Map<String, dynamic> fallbackKeys}) async {
    final response = await request(
      RequestMethod.post,
      '/client/r0/keys/upload',
      json: {
        if (deviceKeys != null) 'device_keys': deviceKeys.toJson(),
        if (oneTimeKeys != null) 'one_time_keys': oneTimeKeys,
        if (fallbackKeys != null) ...{
          'fallback_keys': fallbackKeys,
          'org.matrix.msc2732.fallback_keys': fallbackKeys,
        },
      },
    );
    return Map<String, int>.from(response.jsonObject['one_time_key_counts']);
  }

  /// Returns the current devices and identity keys for the given users.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-keys-query
  Future<KeysQueryResponse> requestDeviceKeys(
    Map<String, dynamic> deviceKeys, {
    int timeout,
    String token,
  }) async {
    final response = await request(
      RequestMethod.post,
      '/client/r0/keys/query',
      json: {
        'device_keys': deviceKeys,
        if (timeout != null) 'timeout': timeout,
        if (token != null) 'token': token,
      },
    );
    return KeysQueryResponse.fromJson(response.jsonObject);
  }

  /// Claims one-time keys for use in pre-key messages.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-keys-claim
  Future<OneTimeKeysClaimResponse> requestOneTimeKeys(
    Map<String, Map<String, String>> oneTimeKeys, {
    int timeout,
  }) async {
    final response = await request(
      RequestMethod.post,
      '/client/r0/keys/claim',
      json: {
        'one_time_keys': oneTimeKeys,
        if (timeout != null) 'timeout': timeout,
      },
    );
    return OneTimeKeysClaimResponse.fromJson(response.jsonObject);
  }

  /// Gets a list of users who have updated their device identity keys since a previous sync token.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-keys-upload
  Future<DeviceListsUpdate> requestDeviceListsUpdate(
      String from, String to) async {
    final response = await request(RequestMethod.get, '/client/r0/keys/changes',
        queryParameters: {
          'from': from,
          'to': to,
        });
    return DeviceListsUpdate.fromJson(response.jsonObject);
  }

  /// Uploads your own cross-signing keys.
  /// https://github.com/matrix-org/matrix-doc/pull/2536
  Future<void> uploadDeviceSigningKeys({
    MatrixCrossSigningKey masterKey,
    MatrixCrossSigningKey selfSigningKey,
    MatrixCrossSigningKey userSigningKey,
    AuthenticationData auth,
  }) async {
    await request(
      RequestMethod.post,
      '/client/unstable/keys/device_signing/upload',
      json: {
        if (masterKey != null) 'master_key': masterKey.toJson(),
        if (selfSigningKey != null) 'self_signing_key': selfSigningKey.toJson(),
        if (userSigningKey != null) 'user_signing_key': userSigningKey.toJson(),
        if (auth != null) 'auth': auth.toJson(),
      },
    );
  }

  /// Uploads new signatures of keys
  /// https://github.com/matrix-org/matrix-doc/pull/2536
  Future<UploadKeySignaturesResponse> uploadKeySignatures(
      List<MatrixSignableKey> keys) async {
    final payload = <String, dynamic>{};
    for (final key in keys) {
      if (key.identifier == null ||
          key.signatures == null ||
          key.signatures.isEmpty) {
        continue;
      }
      if (!payload.containsKey(key.userId)) {
        payload[key.userId] = <String, dynamic>{};
      }
      if (payload[key.userId].containsKey(key.identifier)) {
        // we need to merge signature objects
        payload[key.userId][key.identifier]['signatures']
            .addAll(key.signatures);
      } else {
        // we can just add signatures
        payload[key.userId][key.identifier] = key.toJson();
      }
    }
    final response = await request(
      RequestMethod.post,
      '/client/r0/keys/signatures/upload',
      json: payload,
    );
    return UploadKeySignaturesResponse.fromJson(response.jsonObject);
  }

  /// Gets all currently active pushers for the authenticated user.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-pushers
  Future<List<Pusher>> requestPushers() async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/pushers',
    );
    return (response.jsonObject['pushers'] as List)
        .map((i) => Pusher.fromJson(i))
        .toList();
  }

  /// This endpoint allows the creation, modification and deletion of pushers
  /// for this user ID. The behaviour of this endpoint varies depending on the
  /// values in the JSON body.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-pushers-set
  Future<void> setPusher(Pusher pusher, {bool append}) async {
    var data = pusher.toJson();
    if (append != null) {
      data['append'] = append;
    }
    await request(
      RequestMethod.post,
      '/client/r0/pushers/set',
      json: data,
    );
    return;
  }

  /// This API is used to paginate through the list of events that the user has
  /// been, or would have been notified about.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-notifications
  Future<NotificationsQueryResponse> requestNotifications({
    String from,
    int limit,
    String only,
  }) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/notifications',
      queryParameters: {
        if (from != null) 'from': from,
        if (limit != null) 'limit': limit.toString(),
        if (only != null) 'only': only,
      },
    );
    return NotificationsQueryResponse.fromJson(response.jsonObject);
  }

  /// Retrieve all push rulesets for this user. Clients can "drill-down"
  /// on the rulesets by suffixing a scope to this path e.g. /pushrules/global/.
  /// This will return a subset of this data under the specified key e.g. the global key.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-pushrules
  Future<PushRuleSet> requestPushRules() async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/pushrules',
    );
    return PushRuleSet.fromJson(response.jsonObject['global']);
  }

  /// Retrieve a single specified push rule.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-pushrules-scope-kind-ruleid
  Future<PushRule> requestPushRule(
    String scope,
    PushRuleKind kind,
    String ruleId,
  ) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(describeEnum(kind))}/${Uri.encodeComponent(ruleId)}',
    );
    return PushRule.fromJson(response.jsonObject);
  }

  /// This endpoint removes the push rule defined in the path.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#delete-matrix-client-r0-pushrules-scope-kind-ruleid
  Future<void> deletePushRule(
    String scope,
    PushRuleKind kind,
    String ruleId,
  ) async {
    await request(
      RequestMethod.delete,
      '/client/r0/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(describeEnum(kind))}/${Uri.encodeComponent(ruleId)}',
    );
    return;
  }

  /// This endpoint allows the creation, modification and deletion of pushers for this user ID.
  /// The behaviour of this endpoint varies depending on the values in the JSON body.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-pushrules-scope-kind-ruleid
  Future<void> setPushRule(
    String scope,
    PushRuleKind kind,
    String ruleId,
    List<PushRuleAction> actions, {
    String before,
    String after,
    List<PushConditions> conditions,
    String pattern,
  }) async {
    await request(RequestMethod.put,
        '/client/r0/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(describeEnum(kind))}/${Uri.encodeComponent(ruleId)}',
        queryParameters: {
          if (before != null) 'before': before,
          if (after != null) 'after': after,
        },
        json: {
          'actions': actions.map(describeEnum).toList(),
          if (conditions != null)
            'conditions': conditions.map((c) => c.toJson()).toList(),
          if (pattern != null) 'pattern': pattern,
        });
    return;
  }

  /// This endpoint gets whether the specified push rule is enabled.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-pushrules-scope-kind-ruleid-enabled
  Future<bool> requestPushRuleEnabled(
    String scope,
    PushRuleKind kind,
    String ruleId,
  ) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(describeEnum(kind))}/${Uri.encodeComponent(ruleId)}/enabled',
    );
    return response.jsonObject['enabled'];
  }

  /// This endpoint allows clients to enable or disable the specified push rule.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-pushrules-scope-kind-ruleid-enabled
  Future<void> enablePushRule(
    String scope,
    PushRuleKind kind,
    String ruleId,
    bool enabled,
  ) async {
    await request(
      RequestMethod.put,
      '/client/r0/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(describeEnum(kind))}/${Uri.encodeComponent(ruleId)}/enabled',
      json: {'enabled': enabled},
    );
    return;
  }

  /// This endpoint get the actions for the specified push rule.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-pushrules-scope-kind-ruleid-actions
  Future<List<PushRuleAction>> requestPushRuleActions(
    String scope,
    PushRuleKind kind,
    String ruleId,
  ) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(describeEnum(kind))}/${Uri.encodeComponent(ruleId)}/actions',
    );
    return (response.jsonObject['actions'] as List)
        .map((i) =>
            PushRuleAction.values.firstWhere((a) => describeEnum(a) == i))
        .toList();
  }

  /// This endpoint allows clients to change the actions of a push rule. This can be used to change the actions of builtin rules.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-pushrules-scope-kind-ruleid-actions
  Future<void> setPushRuleActions(
    String scope,
    PushRuleKind kind,
    String ruleId,
    List<PushRuleAction> actions,
  ) async {
    await request(
      RequestMethod.put,
      '/client/r0/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(describeEnum(kind))}/${Uri.encodeComponent(ruleId)}/actions',
      json: {'actions': actions.map((a) => describeEnum(a)).toList()},
    );
    return;
  }

  /// Performs a full text search across different categories.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-search
  /// Please note: The specification is not 100% clear what it is expecting and sending here.
  /// So we stick with pure json until we have more information.
  Future<Map<String, dynamic>> globalSearch(Map<String, dynamic> query) async {
    return (await request(
      RequestMethod.post,
      '/client/r0/search',
      json: query,
    ))
        .jsonObject;
  }

  /// This will listen for new events related to a particular room and return them to the
  /// caller. This will block until an event is received, or until the timeout is reached.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-events
  Future<EventsSyncUpdate> requestEvents({
    String from,
    int timeout,
    String roomId,
  }) async {
    final response =
        await request(RequestMethod.get, '/client/r0/events', queryParameters: {
      if (from != null) 'from': from,
      if (timeout != null) 'timeout': timeout.toString(),
      if (roomId != null) 'roomId': roomId,
    });
    return EventsSyncUpdate.fromJson(response.jsonObject);
  }

  /// List the tags set by a user on a room.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-user-userid-rooms-roomid-tags
  Future<Map<String, Tag>> requestRoomTags(String userId, String roomId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/user/${Uri.encodeComponent(userId)}/rooms/${Uri.encodeComponent(roomId)}/tags',
    );
    return (response.jsonObject['tags'] as Map).map(
      (k, v) => MapEntry(k, Tag.fromJson(v)),
    );
  }

  /// Add a tag to the room.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-user-userid-rooms-roomid-tags-tag
  Future<void> addRoomTag(
    String userId,
    String roomId,
    String tag, {
    double order,
  }) async {
    await request(RequestMethod.put,
        '/client/r0/user/${Uri.encodeComponent(userId)}/rooms/${Uri.encodeComponent(roomId)}/tags/${Uri.encodeComponent(tag)}',
        json: {
          if (order != null) 'order': order,
        });
    return;
  }

  /// Remove a tag from the room.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-user-userid-rooms-roomid-tags-tag
  Future<void> removeRoomTag(String userId, String roomId, String tag) async {
    await request(
      RequestMethod.delete,
      '/client/r0/user/${Uri.encodeComponent(userId)}/rooms/${Uri.encodeComponent(roomId)}/tags/${Uri.encodeComponent(tag)}',
    );
    return;
  }

  /// Set some account_data for the client. This config is only visible to the user that set the account_data.
  /// The config will be synced to clients in the top-level account_data.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-user-userid-account-data-type
  Future<void> setAccountData(
    String userId,
    String type,
    Map<String, dynamic> content,
  ) async {
    await request(
      RequestMethod.put,
      '/client/r0/user/${Uri.encodeComponent(userId)}/account_data/${Uri.encodeComponent(type)}',
      json: content,
    );
    return;
  }

  /// Get some account_data for the client. This config is only visible to the user that set the account_data.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-user-userid-account-data-type
  Future<Map<String, dynamic>> requestAccountData(
    String userId,
    String type,
  ) async {
    return (await request(
      RequestMethod.get,
      '/client/r0/user/${Uri.encodeComponent(userId)}/account_data/${Uri.encodeComponent(type)}',
    ))
        .jsonObject;
  }

  /// Set some account_data for the client on a given room. This config is only visible to the user that set
  /// the account_data. The config will be synced to clients in the per-room account_data.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-user-userid-rooms-roomid-account-data-type
  Future<void> setRoomAccountData(
    String userId,
    String roomId,
    String type,
    Map<String, dynamic> content,
  ) async {
    await request(
      RequestMethod.put,
      '/client/r0/user/${Uri.encodeComponent(userId)}/rooms/${Uri.encodeComponent(roomId)}/account_data/${Uri.encodeComponent(type)}',
      json: content,
    );
    return;
  }

  /// Get some account_data for the client on a given room. This config is only visible to the user that set the account_data.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-user-userid-rooms-roomid-account-data-type
  Future<Map<String, dynamic>> requestRoomAccountData(
    String userId,
    String roomId,
    String type,
  ) async {
    return (await request(
      RequestMethod.get,
      '/client/r0/user/${Uri.encodeComponent(userId)}/rooms/${Uri.encodeComponent(roomId)}/account_data/${Uri.encodeComponent(type)}',
    ))
        .jsonObject;
  }

  /// Gets information about a particular user.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-admin-whois-userid
  Future<WhoIsInfo> requestWhoIsInfo(String userId) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/admin/whois/${Uri.encodeComponent(userId)}',
    );
    return WhoIsInfo.fromJson(response.jsonObject);
  }

  /// This API returns a number of events that happened just before and after the specified event.
  /// This allows clients to get the context surrounding an event.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-rooms-roomid-context-eventid
  Future<EventContext> requestEventContext(
    String roomId,
    String eventId, {
    int limit,
    String filter,
  }) async {
    final response = await request(RequestMethod.get,
        '/client/r0/rooms/${Uri.encodeComponent(roomId)}/context/${Uri.encodeComponent(eventId)}',
        queryParameters: {
          if (filter != null) 'filter': filter,
          if (limit != null) 'limit': limit.toString(),
        });
    return EventContext.fromJson(response.jsonObject);
  }

  /// Reports an event as inappropriate to the server, which may then notify the appropriate people.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-rooms-roomid-report-eventid
  Future<void> reportEvent(
    String roomId,
    String eventId,
    String reason,
    int score,
  ) async {
    await request(RequestMethod.post,
        '/client/r0/rooms/${Uri.encodeComponent(roomId)}/report/${Uri.encodeComponent(eventId)}',
        json: {
          'reason': reason,
          'score': score,
        });
    return;
  }

  /// Fetches the overall metadata about protocols supported by the homeserver. Includes
  /// both the available protocols and all fields required for queries against each protocol.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-thirdparty-protocols
  Future<Map<String, SupportedProtocol>> requestSupportedProtocols() async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/thirdparty/protocols',
    );
    return response.jsonObject
        .map((k, v) => MapEntry(k, SupportedProtocol.fromJson(v)));
  }

  /// Fetches the metadata from the homeserver about a particular third party protocol.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-thirdparty-protocol-protocol
  Future<SupportedProtocol> requestSupportedProtocol(String protocol) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/thirdparty/protocol/${Uri.encodeComponent(protocol)}',
    );
    return SupportedProtocol.fromJson(response.jsonObject);
  }

  /// Requesting this endpoint with a valid protocol name results in a list of successful
  /// mapping results in a JSON array.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-thirdparty-location-protocol
  Future<List<ThirdPartyLocation>> requestThirdPartyLocations(
      String protocol) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/thirdparty/location/${Uri.encodeComponent(protocol)}',
    );
    return response.jsonArray
        .map((i) => ThirdPartyLocation.fromJson(i))
        .toList();
  }

  /// Retrieve a Matrix User ID linked to a user on the third party service, given a set of
  /// user parameters.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-thirdparty-user-protocol
  Future<List<ThirdPartyUser>> requestThirdPartyUsers(String protocol) async {
    final response = await request(
      RequestMethod.get,
      '/client/r0/thirdparty/user/${Uri.encodeComponent(protocol)}',
    );
    return response.jsonArray.map((i) => ThirdPartyUser.fromJson(i)).toList();
  }

  /// Retrieve an array of third party network locations from a Matrix room alias.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-thirdparty-location
  Future<List<ThirdPartyLocation>> requestThirdPartyLocationsByAlias(
      String alias) async {
    final response = await request(
        RequestMethod.get, '/client/r0/thirdparty/location',
        queryParameters: {
          'alias': alias,
        });
    return response.jsonArray
        .map((i) => ThirdPartyLocation.fromJson(i))
        .toList();
  }

  /// Retrieve an array of third party users from a Matrix User ID.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-thirdparty-user
  Future<List<ThirdPartyUser>> requestThirdPartyUsersByUserId(
      String userId) async {
    final response = await request(
        RequestMethod.get, '/client/r0/thirdparty/user',
        queryParameters: {
          'userid': userId,
        });
    return response.jsonArray.map((i) => ThirdPartyUser.fromJson(i)).toList();
  }

  Future<OpenIdCredentials> requestOpenIdCredentials(String userId) async {
    final response = await request(
      RequestMethod.post,
      '/client/r0/user/${Uri.encodeComponent(userId)}/openid/request_token',
      json: {},
    );
    return OpenIdCredentials.fromJson(response.jsonObject);
  }

  Future<void> upgradeRoom(String roomId, String version) async {
    await request(
      RequestMethod.post,
      '/client/r0/rooms/${Uri.encodeComponent(roomId)}/upgrade',
      json: {'new_version': version},
    );
    return;
  }

  /// Create room keys backup
  /// https://matrix.org/docs/spec/client_server/unstable#post-matrix-client-r0-room-keys-version
  Future<String> createRoomKeysBackup(
      RoomKeysAlgorithmType algorithm, Map<String, dynamic> authData) async {
    final ret = await request(
      RequestMethod.post,
      '/client/unstable/room_keys/version',
      json: {
        'algorithm': algorithm.algorithmString,
        'auth_data': authData,
      },
    );
    return ret.jsonObject['version'];
  }

  /// Gets a room key backup
  /// https://matrix.org/docs/spec/client_server/unstable#get-matrix-client-r0-room-keys-version
  Future<RoomKeysVersionResponse> getRoomKeysBackup([String version]) async {
    var url = '/client/unstable/room_keys/version';
    if (version != null) {
      url += '/${Uri.encodeComponent(version)}';
    }
    final ret = await request(
      RequestMethod.get,
      url,
    );
    return RoomKeysVersionResponse.fromJson(ret.jsonObject);
  }

  /// Updates a room key backup
  /// https://matrix.org/docs/spec/client_server/unstable#put-matrix-client-r0-room-keys-version-version
  Future<void> updateRoomKeysBackup(String version,
      RoomKeysAlgorithmType algorithm, Map<String, dynamic> authData) async {
    await request(
      RequestMethod.put,
      '/client/unstable/room_keys/version/${Uri.encodeComponent(version)}',
      json: {
        'algorithm': algorithm.algorithmString,
        'auth_data': authData,
        'version': version,
      },
    );
  }

  /// Deletes a room key backup
  /// https://matrix.org/docs/spec/client_server/unstable#delete-matrix-client-r0-room-keys-version-version
  Future<void> deleteRoomKeysBackup(String version) async {
    await request(
      RequestMethod.delete,
      '/client/unstable/room_keys/version/${Uri.encodeComponent(version)}',
    );
  }

  /// Stores a single room key
  /// https://matrix.org/docs/spec/client_server/unstable#put-matrix-client-r0-room-keys-keys-roomid-sessionid
  Future<RoomKeysUpdateResponse> storeRoomKeysSingleKey(String roomId,
      String sessionId, String version, RoomKeysSingleKey session) async {
    final ret = await request(
      RequestMethod.put,
      '/client/unstable/room_keys/keys/${Uri.encodeComponent(roomId)}/${Uri.encodeComponent(sessionId)}',
      queryParameters: {'version': version},
      json: session.toJson(),
    );
    return RoomKeysUpdateResponse.fromJson(ret.jsonObject);
  }

  /// Gets a single room key
  /// https://matrix.org/docs/spec/client_server/unstable#get-matrix-client-r0-room-keys-keys-roomid-sessionid
  Future<RoomKeysSingleKey> getRoomKeysSingleKey(
      String roomId, String sessionId, String version) async {
    final ret = await request(
      RequestMethod.get,
      '/client/unstable/room_keys/keys/${Uri.encodeComponent(roomId)}/${Uri.encodeComponent(sessionId)}',
      queryParameters: {'version': version},
    );
    return RoomKeysSingleKey.fromJson(ret.jsonObject);
  }

  /// Deletes a single room key
  /// https://matrix.org/docs/spec/client_server/unstable#delete-matrix-client-r0-room-keys-keys-roomid-sessionid
  Future<RoomKeysUpdateResponse> deleteRoomKeysSingleKey(
      String roomId, String sessionId, String version) async {
    final ret = await request(
      RequestMethod.delete,
      '/client/unstable/room_keys/keys/${Uri.encodeComponent(roomId)}/${Uri.encodeComponent(sessionId)}',
      queryParameters: {'version': version},
    );
    return RoomKeysUpdateResponse.fromJson(ret.jsonObject);
  }

  /// Stores room keys for a room
  /// https://matrix.org/docs/spec/client_server/unstable#put-matrix-client-r0-room-keys-keys-roomid
  Future<RoomKeysUpdateResponse> storeRoomKeysRoom(
      String roomId, String version, RoomKeysRoom keys) async {
    final ret = await request(
      RequestMethod.put,
      '/client/unstable/room_keys/keys/${Uri.encodeComponent(roomId)}',
      queryParameters: {'version': version},
      json: keys.toJson(),
    );
    return RoomKeysUpdateResponse.fromJson(ret.jsonObject);
  }

  /// Gets room keys for a room
  /// https://matrix.org/docs/spec/client_server/unstable#get-matrix-client-r0-room-keys-keys-roomid
  Future<RoomKeysRoom> getRoomKeysRoom(String roomId, String version) async {
    final ret = await request(
      RequestMethod.get,
      '/client/unstable/room_keys/keys/${Uri.encodeComponent(roomId)}',
      queryParameters: {'version': version},
    );
    return RoomKeysRoom.fromJson(ret.jsonObject);
  }

  /// Deletes room keys for a room
  /// https://matrix.org/docs/spec/client_server/unstable#delete-matrix-client-r0-room-keys-keys-roomid
  Future<RoomKeysUpdateResponse> deleteRoomKeysRoom(
      String roomId, String version) async {
    final ret = await request(
      RequestMethod.delete,
      '/client/unstable/room_keys/keys/${Uri.encodeComponent(roomId)}',
      queryParameters: {'version': version},
    );
    return RoomKeysUpdateResponse.fromJson(ret.jsonObject);
  }

  /// Store multiple room keys
  /// https://matrix.org/docs/spec/client_server/unstable#put-matrix-client-r0-room-keys-keys
  Future<RoomKeysUpdateResponse> storeRoomKeys(
      String version, RoomKeys keys) async {
    final ret = await request(
      RequestMethod.put,
      '/client/unstable/room_keys/keys',
      queryParameters: {'version': version},
      json: keys.toJson(),
    );
    return RoomKeysUpdateResponse.fromJson(ret.jsonObject);
  }

  /// get all room keys
  /// https://matrix.org/docs/spec/client_server/unstable#get-matrix-client-r0-room-keys-keys
  Future<RoomKeys> getRoomKeys(String version) async {
    final ret = await request(
      RequestMethod.get,
      '/client/unstable/room_keys/keys',
      queryParameters: {'version': version},
    );
    return RoomKeys.fromJson(ret.jsonObject);
  }

  /// delete all room keys
  /// https://matrix.org/docs/spec/client_server/unstable#delete-matrix-client-r0-room-keys-keys
  Future<RoomKeysUpdateResponse> deleteRoomKeys(String version) async {
    final ret = await request(
      RequestMethod.delete,
      '/client/unstable/room_keys/keys',
      queryParameters: {'version': version},
    );
    return RoomKeysUpdateResponse.fromJson(ret.jsonObject);
  }
}
