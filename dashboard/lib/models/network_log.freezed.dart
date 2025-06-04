// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'network_log.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NetworkLog _$NetworkLogFromJson(Map<String, dynamic> json) {
  return _NetworkLog.fromJson(json);
}

/// @nodoc
mixin _$NetworkLog {
  String get method => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  int get statusCode => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  String? get requestBody => throw _privateConstructorUsedError;
  String? get responseBody => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Serializes this NetworkLog to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NetworkLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NetworkLogCopyWith<NetworkLog> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NetworkLogCopyWith<$Res> {
  factory $NetworkLogCopyWith(
          NetworkLog value, $Res Function(NetworkLog) then) =
      _$NetworkLogCopyWithImpl<$Res, NetworkLog>;
  @useResult
  $Res call(
      {String method,
      String url,
      int statusCode,
      DateTime timestamp,
      String? requestBody,
      String? responseBody,
      String? error});
}

/// @nodoc
class _$NetworkLogCopyWithImpl<$Res, $Val extends NetworkLog>
    implements $NetworkLogCopyWith<$Res> {
  _$NetworkLogCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NetworkLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? method = null,
    Object? url = null,
    Object? statusCode = null,
    Object? timestamp = null,
    Object? requestBody = freezed,
    Object? responseBody = freezed,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      method: null == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      statusCode: null == statusCode
          ? _value.statusCode
          : statusCode // ignore: cast_nullable_to_non_nullable
              as int,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      requestBody: freezed == requestBody
          ? _value.requestBody
          : requestBody // ignore: cast_nullable_to_non_nullable
              as String?,
      responseBody: freezed == responseBody
          ? _value.responseBody
          : responseBody // ignore: cast_nullable_to_non_nullable
              as String?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NetworkLogImplCopyWith<$Res>
    implements $NetworkLogCopyWith<$Res> {
  factory _$$NetworkLogImplCopyWith(
          _$NetworkLogImpl value, $Res Function(_$NetworkLogImpl) then) =
      __$$NetworkLogImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String method,
      String url,
      int statusCode,
      DateTime timestamp,
      String? requestBody,
      String? responseBody,
      String? error});
}

/// @nodoc
class __$$NetworkLogImplCopyWithImpl<$Res>
    extends _$NetworkLogCopyWithImpl<$Res, _$NetworkLogImpl>
    implements _$$NetworkLogImplCopyWith<$Res> {
  __$$NetworkLogImplCopyWithImpl(
      _$NetworkLogImpl _value, $Res Function(_$NetworkLogImpl) _then)
      : super(_value, _then);

  /// Create a copy of NetworkLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? method = null,
    Object? url = null,
    Object? statusCode = null,
    Object? timestamp = null,
    Object? requestBody = freezed,
    Object? responseBody = freezed,
    Object? error = freezed,
  }) {
    return _then(_$NetworkLogImpl(
      method: null == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      statusCode: null == statusCode
          ? _value.statusCode
          : statusCode // ignore: cast_nullable_to_non_nullable
              as int,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      requestBody: freezed == requestBody
          ? _value.requestBody
          : requestBody // ignore: cast_nullable_to_non_nullable
              as String?,
      responseBody: freezed == responseBody
          ? _value.responseBody
          : responseBody // ignore: cast_nullable_to_non_nullable
              as String?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NetworkLogImpl implements _NetworkLog {
  const _$NetworkLogImpl(
      {required this.method,
      required this.url,
      required this.statusCode,
      required this.timestamp,
      this.requestBody,
      this.responseBody,
      this.error});

  factory _$NetworkLogImpl.fromJson(Map<String, dynamic> json) =>
      _$$NetworkLogImplFromJson(json);

  @override
  final String method;
  @override
  final String url;
  @override
  final int statusCode;
  @override
  final DateTime timestamp;
  @override
  final String? requestBody;
  @override
  final String? responseBody;
  @override
  final String? error;

  @override
  String toString() {
    return 'NetworkLog(method: $method, url: $url, statusCode: $statusCode, timestamp: $timestamp, requestBody: $requestBody, responseBody: $responseBody, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkLogImpl &&
            (identical(other.method, method) || other.method == method) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.statusCode, statusCode) ||
                other.statusCode == statusCode) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.requestBody, requestBody) ||
                other.requestBody == requestBody) &&
            (identical(other.responseBody, responseBody) ||
                other.responseBody == responseBody) &&
            (identical(other.error, error) || other.error == error));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, method, url, statusCode,
      timestamp, requestBody, responseBody, error);

  /// Create a copy of NetworkLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NetworkLogImplCopyWith<_$NetworkLogImpl> get copyWith =>
      __$$NetworkLogImplCopyWithImpl<_$NetworkLogImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NetworkLogImplToJson(
      this,
    );
  }
}

