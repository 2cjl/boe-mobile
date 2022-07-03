import 'dart:convert';
import 'dart:typed_data';

// 2022-06-24 - 2022-06-26
// 08:00:00 - 20:00:00
// 每天 00 00 08 * * *
// 每周 00 00 08 * * 1,3,5
// 每月 00 00 08 1,3,5 * *
String generateCronTime(String time, String mode) {
  String cStr = '';
  List<String> timeStrs = time.split(':');
  Map<String, dynamic> modeMap = json.decode(mode);
  // 1 秒 2 分 3 时
  cStr += '${timeStrs[2]} ${timeStrs[1]} ${timeStrs[0]}';
  // 4 日 5 月
  cStr +=
      ' ${modeMap['mode'] == '每月' ? (modeMap["times"] as List).map((i) => i.toString()).join(",") : '*'} *';
  // 6 星期 1-7
  cStr +=
      ' ${modeMap['mode'] == '每周' ? (modeMap["times"] as List).map((i) => i.toString()).join(",") : '*'}';
  return cStr;
}

// 开始 00 00 00 24 06 *
// 结束 00 00 00 26 06 *
String generateCronDate(String date) {
  List<String> strs = date.split('-');
  return '00 00 00 ${strs[2]} ${strs[1]} *';
}

bool isBetweenTime(String begin, String end, String mode) {
  List<int> bStrs = begin.split(':').map((e) => int.parse(e)).toList();
  List<int> eStrs = end.split(':').map((e) => int.parse(e)).toList();
  DateTime now = DateTime.now();
  DateTime bTime = DateTime(now.year, now.month, now.day, bStrs[0], bStrs[1], bStrs[2]);
  DateTime eTime = DateTime(now.year, now.month, now.day, eStrs[0], eStrs[1], eStrs[2]);
  if (now.isBefore(bTime) || now.isAfter(eTime)) {
    return false;
  }
  Map<String, dynamic> modeMap = json.decode(mode);
  print('${now.day} ${now.weekday}');
  if (modeMap['mode'] == '每月') {
    if (!(modeMap["times"] as List).contains(now.day)) return false;
  } else if (modeMap['mode'] == '每周') {
    if (!(modeMap["times"] as List).contains(now.weekday)) return false;
  }
  return true;
}

String uint8ListTob64(Uint8List uint8list) {
  String base64String = base64Encode(uint8list);
  String header = "data:image/png;base64,";
  return header + base64String;
}