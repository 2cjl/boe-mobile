import 'package:cron/cron.dart';

class PlanCron {
  int planId;
  List<Cron> crons = [];


  PlanCron(this.planId);

  void close() async {
    for (var element in crons) {
      await element.close();
    }
  }

  void add(String cStr, Function() f) {
    final cron = Cron();
    cron.schedule(Schedule.parse(cStr), f);
    crons.add(cron);
  }
}