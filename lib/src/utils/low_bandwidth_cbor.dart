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

import 'dart:math';

import 'package:typed_data/typed_data.dart';

import 'package:cbor/cbor.dart';

import 'replace_map_keys_extension.dart';
import 'map_to_json_extension.dart';

class CborHelper {
  final int version;
  CborHelper([int version = -1])
      : version = min(version, _cborIntKeys.keys.reduce(max));

  static const _cborIntKeys = <int, Map<String, int>>{
    1: {
      'event_id': 1,
      'type': 2,
      'content': 3,
      'state_key': 4,
      'room_id': 5,
      'sender': 6,
      'user_id': 7,
      'origin_server_ts': 8,
      'unsigned': 9,
      'prev_content': 10,
      'state': 11,
      'timeline': 12,
      'events': 13,
      'limited': 14,
      'prev_batch': 15,
      'transaction_id': 16,
      'age': 17,
      'redacted_because': 18,
      'next_batch': 19,
      'presence': 20,
      'avatar_url': 21,
      'account_data': 22,
      'rooms': 23,
      'join': 24,
      'membership': 25,
      'displayname': 26,
      'body': 27,
      'msgtype': 28,
      'format': 29,
      'formatted_body': 30,
      'ephemeral': 31,
      'invite_state': 32,
      'leave': 33,
      'third_party_invite': 34,
      'is_direct': 35,
      'hashes': 36,
      'signatures': 37,
      'depth': 38,
      'prev_events': 39,
      'prev_state': 40,
      'auth_events': 41,
      'origin': 42,
      'creator': 43,
      'join_rule': 44,
      'history_visibility': 45,
      'ban': 46,
      'events_default': 47,
      'kick': 48,
      'redact': 49,
      'state_default': 50,
      'users': 51,
      'users_default': 52,
      'reason': 53,
      'visibility': 54,
      'room_alias_name': 55,
      'name': 56,
      'topic': 57,
      'invite': 58,
      'invite_3pid': 59,
      'room_version': 60,
      'creation_content': 61,
      'initial_state': 62,
      'preset': 63,
      'servers': 64,
      'identifier': 65,
      'user': 66,
      'medium': 67,
      'address': 68,
      'password': 69,
      'token': 70,
      'device_id': 71,
      'initial_device_display_name': 72,
      'access_token': 73,
      'home_server': 74,
      'well_known': 75,
      'base_url': 76,
      'device_lists': 77,
      'to_device': 78,
      'peek': 79,
      'last_seen_ip': 80,
      'display_name': 81,
      'typing': 82,
      'last_seen_ts': 83,
      'algorithm': 84,
      'sender_key': 85,
      'session_id': 86,
      'ciphertext': 87,
      'one_time_keys': 88,
      'timeout': 89,
      'recent_rooms': 90,
      'chunk': 91,
      'm.fully_read': 92,
      'device_keys': 93,
      'failures': 94,
      'device_display_name': 95,
      'prev_sender': 96,
      'replaces_state': 97,
      'changed': 98,
      'unstable_features': 99,
      'versions': 100,
      'devices': 101,
      'errcode': 102,
      'error': 103,
      'room_alias': 104,
    },
  };

  Map<String, int> get _replaceMap {
    final map = <String, int>{};
    var ver = version;
    while (ver > 0) {
      if (_cborIntKeys[ver] != null) {
        map.addAll(_cborIntKeys[ver]!);
      }
      ver--;
    }
    return map;
  }

  Map<int, String> get _replaceMapInv =>
      _replaceMap.map((k, v) => MapEntry(v, k));

  Uint8Buffer encode(Map<String, dynamic> json) {
    final replacedJson = json.replaceKeys(_replaceMap);
    final cbor = Cbor();
    cbor.encoder.writeMap(replacedJson);
    return cbor.output.getData();
  }

  Map<String, dynamic> decode(Uint8Buffer buffer) {
    final cbor = Cbor();
    cbor.decodeFromBuffer(buffer);
    final data = cbor.getDecodedData();
    if (data == null || data.length != 1 || !(data.first is Map)) {
      print('=== $buffer');
      throw 'Invalid cbor frame';
    }
    final map = (data.first as Map).replaceKeys(_replaceMapInv);
    return map.toJson();
  }
}
