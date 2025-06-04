// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'network_logs_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$NetworkLogsEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initialized,
    required TResult Function(List<dynamic> logs) received,
    required TResult Function(NetworkLogFilter filter) filtered,
    required TResult Function() cleared,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initialized,
    TResult? Function(List<dynamic> logs)? received,
    TResult? Function(NetworkLogFilter filter)? filtered,
    TResult? Function()? cleared,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initialized,
    TResult Function(List<dynamic> logs)? received,
    TResult Function(NetworkLogFilter filter)? filtered,
    TResult Function()? cleared,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkLogsInitialized value) initialized,
    required TResult Function(NetworkLogsReceived value) received,
    required TResult Function(NetworkLogsFiltered value) filtered,
    required TResult Function(NetworkLogsCleared value) cleared,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkLogsInitialized value)? initialized,
    TResult? Function(NetworkLogsReceived value)? received,
    TResult? Function(NetworkLogsFiltered value)? filtered,
    TResult? Function(NetworkLogsCleared value)? cleared,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkLogsInitialized value)? initialized,
    TResult Function(NetworkLogsReceived value)? received,
    TResult Function(NetworkLogsFiltered value)? filtered,
    TResult Function(NetworkLogsCleared value)? cleared,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NetworkLogsEventCopyWith<$Res> {
  factory $NetworkLogsEventCopyWith(
          NetworkLogsEvent value, $Res Function(NetworkLogsEvent) then) =
      _$NetworkLogsEventCopyWithImpl<$Res, NetworkLogsEvent>;
}

/// @nodoc
class _$NetworkLogsEventCopyWithImpl<$Res, $Val extends NetworkLogsEvent>
    implements $NetworkLogsEventCopyWith<$Res> {
  _$NetworkLogsEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NetworkLogsEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$NetworkLogsInitializedImplCopyWith<$Res> {
  factory _$$NetworkLogsInitializedImplCopyWith(
          _$NetworkLogsInitializedImpl value,
          $Res Function(_$NetworkLogsInitializedImpl) then) =
      __$$NetworkLogsInitializedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$NetworkLogsInitializedImplCopyWithImpl<$Res>
    extends _$NetworkLogsEventCopyWithImpl<$Res, _$NetworkLogsInitializedImpl>
    implements _$$NetworkLogsInitializedImplCopyWith<$Res> {
  __$$NetworkLogsInitializedImplCopyWithImpl(
      _$NetworkLogsInitializedImpl _value,
      $Res Function(_$NetworkLogsInitializedImpl) _then)
      : super(_value, _then);

  /// Create a copy of NetworkLogsEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$NetworkLogsInitializedImpl implements NetworkLogsInitialized {
  const _$NetworkLogsInitializedImpl();

  @override
  String toString() {
    return 'NetworkLogsEvent.initialized()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkLogsInitializedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initialized,
    required TResult Function(List<dynamic> logs) received,
    required TResult Function(NetworkLogFilter filter) filtered,
    required TResult Function() cleared,
  }) {
    return initialized();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initialized,
    TResult? Function(List<dynamic> logs)? received,
    TResult? Function(NetworkLogFilter filter)? filtered,
    TResult? Function()? cleared,
  }) {
    return initialized?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initialized,
    TResult Function(List<dynamic> logs)? received,
    TResult Function(NetworkLogFilter filter)? filtered,
    TResult Function()? cleared,
    required TResult orElse(),
  }) {
    if (initialized != null) {
      return initialized();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkLogsInitialized value) initialized,
    required TResult Function(NetworkLogsReceived value) received,
    required TResult Function(NetworkLogsFiltered value) filtered,
    required TResult Function(NetworkLogsCleared value) cleared,
  }) {
    return initialized(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkLogsInitialized value)? initialized,
    TResult? Function(NetworkLogsReceived value)? received,
    TResult? Function(NetworkLogsFiltered value)? filtered,
    TResult? Function(NetworkLogsCleared value)? cleared,
  }) {
    return initialized?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkLogsInitialized value)? initialized,
    TResult Function(NetworkLogsReceived value)? received,
    TResult Function(NetworkLogsFiltered value)? filtered,
    TResult Function(NetworkLogsCleared value)? cleared,
    required TResult orElse(),
  }) {
    if (initialized != null) {
      return initialized(this);
    }
    return orElse();
  }
}

abstract class NetworkLogsInitialized implements NetworkLogsEvent {
  const factory NetworkLogsInitialized() = _$NetworkLogsInitializedImpl;
}

/// @nodoc
abstract class _$$NetworkLogsReceivedImplCopyWith<$Res> {
  factory _$$NetworkLogsReceivedImplCopyWith(_$NetworkLogsReceivedImpl value,
          $Res Function(_$NetworkLogsReceivedImpl) then) =
      __$$NetworkLogsReceivedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<dynamic> logs});
}

