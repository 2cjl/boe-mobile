// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Plan _$PlanFromJson(Map<String, dynamic> json) => Plan(
      json['id'] as int,
      json['startDate'] as String,
      json['endDate'] as String,
      (json['playPeriods'] as List<dynamic>)
          .map((e) => PlayPeriod.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PlanToJson(Plan instance) => <String, dynamic>{
      'id': instance.id,
      'startDate': instance.startDate,
      'endDate': instance.endDate,
      'playPeriods': instance.playPeriods,
    };

PlayPeriod _$PlayPeriodFromJson(Map<String, dynamic> json) => PlayPeriod(
      json['startTime'] as String,
      json['endTime'] as String,
      json['loopMode'] as String,
      json['html'] as String,
    );

Map<String, dynamic> _$PlayPeriodToJson(PlayPeriod instance) =>
    <String, dynamic>{
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'loopMode': instance.loopMode,
      'html': instance.html,
    };
