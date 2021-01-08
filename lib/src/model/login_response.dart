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

import 'well_known_informations.dart';

class LoginResponse {
  String userId;
  String accessToken;
  String deviceId;
  WellKnownInformations wellKnownInformations;

  LoginResponse.fromJson(Map<String, dynamic> json) {
    userId = json['user_id'];
    accessToken = json['access_token'];
    deviceId = json['device_id'];
    if (json['well_known'] is Map) {
      wellKnownInformations =
          WellKnownInformations.fromJson(json['well_known']);
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (userId != null) data['user_id'] = userId;
    if (accessToken != null) data['access_token'] = accessToken;
    if (deviceId != null) data['device_id'] = deviceId;
    if (wellKnownInformations != null) {
      data['well_known'] = wellKnownInformations.toJson();
    }
    return data;
  }
}
