import 'package:json_annotation/json_annotation.dart';

part 'plan.g.dart';

@JsonSerializable()
class Plan {
  int id;
  String startDate;
  String endDate;
  List<PlayPeriod> playPeriods;

  Plan(this.id, this.startDate, this.endDate, this.playPeriods);
  factory Plan.fromJson(Map<String, dynamic> json) => _$PlanFromJson(json);
  Map<String, dynamic> toJson() => _$PlanToJson(this);

  @override
  String toString() {
    return 'Plan{startTime: $startDate, endTime: $endDate, playPeriods: $playPeriods}';
  }
}

@JsonSerializable()
class PlayPeriod {
  String startTime;
  String endTime;
  String loopMode;
  String html;

  PlayPeriod(this.startTime, this.endTime, this.loopMode, this.html);
  factory PlayPeriod.fromJson(Map<String, dynamic> json) => _$PlayPeriodFromJson(json);
  Map<String, dynamic> toJson() => _$PlayPeriodToJson(this);

  @override
  String toString() {
    return 'PlayPeriod{startTime: $startTime, endTime: $endTime, loopMode: $loopMode, html: $html}';
  }
}