/// @nodoc
class __$$NetworkLogsReceivedImplCopyWithImpl<$Res>
    extends _$NetworkLogsEventCopyWithImpl<$Res, _$NetworkLogsReceivedImpl>
    implements _$$NetworkLogsReceivedImplCopyWith<$Res> {
  __$$NetworkLogsReceivedImplCopyWithImpl(_$NetworkLogsReceivedImpl _value,
      $Res Function(_$NetworkLogsReceivedImpl) _then)
      : super(_value, _then);

  /// Create a copy of NetworkLogsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? logs = null,
  }) {
    return _then(_$NetworkLogsReceivedImpl(
      null == logs
          ? _value._logs
          : logs // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
    ));
  }
}

/// @nodoc

class _$NetworkLogsReceivedImpl implements NetworkLogsReceived {
  const _$NetworkLogsReceivedImpl(final List<dynamic> logs) : _logs = logs;

  final List<dynamic> _logs;
  @override
  List<dynamic> get logs {
    if (_logs is EqualUnmodifiableListView) return _logs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_logs);
  }

  @override
  String toString() {
    return 'NetworkLogsEvent.received(logs: $logs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkLogsReceivedImpl &&
            const DeepCollectionEquality().equals(other._logs, _logs));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_logs));

  /// Create a copy of NetworkLogsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NetworkLogsReceivedImplCopyWith<_$NetworkLogsReceivedImpl> get copyWith =>
      __$$NetworkLogsReceivedImplCopyWithImpl<_$NetworkLogsReceivedImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initialized,
    required TResult Function(List<dynamic> logs) received,
    required TResult Function(NetworkLogFilter filter) filtered,
    required TResult Function() cleared,
  }) {
    return received(logs);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initialized,
    TResult? Function(List<dynamic> logs)? received,
    TResult? Function(NetworkLogFilter filter)? filtered,
    TResult? Function()? cleared,
  }) {
    return received?.call(logs);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initialized,
    TResult Function(List<dynamic> logs)? received,
    TResult Function(NetworkLogFilter filter)? filtered,
    TResult Function()? cleared,
    required TResult orElse(),
  }) {
    if (received != null) {
      return received(logs);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkLogsInitialized value) initialized,
    required TResult Function(NetworkLogsReceived value) received,
    required TResult Function(NetworkLogsFiltered value) filtered,
    required TResult Function(NetworkLogsCleared value) cleared,
  }) {
    return received(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkLogsInitialized value)? initialized,
    TResult? Function(NetworkLogsReceived value)? received,
    TResult? Function(NetworkLogsFiltered value)? filtered,
    TResult? Function(NetworkLogsCleared value)? cleared,
  }) {
    return received?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkLogsInitialized value)? initialized,
    TResult Function(NetworkLogsReceived value)? received,
    TResult Function(NetworkLogsFiltered value)? filtered,
    TResult Function(NetworkLogsCleared value)? cleared,
    required TResult orElse(),
  }) {
    if (received != null) {
      return received(this);
    }
    return orElse();
  }
}

abstract class NetworkLogsReceived implements NetworkLogsEvent {
  const factory NetworkLogsReceived(final List<dynamic> logs) =
      _$NetworkLogsReceivedImpl;

  List<dynamic> get logs;

  /// Create a copy of NetworkLogsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NetworkLogsReceivedImplCopyWith<_$NetworkLogsReceivedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$NetworkLogsFilteredImplCopyWith<$Res> {
  factory _$$NetworkLogsFilteredImplCopyWith(_$NetworkLogsFilteredImpl value,
          $Res Function(_$NetworkLogsFilteredImpl) then) =
      __$$NetworkLogsFilteredImplCopyWithImpl<$Res>;
  @useResult
  $Res call({NetworkLogFilter filter});

  $NetworkLogFilterCopyWith<$Res> get filter;
}

/// @nodoc
class __$$NetworkLogsFilteredImplCopyWithImpl<$Res>
    extends _$NetworkLogsEventCopyWithImpl<$Res, _$NetworkLogsFilteredImpl>
    implements _$$NetworkLogsFilteredImplCopyWith<$Res> {
  __$$NetworkLogsFilteredImplCopyWithImpl(_$NetworkLogsFilteredImpl _value,
      $Res Function(_$NetworkLogsFilteredImpl) _then)
      : super(_value, _then);

  /// Create a copy of NetworkLogsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? filter = null,
  }) {
    return _then(_$NetworkLogsFilteredImpl(
      null == filter
          ? _value.filter
          : filter // ignore: cast_nullable_to_non_nullable
              as NetworkLogFilter,
    ));
  }

  /// Create a copy of NetworkLogsEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NetworkLogFilterCopyWith<$Res> get filter {
    return $NetworkLogFilterCopyWith<$Res>(_value.filter, (value) {
      return _then(_value.copyWith(filter: value));
    });
  }
}

/// @nodoc

class _$NetworkLogsFilteredImpl implements NetworkLogsFiltered {
  const _$NetworkLogsFilteredImpl(this.filter);

  @override
  final NetworkLogFilter filter;

