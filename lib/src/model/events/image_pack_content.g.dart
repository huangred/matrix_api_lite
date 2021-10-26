// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_pack_content.dart';

// **************************************************************************
// EnhancedEnumGenerator
// **************************************************************************

extension ImagePackUsageFromStringExtension on Iterable<ImagePackUsage> {
  ImagePackUsage? fromString(String? val) {
    final override = {
      'sticker': ImagePackUsage.sticker,
      'emoticon': ImagePackUsage.emoticon,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension ImagePackUsageEnhancedEnum on ImagePackUsage {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        ImagePackUsage.sticker: 'sticker',
        ImagePackUsage.emoticon: 'emoticon',
      }[this]!;
  bool get isSticker => this == ImagePackUsage.sticker;
  bool get isEmoticon => this == ImagePackUsage.emoticon;
  T when<T>({
    required T Function() sticker,
    required T Function() emoticon,
  }) =>
      {
        ImagePackUsage.sticker: sticker,
        ImagePackUsage.emoticon: emoticon,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? sticker,
    T? Function()? emoticon,
    required T Function() orElse,
  }) =>
      {
        ImagePackUsage.sticker: sticker,
        ImagePackUsage.emoticon: emoticon,
      }[this]
          ?.call() ??
      orElse();
}
