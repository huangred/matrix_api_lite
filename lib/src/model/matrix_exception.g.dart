// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matrix_exception.dart';

// **************************************************************************
// EnhancedEnumGenerator
// **************************************************************************

extension MatrixErrorFromStringExtension on Iterable<MatrixError> {
  MatrixError? fromString(String? val) {
    final override = {
      'M_UNKNOWN': MatrixError.M_UNKNOWN,
      'M_UNKNOWN_TOKEN': MatrixError.M_UNKNOWN_TOKEN,
      'M_NOT_FOUND': MatrixError.M_NOT_FOUND,
      'M_FORBIDDEN': MatrixError.M_FORBIDDEN,
      'M_LIMIT_EXCEEDED': MatrixError.M_LIMIT_EXCEEDED,
      'M_USER_IN_USE': MatrixError.M_USER_IN_USE,
      'M_THREEPID_IN_USE': MatrixError.M_THREEPID_IN_USE,
      'M_THREEPID_DENIED': MatrixError.M_THREEPID_DENIED,
      'M_THREEPID_NOT_FOUND': MatrixError.M_THREEPID_NOT_FOUND,
      'M_THREEPID_AUTH_FAILED': MatrixError.M_THREEPID_AUTH_FAILED,
      'M_TOO_LARGE': MatrixError.M_TOO_LARGE,
      'M_MISSING_PARAM': MatrixError.M_MISSING_PARAM,
      'M_UNSUPPORTED_ROOM_VERSION': MatrixError.M_UNSUPPORTED_ROOM_VERSION,
      'M_UNRECOGNIZED': MatrixError.M_UNRECOGNIZED,
    }[val];
// ignore: unnecessary_this
    return this.contains(override) ? override : null;
  }
}

