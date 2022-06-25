import 'dart:convert';
import 'dart:async';

import 'package:boe_mobile/plan.dart';
import 'package:boe_mobile/plan_cron.dart';
import 'package:boe_mobile/utils.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

String htmlData = r'''
<!DOCTYPE html>
<html lang="en">
<body>
<img id="img" style="height: 100vh; width: 100%; object-fit: scale-down">
<script>
    let imgs = ['https://s3.bmp.ovh/imgs/2022/06/24/415d5ef060f6b058.jpeg', 'https://s3.bmp.ovh/imgs/2022/06/24/50dedbe0da3b01f5.jpeg']
    let obj = document.getElementById("img");
    let i = 0;
    let runThis = () => {
        obj.src = imgs[i++ % 2];
    }
    runThis()
    setInterval(runThis, 3000)
</script>
</body>
</html>
''';
String jsonString = '''
    [
      {
        "id": 1,
        "startDate": "2022-06-24", 
        "endDate": "2022-06-26",
        "playPeriods": [
          {
            "startTime": "19:17:00", 
            "endTime": "19:17:10",
            "loopMode": "{\\"mode\\":\\"每周\\",\\"times\\":[1,3,5]}",
            "html": "html_1"
          }
        ]
      },
      {
        "id": 2,
        "startDate": "2022-07-10", 
        "endDate": "2022-07-26",
        "playPeriods": [
          {
            "startTime": "08:00:00", 
            "endTime": "21:00:00",
            "loopMode": "{\\"mode\\":\\"每周\\"}",
            "html": "html_2"
          }
        ]
      }
    ]
    ''';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('tclx.xyz/info');
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://47.97.9.122:8080/ws'),
  );
  late Timer heartBeat;
  Map<int, PlanCron> planCronMap = {};
  int planIdNow = 0;  // 0 是没有计划执行

  @override
  void initState() {
    super.initState();
    listenHandle();
    sayHello();
    initHeartBeat();
    syncPlan();
  }

  void sayHello() async {
    try {
      final String mac = await platform.invokeMethod('getMacAddress');
      sendHandle(<String, dynamic>{"type": "hello", "mac": mac});
    } on PlatformException catch (e) {
      print("Failed to get device info: '${e.message}'");
    }
  }

  void initHeartBeat() {
    heartBeat =
    Timer.periodic(const Duration(milliseconds: 5000), (timer) async {
      try {
        // print('ping');
        final int runningTime = await platform.invokeMethod('getRunningTime');
        sendHandle(<String, dynamic>{"type": "ping", "runningTime": runningTime, "planId": planIdNow});
      } on PlatformException catch (e) {
        print("Failed to get device info: '${e.message}'");
      }
    });
  }

  void syncPlan() {
    sendHandle(<String, dynamic>{"type": "sync_plan"});
  }

  void listenHandle() {
    channel.stream.listen((message) {
      Map<String, dynamic> msgMap = json.decode(message);
      switch (msgMap["type"]) {
        case "plan_list":
          List<Plan> plans = (json.decode(msgMap["plan"]) as List)
              .map((e) => Plan.fromJson(e))
              .toList();
          for (var plan in plans) {
            addCron(plan);
          }
          break;
        case "device_info":
          getDeviceInfo();
          break;
        default:
          print('message: $message');
          print('not support type');
      }
    });
  }

  void sendHandle(Map<String, dynamic> data) {
    channel.sink.add(json.encode(data));
  }

  Future<void> getDeviceInfo() async {
    Map<String, dynamic> info = {};
    try {
      final Map<Object?, Object?> result =
          await platform.invokeMethod('getDeivceInfo');
      info.addAll(result.cast<String, dynamic>()); // convert map type
      // mac
      final String mac = await platform.invokeMethod('getMacAddress');
    } on PlatformException catch (e) {
      print("Failed to get device info: '${e.message}'");
    }

    // 经纬度
    Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            forceAndroidLocationManager: true)
        .then((Position position) {
      info['latitude'] = position.latitude;
      info['longitude'] = position.longitude;
    }).catchError((e) {
      print(e);
    });

    sendHandle(<String, dynamic>{"type": "device_info", "info": info});
  }

  void addCron(Plan plan) {
    if (DateTime.now().isAfter(DateTime.parse(plan.endDate))) return;
    PlanCron planCron = PlanCron(plan.id);

    // 创建时间段计时器
    periodCron() {
      for (var playPeriod in plan.playPeriods) {
        if (isBetweenTime(playPeriod.startTime, playPeriod.endTime)) {
          htmlData = playPeriod.html;
        }
        String startTime =
            generateCronTime(playPeriod.startTime, playPeriod.loopMode);
        planCron.add(startTime, () {
          print(
              '[${playPeriod.startTime}]plan ${plan.id} start time: ${playPeriod.html}');
          planIdNow = plan.id;
          setState(() {
            htmlData = playPeriod.html;
          });
        });
        String endTime =
            generateCronTime(playPeriod.endTime, playPeriod.loopMode);
        planCron.add(endTime, () {
          print('[${playPeriod.endTime}]plan ${plan.id} stop time: stop');
          planIdNow = 0;
          setState(() {
            htmlData = '';
          });
        });
      }
    }

    // 判断是否计划已开始
    if (DateTime.now().isBefore(DateTime.parse(plan.startDate))) {
      // 开始时间
      planCron.add(generateCronDate(plan.startDate), () {
        print(
            '[${generateCronDate(plan.startDate)}]plan ${plan.id} begin date: begin');
        // 创建所有时间段定时器
        periodCron();
      });
    } else {
      print('plan ${plan.id} has begun');
      periodCron();
    }

    // 把所有 cron 删除
    planCron.add(generateCronDate(plan.endDate), () {
      print('[${generateCronDate(plan.endDate)}]plan ${plan.id} end date: end');
      planIdNow = 0;
      setState(() {
        htmlData = '';
      });
      planCron.close();
      planCronMap.remove(plan.id);
    });
    planCronMap[plan.id] = planCron;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        // child: WebView(
        //   javascriptMode: JavascriptMode.unrestricted,
        //   onWebViewCreated: (WebViewController controller) {
        //     controller.loadHtmlString(htmlData);
        //   },
        // ),
        child: Text(htmlData.isEmpty ? 'Welcome to BOE' : htmlData),
      ),
    ));
  }

  @override
  void dispose() {
    planCronMap.forEach((key, value) {
      value.close();
    });
    channel.sink.close();
    heartBeat.cancel();
    super.dispose();
  }
}
