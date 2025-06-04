// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'network_logs_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$NetworkLogsState {
  List<NetworkLog> get logs => throw _privateConstructorUsedError;
  List<NetworkLog> get filteredLogs => throw _privateConstructorUsedError;
  NetworkLogFilter get filter => throw _privateConstructorUsedError;

  /// Create a copy of NetworkLogsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NetworkLogsStateCopyWith<NetworkLogsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NetworkLogsStateCopyWith<$Res> {
  factory $NetworkLogsStateCopyWith(
          NetworkLogsState value, $Res Function(NetworkLogsState) then) =
      _$NetworkLogsStateCopyWithImpl<$Res, NetworkLogsState>;
  @useResult
  $Res call(
      {List<NetworkLog> logs,
      List<NetworkLog> filteredLogs,
      NetworkLogFilter filter});

  $NetworkLogFilterCopyWith<$Res> get filter;
}

/// @nodoc
class _$NetworkLogsStateCopyWithImpl<$Res, $Val extends NetworkLogsState>
    implements $NetworkLogsStateCopyWith<$Res> {
  _$NetworkLogsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NetworkLogsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? logs = null,
    Object? filteredLogs = null,
    Object? filter = null,
  }) {
    return _then(_value.copyWith(
      logs: null == logs
          ? _value.logs
          : logs // ignore: cast_nullable_to_non_nullable
              as List<NetworkLog>,
      filteredLogs: null == filteredLogs
          ? _value.filteredLogs
          : filteredLogs // ignore: cast_nullable_to_non_nullable
              as List<NetworkLog>,
      filter: null == filter
          ? _value.filter
          : filter // ignore: cast_nullable_to_non_nullable
              as NetworkLogFilter,
    ) as $Val);
  }

  /// Create a copy of NetworkLogsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NetworkLogFilterCopyWith<$Res> get filter {
    return $NetworkLogFilterCopyWith<$Res>(_value.filter, (value) {
      return _then(_value.copyWith(filter: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$NetworkLogsStateImplCopyWith<$Res>
    implements $NetworkLogsStateCopyWith<$Res> {
  factory _$$NetworkLogsStateImplCopyWith(_$NetworkLogsStateImpl value,
          $Res Function(_$NetworkLogsStateImpl) then) =
      __$$NetworkLogsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<NetworkLog> logs,
      List<NetworkLog> filteredLogs,
      NetworkLogFilter filter});

  @override
  $NetworkLogFilterCopyWith<$Res> get filter;
}

/// @nodoc
class __$$NetworkLogsStateImplCopyWithImpl<$Res>
    extends _$NetworkLogsStateCopyWithImpl<$Res, _$NetworkLogsStateImpl>
    implements _$$NetworkLogsStateImplCopyWith<$Res> {
  __$$NetworkLogsStateImplCopyWithImpl(_$NetworkLogsStateImpl _value,
      $Res Function(_$NetworkLogsStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of NetworkLogsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? logs = null,
    Object? filteredLogs = null,
    Object? filter = null,
  }) {
    return _then(_$NetworkLogsStateImpl(
      logs: null == logs
          ? _value._logs
          : logs // ignore: cast_nullable_to_non_nullable
              as List<NetworkLog>,
      filteredLogs: null == filteredLogs
          ? _value._filteredLogs
          : filteredLogs // ignore: cast_nullable_to_non_nullable
              as List<NetworkLog>,
      filter: null == filter
          ? _value.filter
          : filter // ignore: cast_nullable_to_non_nullable
              as NetworkLogFilter,
    ));
  }
}

/// @nodoc

class _$NetworkLogsStateImpl implements _NetworkLogsState {
  const _$NetworkLogsStateImpl(
      {final List<NetworkLog> logs = const [],
      final List<NetworkLog> filteredLogs = const [],
      this.filter = const NetworkLogFilter()})
      : _logs = logs,
        _filteredLogs = filteredLogs;

  final List<NetworkLog> _logs;
  @override
  @JsonKey()
  List<NetworkLog> get logs {
    if (_logs is EqualUnmodifiableListView) return _logs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_logs);
  }

  final List<NetworkLog> _filteredLogs;
  @override
  @JsonKey()
  List<NetworkLog> get filteredLogs {
    if (_filteredLogs is EqualUnmodifiableListView) return _filteredLogs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_filteredLogs);
  }

  @override
  @JsonKey()
  final NetworkLogFilter filter;

  @override
  String toString() {
    return 'NetworkLogsState(logs: $logs, filteredLogs: $filteredLogs, filter: $filter)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkLogsStateImpl &&
            const DeepCollectionEquality().equals(other._logs, _logs) &&
            const DeepCollectionEquality()
                .equals(other._filteredLogs, _filteredLogs) &&
            (identical(other.filter, filter) || other.filter == filter));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_logs),
      const DeepCollectionEquality().hash(_filteredLogs),
      filter);

  /// Create a copy of NetworkLogsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NetworkLogsStateImplCopyWith<_$NetworkLogsStateImpl> get copyWith =>
      __$$NetworkLogsStateImplCopyWithImpl<_$NetworkLogsStateImpl>(
          this, _$identity);
}

abstract class _NetworkLogsState implements NetworkLogsState {
  const factory _NetworkLogsState(
      {final List<NetworkLog> logs,
      final List<NetworkLog> filteredLogs,
      final NetworkLogFilter filter}) = _$NetworkLogsStateImpl;

  @override
  List<NetworkLog> get logs;
  @override
  List<NetworkLog> get filteredLogs;
  @override
  NetworkLogFilter get filter;

  /// Create a copy of NetworkLogsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NetworkLogsStateImplCopyWith<_$NetworkLogsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