extension MatrixErrorEnhancedEnum on MatrixError {
  @override
// ignore: override_on_non_overriding_member
  String get name => {
        MatrixError.M_UNKNOWN: 'M_UNKNOWN',
        MatrixError.M_UNKNOWN_TOKEN: 'M_UNKNOWN_TOKEN',
        MatrixError.M_NOT_FOUND: 'M_NOT_FOUND',
        MatrixError.M_FORBIDDEN: 'M_FORBIDDEN',
        MatrixError.M_LIMIT_EXCEEDED: 'M_LIMIT_EXCEEDED',
        MatrixError.M_USER_IN_USE: 'M_USER_IN_USE',
        MatrixError.M_THREEPID_IN_USE: 'M_THREEPID_IN_USE',
        MatrixError.M_THREEPID_DENIED: 'M_THREEPID_DENIED',
        MatrixError.M_THREEPID_NOT_FOUND: 'M_THREEPID_NOT_FOUND',
        MatrixError.M_THREEPID_AUTH_FAILED: 'M_THREEPID_AUTH_FAILED',
        MatrixError.M_TOO_LARGE: 'M_TOO_LARGE',
        MatrixError.M_MISSING_PARAM: 'M_MISSING_PARAM',
        MatrixError.M_UNSUPPORTED_ROOM_VERSION: 'M_UNSUPPORTED_ROOM_VERSION',
        MatrixError.M_UNRECOGNIZED: 'M_UNRECOGNIZED',
      }[this]!;
  bool get isMUnknown => this == MatrixError.M_UNKNOWN;
  bool get isMUnknownToken => this == MatrixError.M_UNKNOWN_TOKEN;
  bool get isMNotFound => this == MatrixError.M_NOT_FOUND;
  bool get isMForbidden => this == MatrixError.M_FORBIDDEN;
  bool get isMLimitExceeded => this == MatrixError.M_LIMIT_EXCEEDED;
  bool get isMUserInUse => this == MatrixError.M_USER_IN_USE;
  bool get isMThreepidInUse => this == MatrixError.M_THREEPID_IN_USE;
  bool get isMThreepidDenied => this == MatrixError.M_THREEPID_DENIED;
  bool get isMThreepidNotFound => this == MatrixError.M_THREEPID_NOT_FOUND;
  bool get isMThreepidAuthFailed => this == MatrixError.M_THREEPID_AUTH_FAILED;
  bool get isMTooLarge => this == MatrixError.M_TOO_LARGE;
  bool get isMMissingParam => this == MatrixError.M_MISSING_PARAM;
  bool get isMUnsupportedRoomVersion =>
      this == MatrixError.M_UNSUPPORTED_ROOM_VERSION;
  bool get isMUnrecognized => this == MatrixError.M_UNRECOGNIZED;
  T when<T>({
    required T Function() M_UNKNOWN,
    required T Function() M_UNKNOWN_TOKEN,
    required T Function() M_NOT_FOUND,
    required T Function() M_FORBIDDEN,
    required T Function() M_LIMIT_EXCEEDED,
    required T Function() M_USER_IN_USE,
    required T Function() M_THREEPID_IN_USE,
    required T Function() M_THREEPID_DENIED,
    required T Function() M_THREEPID_NOT_FOUND,
    required T Function() M_THREEPID_AUTH_FAILED,
    required T Function() M_TOO_LARGE,
    required T Function() M_MISSING_PARAM,
    required T Function() M_UNSUPPORTED_ROOM_VERSION,
    required T Function() M_UNRECOGNIZED,
  }) =>
      {
        MatrixError.M_UNKNOWN: M_UNKNOWN,
        MatrixError.M_UNKNOWN_TOKEN: M_UNKNOWN_TOKEN,
        MatrixError.M_NOT_FOUND: M_NOT_FOUND,
        MatrixError.M_FORBIDDEN: M_FORBIDDEN,
        MatrixError.M_LIMIT_EXCEEDED: M_LIMIT_EXCEEDED,
        MatrixError.M_USER_IN_USE: M_USER_IN_USE,
        MatrixError.M_THREEPID_IN_USE: M_THREEPID_IN_USE,
        MatrixError.M_THREEPID_DENIED: M_THREEPID_DENIED,
        MatrixError.M_THREEPID_NOT_FOUND: M_THREEPID_NOT_FOUND,
        MatrixError.M_THREEPID_AUTH_FAILED: M_THREEPID_AUTH_FAILED,
        MatrixError.M_TOO_LARGE: M_TOO_LARGE,
        MatrixError.M_MISSING_PARAM: M_MISSING_PARAM,
        MatrixError.M_UNSUPPORTED_ROOM_VERSION: M_UNSUPPORTED_ROOM_VERSION,
        MatrixError.M_UNRECOGNIZED: M_UNRECOGNIZED,
      }[this]!();
  T maybeWhen<T>({
    T? Function()? M_UNKNOWN,
    T? Function()? M_UNKNOWN_TOKEN,
    T? Function()? M_NOT_FOUND,
    T? Function()? M_FORBIDDEN,
    T? Function()? M_LIMIT_EXCEEDED,
    T? Function()? M_USER_IN_USE,
    T? Function()? M_THREEPID_IN_USE,
    T? Function()? M_THREEPID_DENIED,
    T? Function()? M_THREEPID_NOT_FOUND,
    T? Function()? M_THREEPID_AUTH_FAILED,
    T? Function()? M_TOO_LARGE,
    T? Function()? M_MISSING_PARAM,
    T? Function()? M_UNSUPPORTED_ROOM_VERSION,
    T? Function()? M_UNRECOGNIZED,
    required T Function() orElse,
  }) =>
      {
        MatrixError.M_UNKNOWN: M_UNKNOWN,
        MatrixError.M_UNKNOWN_TOKEN: M_UNKNOWN_TOKEN,
        MatrixError.M_NOT_FOUND: M_NOT_FOUND,
        MatrixError.M_FORBIDDEN: M_FORBIDDEN,
        MatrixError.M_LIMIT_EXCEEDED: M_LIMIT_EXCEEDED,
        MatrixError.M_USER_IN_USE: M_USER_IN_USE,
        MatrixError.M_THREEPID_IN_USE: M_THREEPID_IN_USE,
        MatrixError.M_THREEPID_DENIED: M_THREEPID_DENIED,
        MatrixError.M_THREEPID_NOT_FOUND: M_THREEPID_NOT_FOUND,
        MatrixError.M_THREEPID_AUTH_FAILED: M_THREEPID_AUTH_FAILED,
        MatrixError.M_TOO_LARGE: M_TOO_LARGE,
        MatrixError.M_MISSING_PARAM: M_MISSING_PARAM,
        MatrixError.M_UNSUPPORTED_ROOM_VERSION: M_UNSUPPORTED_ROOM_VERSION,
        MatrixError.M_UNRECOGNIZED: M_UNRECOGNIZED,
      }[this]
          ?.call() ??
      orElse();
}
