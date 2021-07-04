// @dart=2.9
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

import '../basic_event.dart';
import '../../utils/try_get_map_extension.dart';

extension ImagePackContentBasicEventExtension on BasicEvent {
  ImagePackContent get parsedImagePackContent =>
      ImagePackContent.fromJson(content);
}

enum ImagePackUsage {
  sticker,
  emoticon,
}

List<ImagePackUsage> imagePackUsageFromJson(List<String> json) {
  return json
      ?.map((v) => {
            'sticker': ImagePackUsage.sticker,
            'emoticon': ImagePackUsage.emoticon,
          }[v])
      ?.where((v) => v != null)
      ?.cast<ImagePackUsage>()
      ?.toList();
}

List<String> imagePackUsageToJson(
    List<ImagePackUsage> usage, List<String> prevUsage) {
  final knownUsages = <String>{'sticker', 'emoticon'};
  final usagesStr = (usage ?? [])
      .map((v) => {
            ImagePackUsage.sticker: 'sticker',
            ImagePackUsage.emoticon: 'emoticon',
          }[v])
      .where((v) => v != null)
      .cast<String>()
      .toList();
  // first we add all the unknown usages and the previous known usages which are new again
  final newUsages = (prevUsage ?? [])
      .where((v) => !knownUsages.contains(v) || usagesStr.contains(v))
      .toList();
  // now we need to add the new usages that we didn't add yet
  newUsages.addAll(usagesStr.where((v) => !newUsages.contains(v)));
  return newUsages;
}

class ImagePackContent {
  // we want to preserve potential custom keys in this object
  final Map<String, dynamic> _json;

  Map<String, ImagePackImageContent> images;
  ImagePackPackContent pack;

  ImagePackContent.fromJson(Map<String, dynamic> json)
      : _json = json,
        pack = ImagePackPackContent.fromJson(
            json.tryGetMap<String, dynamic>('pack', <String, dynamic>{}, true)),
        images = Map<String, ImagePackImageContent>.from((json
                .tryGetMap<String, dynamic>('images', null, true)
                ?.map((k, v) => MapEntry(
                    k,
                    v is Map<String, dynamic> &&
                            // we default to an invalid uri
                            Uri.tryParse(v.tryGet<String>('url', '.::', true)) !=
                                null
                        ? ImagePackImageContent.fromJson(v)
                        : null)) ??
            // the "emoticons" key needs a small migration on the key, ":string:" --> "string"
            json.tryGetMap<String, dynamic>('emoticons', null, true)?.map(
                (k, v) => MapEntry(
                    k.startsWith(':') && k.endsWith(':')
                        ? k.substring(1, k.length - 1)
                        : k,
                    v is Map<String, dynamic> &&
                            // we default to an invalid uri
                            Uri.tryParse(v.tryGet<String>('url', '.::', true)) !=
                                null
                        ? ImagePackImageContent.fromJson(v)
                        : null)) ??
            // the "short" key was still just a map from shortcode to mxc uri
            json.tryGetMap<String, String>('short', null, true)?.map((k, v) =>
                MapEntry(
                    k.startsWith(':') && k.endsWith(':')
                        ? k.substring(1, k.length - 1)
                        : k,
                    // we default to an invalid uri
                    Uri.tryParse(v) != null
                        ? ImagePackImageContent.fromJson(<String, dynamic>{'url': v})
                        : null)) ??
            <String, ImagePackImageContent>{})) {
    images.removeWhere((k, v) => v == null);
  }

  Map<String, dynamic> toJson() {
    // remove the old, obsolete "emoticons" and "short" keys
    _json.remove('emoticons');
    _json.remove('short');
    return {
      ..._json,
      'images': Map<String, dynamic>.from(
          images.map((k, v) => MapEntry(k, v.toJson()))),
      'pack': pack.toJson(),
    };
  }
}

class ImagePackImageContent {
  // we want to preserve potential custom keys in this object
  final Map<String, dynamic> _json;

  Uri url;
  String body;
  Map<String, dynamic> info;
  List<ImagePackUsage> usage;

  ImagePackImageContent.fromJson(Map<String, dynamic> json)
      : _json = json,
        // we default to an invalid uri
        url = Uri.parse(json.tryGet<String>('url', '.::', true)),
        body = json.tryGet<String>('body', null, true),
        info = json.tryGetMap<String, dynamic>('info', null, true),
        usage = imagePackUsageFromJson(
            json.tryGetList<String>('usage', null, true));

  Map<String, dynamic> toJson() {
    return {
      ..._json,
      'url': url.toString(),
      if (body != null) 'body': body,
      if (info != null) 'info': info,
      if (usage != null)
        'usage': imagePackUsageToJson(
            usage, _json.tryGetList<String>('usage', null, true)),
    };
  }
}

class ImagePackPackContent {
  // we want to preserve potential custom keys in this object
  final Map<String, dynamic> _json;

  String displayName;
  Uri avatarUrl;
  List<ImagePackUsage> usage;
  String attribution;

  ImagePackPackContent.fromJson(Map<String, dynamic> json)
      : _json = json,
        displayName = json.tryGet<String>('display_name', null, true),
        // we default to an invalid uri
        avatarUrl =
            Uri.tryParse(json.tryGet<String>('avatar_url', '.::', true)),
        usage = imagePackUsageFromJson(
            json.tryGetList<String>('usage', null, true)),
        attribution = json.tryGet<String>('attribution', null, true);

  Map<String, dynamic> toJson() {
    return {
      ..._json,
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl.toString(),
      if (usage != null)
        'usage': imagePackUsageToJson(
            usage, _json.tryGetList<String>('usage', null, true)),
      if (attribution != null) 'attribution': attribution,
    };
  }
}