abstract class _NetworkLog implements NetworkLog {
  const factory _NetworkLog(
      {required final String method,
      required final String url,
      required final int statusCode,
      required final DateTime timestamp,
      final String? requestBody,
      final String? responseBody,
      final String? error}) = _$NetworkLogImpl;

  factory _NetworkLog.fromJson(Map<String, dynamic> json) =
      _$NetworkLogImpl.fromJson;

  @override
  String get method;
  @override
  String get url;
  @override
  int get statusCode;
  @override
  DateTime get timestamp;
  @override
  String? get requestBody;
  @override
  String? get responseBody;
  @override
  String? get error;

  /// Create a copy of NetworkLog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NetworkLogImplCopyWith<_$NetworkLogImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$NetworkLogFilter {
  String get searchTerm => throw _privateConstructorUsedError;
  String get method => throw _privateConstructorUsedError;
  String get statusCode => throw _privateConstructorUsedError;

  /// Create a copy of NetworkLogFilter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NetworkLogFilterCopyWith<NetworkLogFilter> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NetworkLogFilterCopyWith<$Res> {
  factory $NetworkLogFilterCopyWith(
          NetworkLogFilter value, $Res Function(NetworkLogFilter) then) =
      _$NetworkLogFilterCopyWithImpl<$Res, NetworkLogFilter>;
  @useResult
  $Res call({String searchTerm, String method, String statusCode});
}

/// @nodoc
class _$NetworkLogFilterCopyWithImpl<$Res, $Val extends NetworkLogFilter>
    implements $NetworkLogFilterCopyWith<$Res> {
  _$NetworkLogFilterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NetworkLogFilter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? searchTerm = null,
    Object? method = null,
    Object? statusCode = null,
  }) {
    return _then(_value.copyWith(
      searchTerm: null == searchTerm
          ? _value.searchTerm
          : searchTerm // ignore: cast_nullable_to_non_nullable
              as String,
      method: null == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
      statusCode: null == statusCode
          ? _value.statusCode
          : statusCode // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NetworkLogFilterImplCopyWith<$Res>
    implements $NetworkLogFilterCopyWith<$Res> {
  factory _$$NetworkLogFilterImplCopyWith(_$NetworkLogFilterImpl value,
          $Res Function(_$NetworkLogFilterImpl) then) =
      __$$NetworkLogFilterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String searchTerm, String method, String statusCode});
}

/// @nodoc
class __$$NetworkLogFilterImplCopyWithImpl<$Res>
    extends _$NetworkLogFilterCopyWithImpl<$Res, _$NetworkLogFilterImpl>
    implements _$$NetworkLogFilterImplCopyWith<$Res> {
  __$$NetworkLogFilterImplCopyWithImpl(_$NetworkLogFilterImpl _value,
      $Res Function(_$NetworkLogFilterImpl) _then)
      : super(_value, _then);

  /// Create a copy of NetworkLogFilter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? searchTerm = null,
    Object? method = null,
    Object? statusCode = null,
  }) {
    return _then(_$NetworkLogFilterImpl(
      searchTerm: null == searchTerm
          ? _value.searchTerm
          : searchTerm // ignore: cast_nullable_to_non_nullable
              as String,
      method: null == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
      statusCode: null == statusCode
          ? _value.statusCode
          : statusCode // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$NetworkLogFilterImpl implements _NetworkLogFilter {
  const _$NetworkLogFilterImpl(
      {this.searchTerm = '', this.method = '', this.statusCode = ''});

  @override
  @JsonKey()
  final String searchTerm;
  @override
  @JsonKey()
  final String method;
  @override
  @JsonKey()
  final String statusCode;

  @override
  String toString() {
    return 'NetworkLogFilter(searchTerm: $searchTerm, method: $method, statusCode: $statusCode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkLogFilterImpl &&
            (identical(other.searchTerm, searchTerm) ||
                other.searchTerm == searchTerm) &&
            (identical(other.method, method) || other.method == method) &&
            (identical(other.statusCode, statusCode) ||
                other.statusCode == statusCode));
  }

  @override
  int get hashCode => Object.hash(runtimeType, searchTerm, method, statusCode);

  /// Create a copy of NetworkLogFilter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NetworkLogFilterImplCopyWith<_$NetworkLogFilterImpl> get copyWith =>
      __$$NetworkLogFilterImplCopyWithImpl<_$NetworkLogFilterImpl>(
          this, _$identity);
}

abstract class _NetworkLogFilter implements NetworkLogFilter {
  const factory _NetworkLogFilter(
      {final String searchTerm,
      final String method,
      final String statusCode}) = _$NetworkLogFilterImpl;

  @override
  String get searchTerm;
  @override
  String get method;
  @override
  String get statusCode;

  /// Create a copy of NetworkLogFilter
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NetworkLogFilterImplCopyWith<_$NetworkLogFilterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
