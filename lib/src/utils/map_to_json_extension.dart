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

extension ToJsonExtension on Map {
  List<dynamic> _toJsonList(List list) {
    final ret = list.cast<dynamic>();
    for (var i = 0; i < ret.length; i++) {
      final value = ret[i]!;
      if (value is Map) {
        ret[i] = value.toJson();
      } else if (value is List) {
        ret[i] = _toJsonList(value);
      } else if ((value is num) && value.toInt().toDouble() == value) {
        ret[i] = value.toInt();
      } else if (!(value is String ||
          value is int ||
          value is num ||
          value is bool ||
          value == null)) {
        throw 'type \'${value.runtimeType}\' is not a valid json value';
      }
    }
    return ret;
  }

  Map<String, dynamic> toJson() {
    final ret = cast<String, dynamic>();
    for (final key in ret.keys.toList()) {
      final value = ret[key];
      if (value is Map) {
        ret[key] = value.toJson();
      } else if (value is List) {
        ret[key] = _toJsonList(value);
      } else if ((value is num) && value.toInt().toDouble() == value) {
        ret[key] = value.toInt();
      } else if (!(value is String ||
          value is int ||
          value is num ||
          value is bool ||
          value == null)) {
        throw 'type \'${value.runtimeType}\' is not a valid json value';
      }
    }
    return ret;
  }
}
