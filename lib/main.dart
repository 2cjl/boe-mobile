import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:boe_mobile/plan.dart';
import 'package:boe_mobile/plan_cron.dart';
import 'package:boe_mobile/utils.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';

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

String welcomeHtml = r'''
<!DOCTYPE html>
<html lang="en">
<body>
<div id="welcome" style="height: 100vh; width: 100%; display:flex; justify-content:center; align-items:center;">
  <h1 style="font-size: 100px">Welcome to BOE!</h1>
</div>
</body>
</html>
''';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('tclx.xyz/info');
  GlobalKey rootWidgetKey = GlobalKey();
  InAppWebViewController? controller;
  Map<int, PlanCron> planCronMap = {};
  WebSocketChannel? channel;
  Timer? heartBeat; // 心跳定时器
  Timer? reconnectTimer; // 重连定时器
  final heartTimes = 3000; // 心跳间隔
  num planIdNow = 0; // 0 是没有计划执行

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays([]); // 初始化时隐藏
  }

  /// 连接回调
  sayHello() async {
    try {
      final String mac = await platform.invokeMethod('getMacAddress');
      sendHandle(<String, dynamic>{'type': 'hello', 'mac': mac});
    } on PlatformException catch (e) {
      print('Failed to get mac address: ${e.message}');
    }
  }

  initHeartBeat() {
    heartBeat = Timer.periodic(Duration(milliseconds: 5000), (timer) async {
      try {
        // print('ping');
        final int runningTime = await platform.invokeMethod('getRunningTime');
        sendHandle(<String, dynamic>{
          'type': 'ping',
          'runningTime': runningTime,
          'planId': planIdNow
        });
      } on PlatformException catch (e) {
        print('Failed to get running time: ${e.message}');
      }
    });
  }

  getDeviceInfo() async {
    Map<String, dynamic> info = {};
    try {
      final Map<Object?, Object?> result =
          await platform.invokeMethod('getDeivceInfo');
      info.addAll(result.cast<String, dynamic>()); // convert map type
      // mac
      final String mac = await platform.invokeMethod('getMacAddress');
      info['mac'] = mac;
    } on PlatformException catch (e) {
      print('Failed to get device info: ${e.message}');
    }

    // 经纬度
    Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            forceAndroidLocationManager: true)
        .then((Position position) {
      info['latitude'] = position.latitude;
      info['longitude'] = position.longitude;
      print('info $info');
      sendHandle(<String, dynamic>{'type': 'deviceInfo', 'info': info});
    }).catchError((e) {
      print('Failed to get position: ${e.message}');
      sendHandle(<String, dynamic>{'type': 'deviceInfo', 'info': info});
    });
  }

  addCron(Plan plan) {
    if (planCronMap.containsKey(plan.id)) {
      if (planIdNow == plan.id) {
        planIdNow = 0;
        controller?.loadData(data: welcomeHtml);
      }
      planCronMap[plan.id]?.close();
      planCronMap.remove(plan.id);
    }
    if (DateTime.now().isAfter(DateTime.parse(plan.endDate))) return;
    PlanCron planCron = PlanCron(plan.id);

    // 创建时间段计时器
    periodCron() {
      for (var playPeriod in plan.playPeriods) {
        if (isBetweenTime(
            playPeriod.startTime, playPeriod.endTime, playPeriod.loopMode)) {
          controller?.loadData(data: playPeriod.html);
        }
        String startTime =
            generateCronTime(playPeriod.startTime, playPeriod.loopMode);
        planCron.add(startTime, () {
          print(
              '[${playPeriod.startTime}]plan ${plan.id} start time: ${playPeriod.html}');
          planIdNow = plan.id;
          controller?.loadData(data: playPeriod.html);
        });
        String endTime =
            generateCronTime(playPeriod.endTime, playPeriod.loopMode);
        planCron.add(endTime, () {
          print('[${playPeriod.endTime}]plan ${plan.id} stop time: stop');
          planIdNow = 0;
          controller?.loadData(data: welcomeHtml);
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
      if (planIdNow == plan.id) {
        planIdNow = 0;
        controller?.loadData(data: welcomeHtml);
      }
      planCron.close();
      planCronMap.remove(plan.id);
    });
    planCronMap[plan.id] = planCron;
  }

  /// ws 相关
  listenHandle() {
    channel?.stream.listen((message) {
      if (message == 'null') return;
      // print('receive: $message');
      Map<String, dynamic> msgMap = json.decode(message);
      switch (msgMap['type']) {
        case 'planList':
          // List<Plan> plans = List<Plan>.from(
          //     msgMap['plan']); // avoid error: type 'List<dynamic>' is not a subtype of type 'String'type of type 'String'
          List<Plan> plans = [];
          for (var j = 0; j < (msgMap['plan'] as List).length; j++) {
            Map<String, dynamic> b = (msgMap['plan'] as List)[j];
            Plan p = Plan(
                b['id'],
                b['startDate'],
                b['endDate'],
                b['mode'],
                (b['playPeriods'] as List)
                    .map((i) => PlayPeriod.fromJson(i))
                    .toList());
            plans.add(p);
          }
          // plans =
          //     (msgMap['plan'] as List).map((i) => Plan.fromJson(i)).toList();

          for (var plan in plans) {
            addCron(plan);
          }
          break;
        case 'deviceInfo':
          getDeviceInfo();
          break;
        case 'pong':
          // print('pong');
          break;
        case 'hi':
          print('hello succeed');
          initHeartBeat();
          break;
        case 'deletePlan':
          var delPlanMap = json.decode(message);
          for (var id in (delPlanMap['planIds'] as List)) {
            if (id == planIdNow) {
              planIdNow = 0;
              controller?.loadData(data: welcomeHtml);
            }
            planCronMap[id]?.close();
            planCronMap.remove(id);
          }
          break;
        case 'screenshot':
          getScreenshot();
          break;
        case 'brightness':
          Map<String, dynamic> msgMap = json.decode(message);
          setBrightness(msgMap['data'] as double);
          break;
        default:
          print('not support type');
      }
    }, onDone: webSocketOnDone);
  }

  sendHandle(Map<String, dynamic> data) {
    channel?.sink.add(json.encode(data));
  }

  // ws 连接
  openSocket() {
    if (channel == null) channel?.sink.close();
    channel = WebSocketChannel.connect(
      Uri.parse('ws://boe.vinf.top:8081/'),
    );
    print('connect succeed');
    // 连接成功，重置重连计数器
    reconnectTimer?.cancel();
    listenHandle();
    sayHello();
  }

  // 重连机制
  reconnect() {
    reconnectTimer =
        Timer.periodic(Duration(milliseconds: heartTimes), (timer) {
      openSocket();
    });
  }

  // ws 关闭连接回调
  webSocketOnDone() {
    print('ws closed, try to reconnect');
    reconnect();
  }

  setBrightness(double brightness) async {
    print('brightness $brightness');
    try {
      await ScreenBrightnessPlatform.instance.setScreenBrightness(brightness);
    } catch (e) {
      debugPrint(e.toString());
      throw 'Failed to set brightness';
    }
  }

  resetBrightness() async {
    try {
      await ScreenBrightnessPlatform.instance.resetScreenBrightness();
    } catch (e) {
      debugPrint(e.toString());
      throw 'Failed to reset brightness';
    }
  }

  // screenshot without webview
  captureWidget() async {
    final boundary = rootWidgetKey.currentContext?.findRenderObject();
    if (boundary != null && boundary is RenderRepaintBoundary) {
      final image = await boundary.toImage();
      ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData != null) {
        return byteData;
      }
    }
  }

  getScreenshot() async {
    Uint8List? screenshotBytes = await controller?.takeScreenshot();
    if (screenshotBytes != null) {
      sendHandle(<String, dynamic>{
        'type': 'screenshot',
        'data': uint8ListTob64(screenshotBytes)
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 强制横屏
    if (MediaQuery.of(context).size.width <
        MediaQuery.of(context).size.height) {
      print('to horizontal screen');
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }

    return RepaintBoundary(
        key: rootWidgetKey,
        child: Scaffold(
            body: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              child: InAppWebView(
                onWebViewCreated: (InAppWebViewController webViewController) {
                  controller = webViewController;
                  controller?.loadData(data: welcomeHtml);
                  openSocket(); // 保证 controller 不为 null
                },
              ),
            ),
          ],
        )));
  }

  @override
  void dispose() {
    planCronMap.forEach((key, value) {
      value.close();
    });
    channel?.sink.close();
    heartBeat?.cancel();
    reconnectTimer?.cancel();
    resetBrightness();
    SystemChrome.setEnabledSystemUIOverlays(
        SystemUiOverlay.values); // 页面关闭时恢复正常设置
    super.dispose();
  }
}
