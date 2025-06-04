// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NetworkLogImpl _$$NetworkLogImplFromJson(Map<String, dynamic> json) =>
    _$NetworkLogImpl(
      method: json['method'] as String,
      url: json['url'] as String,
      statusCode: (json['statusCode'] as num).toInt(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      requestBody: json['requestBody'] as String?,
      responseBody: json['responseBody'] as String?,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$$NetworkLogImplToJson(_$NetworkLogImpl instance) =>
    <String, dynamic>{
      'method': instance.method,
      'url': instance.url,
      'statusCode': instance.statusCode,
      'timestamp': instance.timestamp.toIso8601String(),
      'requestBody': instance.requestBody,
      'responseBody': instance.responseBody,
      'error': instance.error,
    };