  @override
  String toString() {
    return 'NetworkLogsEvent.filtered(filter: $filter)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkLogsFilteredImpl &&
            (identical(other.filter, filter) || other.filter == filter));
  }

  @override
  int get hashCode => Object.hash(runtimeType, filter);

  /// Create a copy of NetworkLogsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NetworkLogsFilteredImplCopyWith<_$NetworkLogsFilteredImpl> get copyWith =>
      __$$NetworkLogsFilteredImplCopyWithImpl<_$NetworkLogsFilteredImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initialized,
    required TResult Function(List<dynamic> logs) received,
    required TResult Function(NetworkLogFilter filter) filtered,
    required TResult Function() cleared,
  }) {
    return filtered(filter);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initialized,
    TResult? Function(List<dynamic> logs)? received,
    TResult? Function(NetworkLogFilter filter)? filtered,
    TResult? Function()? cleared,
  }) {
    return filtered?.call(filter);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initialized,
    TResult Function(List<dynamic> logs)? received,
    TResult Function(NetworkLogFilter filter)? filtered,
    TResult Function()? cleared,
    required TResult orElse(),
  }) {
    if (filtered != null) {
      return filtered(filter);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkLogsInitialized value) initialized,
    required TResult Function(NetworkLogsReceived value) received,
    required TResult Function(NetworkLogsFiltered value) filtered,
    required TResult Function(NetworkLogsCleared value) cleared,
  }) {
    return filtered(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkLogsInitialized value)? initialized,
    TResult? Function(NetworkLogsReceived value)? received,
    TResult? Function(NetworkLogsFiltered value)? filtered,
    TResult? Function(NetworkLogsCleared value)? cleared,
  }) {
    return filtered?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkLogsInitialized value)? initialized,
    TResult Function(NetworkLogsReceived value)? received,
    TResult Function(NetworkLogsFiltered value)? filtered,
    TResult Function(NetworkLogsCleared value)? cleared,
    required TResult orElse(),
  }) {
    if (filtered != null) {
      return filtered(this);
    }
    return orElse();
  }
}

abstract class NetworkLogsFiltered implements NetworkLogsEvent {
  const factory NetworkLogsFiltered(final NetworkLogFilter filter) =
      _$NetworkLogsFilteredImpl;

  NetworkLogFilter get filter;

  /// Create a copy of NetworkLogsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NetworkLogsFilteredImplCopyWith<_$NetworkLogsFilteredImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$NetworkLogsClearedImplCopyWith<$Res> {
  factory _$$NetworkLogsClearedImplCopyWith(_$NetworkLogsClearedImpl value,
          $Res Function(_$NetworkLogsClearedImpl) then) =
      __$$NetworkLogsClearedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$NetworkLogsClearedImplCopyWithImpl<$Res>
    extends _$NetworkLogsEventCopyWithImpl<$Res, _$NetworkLogsClearedImpl>
    implements _$$NetworkLogsClearedImplCopyWith<$Res> {
  __$$NetworkLogsClearedImplCopyWithImpl(_$NetworkLogsClearedImpl _value,
      $Res Function(_$NetworkLogsClearedImpl) _then)
      : super(_value, _then);

  /// Create a copy of NetworkLogsEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$NetworkLogsClearedImpl implements NetworkLogsCleared {
  const _$NetworkLogsClearedImpl();

  @override
  String toString() {
    return 'NetworkLogsEvent.cleared()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$NetworkLogsClearedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() initialized,
    required TResult Function(List<dynamic> logs) received,
    required TResult Function(NetworkLogFilter filter) filtered,
    required TResult Function() cleared,
  }) {
    return cleared();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initialized,
    TResult? Function(List<dynamic> logs)? received,
    TResult? Function(NetworkLogFilter filter)? filtered,
    TResult? Function()? cleared,
  }) {
    return cleared?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initialized,
    TResult Function(List<dynamic> logs)? received,
    TResult Function(NetworkLogFilter filter)? filtered,
    TResult Function()? cleared,
    required TResult orElse(),
  }) {
    if (cleared != null) {
      return cleared();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NetworkLogsInitialized value) initialized,
    required TResult Function(NetworkLogsReceived value) received,
    required TResult Function(NetworkLogsFiltered value) filtered,
    required TResult Function(NetworkLogsCleared value) cleared,
  }) {
    return cleared(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NetworkLogsInitialized value)? initialized,
    TResult? Function(NetworkLogsReceived value)? received,
    TResult? Function(NetworkLogsFiltered value)? filtered,
    TResult? Function(NetworkLogsCleared value)? cleared,
  }) {
    return cleared?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NetworkLogsInitialized value)? initialized,
    TResult Function(NetworkLogsReceived value)? received,
    TResult Function(NetworkLogsFiltered value)? filtered,
    TResult Function(NetworkLogsCleared value)? cleared,
    required TResult orElse(),
  }) {
    if (cleared != null) {
      return cleared(this);
    }
    return orElse();
  }
}

abstract class NetworkLogsCleared implements NetworkLogsEvent {
  const factory NetworkLogsCleared() = _$NetworkLogsClearedImpl;
}
