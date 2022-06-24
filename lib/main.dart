import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:boe_mobile/plan.dart';
import 'package:boe_mobile/plan_cron.dart';
import 'package:boe_mobile/utils.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mac_address/mac_address.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter/material.dart';
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
  Map<int, PlanCron> planCronMap = {};

  @override
  void initState() {
    super.initState();
    // 获取设备信息
    getDeviceInfo();
    //TODO websocket 连接获取任务列表
    List<Plan> plans =
        (json.decode(jsonString) as List).map((e) => Plan.fromJson(e)).toList();
    for (var plan in plans) {
      addCron(plan);
    }
  }

  Future<void> getDeviceInfo() async {
    try {
      final Map<Object?, Object?> result = await platform.invokeMethod('getDeivceInfo');
      print('device info: $result');
    } on PlatformException catch (e) {
      print("Failed to get device info: '${e.message}'");
    }

    // 经纬度
    Geolocator
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.best, forceAndroidLocationManager: true)
        .then((Position position) {
      print('lat: ${position.latitude}, lng: ${position.longitude}');
    }).catchError((e) {
      print(e);
    });
  }

  addCron(Plan plan) {
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
          setState(() {
            htmlData = playPeriod.html;
          });
        });
        String endTime =
            generateCronTime(playPeriod.endTime, playPeriod.loopMode);
        planCron.add(endTime, () {
          print('[${playPeriod.endTime}]plan ${plan.id} stop time: stop');
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
        child: Text(htmlData == '' ? 'Welcome to BOE' : htmlData),
      ),
    ));
  }

  @override
  void dispose() {
    planCronMap.forEach((key, value) {value.close();});
    super.dispose();
  }
}
