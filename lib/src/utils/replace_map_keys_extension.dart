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

extension ReplaceMapKeys on Map {
  List _replaceKeysList(List list, Map replace) => list
      .map((v) => v is List
          ? _replaceKeysList(v, replace)
          : (v is Map ? v.replaceKeys(replace) : v))
      .toList();

  Map replaceKeys(Map replace) {
    final output = {};
    for (final entry in entries) {
      // if we have a collission and both the replace and the original key exists,
      // we *must* preserve the original key
      var newKey = replace[entry.key];
      if (newKey == null || containsKey(newKey)) {
        newKey = entry.key;
      }
      final value = entry.value is List
          ? _replaceKeysList(entry.value, replace)
          : (entry.value is Map
              ? (entry.value as Map).replaceKeys(replace)
              : entry.value);
      output[replace[entry.key] ?? entry.key] = value;
    }
    return output;
  }
}
