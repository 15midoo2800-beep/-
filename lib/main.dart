import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'dart:io';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MyApp());

// نظام حماية التراخيص والتحكم عن بُعد
class RasedLicenseManager {
  static const String _secretSalt = "RASED_PRO_2026_SECRET_KEY";
  
  // تم تحديث الرابط هنا ليطابق مستودع الإدارة الصحيح Admin-Rased
  static const String remoteControlJsonUrl = "https://raw.githubusercontent.com/15midoo2800-beep/Admin-Rased/main/clients_control.json";

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? devId = prefs.getString('rased_unique_device_id');
    if (devId == null || devId.isEmpty) {
      final rnd = Random.secure();
      String hex = List.generate(6, (_) => rnd.nextInt(16).toRadixString(16)).join().toUpperCase();
      devId = "RSD-$hex";
      await prefs.setString('rased_unique_device_id', devId);
    }
    return devId;
  }

  static Map<String, dynamic> verifyActivationCode(String code, String myDeviceId) {
    try {
      String clean = code.trim();
      if (!clean.startsWith("ACT-")) return {'valid': false, 'msg': 'صيغة الكود غير صحيحة'};
      String encoded = clean.substring(4);
      while (encoded.length % 4 != 0) {
        encoded += '=';
      }
      String decoded = utf8.decode(base64Url.decode(encoded));
      List<String> parts = decoded.split('|');
      if (parts.length != 3) return {'valid': false, 'msg': 'كود تفعيل تالف'};

      String codeDevice = parts[0];
      String expStr = parts[1];
      String sig = parts[2];

      if (codeDevice != myDeviceId.toUpperCase()) {
        return {'valid': false, 'msg': 'هذا الكود مخصص لهاتف آخر ولا يعمل على جهازك!'};
      }

      String raw = "$codeDevice|$expStr|$_secretSalt";
      int hash = 0;
      for (int i = 0; i < raw.length; i++) {
        hash = ((hash << 5) - hash) + raw.codeUnitAt(i);
        hash &= 0xFFFFFFFF;
      }
      String expectedSig = hash.toRadixString(16).toUpperCase().padLeft(8, '0');
      if (sig != expectedSig) {
        return {'valid': false, 'msg': 'كود التفعيل غير صالح'};
      }

      int year = int.parse(expStr.substring(0, 4));
      int month = int.parse(expStr.substring(4, 6));
      int day = int.parse(expStr.substring(6, 8));
      DateTime expiry = DateTime(year, month, day, 23, 59, 59);

      if (DateTime.now().isAfter(expiry)) {
        return {'valid': false, 'msg': 'انتهت صلاحية هذا الكود'};
      }

      return {'valid': true, 'expiry': expiry.toIso8601String()};
    } catch (_) {
      return {'valid': false, 'msg': 'كود التفعيل غير صالح'};
    }
  }

  // التحقق السحابي من حالة العميل (إيقاف عن بُعد أو تمديد المدة)
  static Future<Map<String, dynamic>> checkRemoteStatus(String myDeviceId, String currentExpiryIso) async {
    try {
      if (remoteControlJsonUrl.contains("YOUR_USERNAME")) {
        DateTime exp = DateTime.parse(currentExpiryIso);
        return {'allowed': DateTime.now().isBefore(exp), 'expiry': currentExpiryIso};
      }

      HttpClient client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse("$remoteControlJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}"));
      final res = await req.close();

      if (res.statusCode == 200) {
        String body = await res.transform(utf8.decoder).join();
        List<dynamic> list = json.decode(body);
        for (var item in list) {
          if (item['deviceId'].toString().toUpperCase() == myDeviceId.toUpperCase()) {
            bool active = item['isActive'] ?? true;
            if (!active) {
              return {'allowed': false, 'reason': 'تم إيقاف اشتراكك من قِبل الإدارة'};
            }
            if (item['expiry'] != null) {
              DateTime remoteExp = DateTime.parse("${item['expiry']}T23:59:59");
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('rased_license_expiry', remoteExp.toIso8601String());
              if (DateTime.now().isAfter(remoteExp)) {
                return {'allowed': false, 'reason': 'انتهت فترة اشتراكك، يرجى التجديد'};
              }
              return {'allowed': true, 'expiry': remoteExp.toIso8601String()};
            }
          }
        }
      }
    } catch (_) {}

    DateTime exp = DateTime.parse(currentExpiryIso);
    if (DateTime.now().isAfter(exp)) {
      return {'allowed': false, 'reason': 'انتهت فترة اشتراكك، يرجى التواصل للتجديد'};
    }
    return {'allowed': true, 'expiry': currentExpiryIso};
  }
}

class AppStrings {
  static bool isAr = true;

  static String get appName => 'RASED';
  static String get checkingTab => isAr ? 'التشييك' : 'Check';
  static String get registrationTab => isAr ? 'التسجيل' : 'Register';
  static String get wantedTab => isAr ? 'المرصودة' : 'Wanted';
  static String get manualSearchTab => isAr ? 'فحص يدوي' : 'Manual';
  static String get settingsTab => isAr ? 'الإعدادات' : 'Settings';

  static String get listeningNow => isAr ? 'يستمع الآن...' : 'Listening now...';
  static String get stopped => isAr ? 'متوقف' : 'Stopped';
  static String get recordsCount => isAr ? 'السجلات:' : 'Records:';
  static String get editPlateHint => isAr ? 'اضغط على اللوحة أو النوع لتعديلهما' : 'Tap plate or type to edit';
  static String get noRecords => isAr ? 'لا توجد سجلات حالياً...' : 'No records yet...';

  static String get notes => isAr ? 'ملاحظات' : 'Notes';
  static String get street => isAr ? 'الشارع' : 'Street';
  static String get district => isAr ? 'الحي' : 'District';
  static String get exportExcel => isAr ? 'تصدير إكسيل (باسم الحي)' : 'Export Excel';
  static String get appendExcel => isAr ? 'استيراد وإكمال شيت' : 'Append Sheet';

  static String get sendWhatsApp => isAr ? 'إرسال للواتساب' : 'Send WhatsApp';
  static String get sendNumber => isAr ? 'رقم الإرسال:' : 'Send Phone:';
  static String get searchBtn => isAr ? 'بحث' : 'Search';
  static String get searchHint => isAr ? 'اكتب حروف أو أرقام السيارة...' : 'Enter plate code or digits...';
  static String get searchEmptyHint => isAr ? 'اكتب كود أو رقم السيارة واضغط "بحث" للفحص الفوري في الشيت' : 'Enter plate and tap "Search" to check against sheet';

  static String get langSetting => isAr ? 'لغة التطبيق / Language' : 'App Language / اللغة';
  static String get gpsSetting => isAr ? 'تفعيل موقع GPS عند الرصد' : 'Enable GPS Tracking';
  static String get gpsSub => isAr ? 'التقاط الإحداثيات تلقائياً وتثبيتها في الشيت' : 'Auto-record coordinates in records & sheet';
  static String get supportSetting => isAr ? 'التواصل مع الدعم وتحديد الاشتراك' : 'Support & Subscription';
  static String get supportSub => isAr ? 'واتساب: 00201155661920' : 'WhatsApp: 00201155661920';
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('ar');

  void setLocale(Locale loc) {
    setState(() {
      _locale = loc;
      AppStrings.isAr = loc.languageCode == 'ar';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B132B),
        primaryColor: const Color(0xFF06D6A0),
      ),
      home: SubscriptionGateScreen(onLanguageChange: setLocale),
    );
  }
}

// شاشة بوابة التفعيل والتحقق من الاشتراك
class SubscriptionGateScreen extends StatefulWidget {
  final Function(Locale) onLanguageChange;
  const SubscriptionGateScreen({super.key, required this.onLanguageChange});

  @override
  State<SubscriptionGateScreen> createState() => _SubscriptionGateScreenState();
}

class _SubscriptionGateScreenState extends State<SubscriptionGateScreen> {
  bool _isChecking = true;
  bool _isActivated = false;
  String _deviceId = '';
  String _errorMessage = '';
  final TextEditingController _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _verifyCurrentLicense();
  }

  Future<void> _verifyCurrentLicense() async {
    setState(() => _isChecking = true);
    _deviceId = await RasedLicenseManager.getOrCreateDeviceId();
    final prefs = await SharedPreferences.getInstance();
    String? savedCode = prefs.getString('rased_license_code');
    String? savedExpiry = prefs.getString('rased_license_expiry');

    if (savedCode != null && savedExpiry != null) {
      var localCheck = RasedLicenseManager.verifyActivationCode(savedCode, _deviceId);
      if (localCheck['valid'] == true) {
        var remoteCheck = await RasedLicenseManager.checkRemoteStatus(_deviceId, savedExpiry);
        if (remoteCheck['allowed'] == true) {
          setState(() {
            _isActivated = true;
            _isChecking = false;
          });
          return;
        } else {
          _errorMessage = remoteCheck['reason'] ?? 'الاشتراك متوقف';
        }
      }
    }

    setState(() {
      _isActivated = false;
      _isChecking = false;
    });
  }

  Future<void> _submitActivationCode() async {
    String input = _codeCtrl.text.trim();
    var res = RasedLicenseManager.verifyActivationCode(input, _deviceId);

    if (res['valid'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rased_license_code', input);
      await prefs.setString('rased_license_expiry', res['expiry']);
      _verifyCurrentLicense();
    } else {
      setState(() => _errorMessage = res['msg'] ?? 'كود خاطئ');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF06D6A0))),
      );
    }

    if (_isActivated) {
      return SheekhaHomeScreen(onLanguageChange: widget.onLanguageChange);
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF06D6A0), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, color: Color(0xFF06D6A0), size: 55),
                  const SizedBox(height: 10),
                  const Text('تفعيل تطبيق RASED', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('انسخ معرف جهازك وأرسله للإدارة للحصول على كود التفعيل الخاص بهاتفك', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFF0B132B), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, color: Color(0xFF06D6A0)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _deviceId));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ معرف الجهاز', textDirection: TextDirection.rtl)));
                          },
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('معرف الجهاز (Device ID):', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            Text(_deviceId, style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 17, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeCtrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'أدخل كود التفعيل هنا (ACT-...)',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0B132B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0), padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _submitActivationCode,
                      child: const Text('تفعيل التطبيق الآن', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () async {
                      String msg = Uri.encodeComponent("مرحباً، أرغب في الاشتراك وتفعيل تطبيق RASED.\nمعرف جهازي هو: $_deviceId");
                      Uri wa = Uri.parse("whatsapp://send?phone=201155661920&text=$msg");
                      if (await canLaunchUrl(wa)) {
                        await launchUrl(wa, mode: LaunchMode.externalApplication);
                      } else {
                        await launchUrl(Uri.parse("https://wa.me/201155661920?text=$msg"), mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.support_agent, color: Color(0xFF06D6A0)),
                    label: const Text('طلب كود تفعيل عبر واتساب', style: TextStyle(color: Color(0xFF06D6A0))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SheekhaFullEngine {
  static final Map<String, String> lettersMap = {
    'الف': 'أ', 'ألف': 'أ', 'ا': 'أ', 'أ': 'أ', 'إ': 'أ', 'آ': 'أ', 'ء': 'أ',
    'باء': 'ب', 'به': 'ب', 'با': 'ب', 'بي': 'ب', 'ب': 'ب',
    'تاء': 'ت', 'ته': 'ت', 'تا': 'ت', 'تي': 'ت', 'ت': 'ت',
    'ثاء': 'ث', 'ثه': 'ث', 'ثا': 'ث', 'ث': 'ث',
    'جيم': 'ج', 'جه': 'ج', 'جا': 'ج', 'جي': 'ج', 'ج': 'ج',
    'حاء': 'ح', 'حه': 'ح', 'حا': 'ح', 'حي': 'ح', 'ح': 'ح',
    'خاء': 'خ', 'خه': 'خ', 'خا': 'خ', 'خي': 'خ', 'خ': 'خ',
    'دال': 'د', 'ده': 'د', 'دا': 'د', 'دي': 'د', 'د': 'د',
    'ذال': 'ذ', 'ذه': 'ذ', 'ذا': 'ذ', 'ذ': 'ذ',
    'راء': 'ر', 'ره': 'ر', 'را': 'ر', 'ري': 'ر', 'ر': 'ر',
    'زين': 'ز', 'زه': 'ز', 'زا': 'ز', 'زاي': 'ز', 'ز': 'ز',
    'سين': 'س', 'سه': 'س', 'سين': 'س', 'سا': 'س', 'سي': 'س', 'س': 'س',
    'شين': 'ش', 'شه': 'ش', 'شين': 'ش', 'شا': 'ش', 'شي': 'ش', 'ش': 'ش',
    'صاد': 'ص', 'صاه': 'ص', 'صا': 'ص', 'صي': 'ص', 'ص': 'ص',
    'ضاد': 'ض', 'ضه': 'ض', 'ضا': 'ض', 'ضي': 'ض', 'ض': 'ض',
    'طاء': 'ط', 'طه': 'ط', 'طاء': 'ط', 'طا': 'ط', 'طي': 'ط', 'ط': 'ط',
    'ظاء': 'ظ', 'ظه': 'ظ', 'ظا': 'ظ', 'ظ': 'ظ',
    'عين': 'ع', 'عه': 'ع', 'عين': 'ع', 'عا': 'ع', 'عي': 'ع', 'ع': 'ع',
    'غين': 'غ', 'غه': 'غ', 'غين': 'غ', 'غا': 'غ', 'غاء': 'غ', 'غ': 'غ',
    'فاء': 'ف', 'فه': 'ف', 'فا': 'ف', 'في': 'ف', 'ف': 'ف',
    'قاف': 'ق', 'قه': 'ق', 'قا': 'ق', 'قف': 'ق', 'ق': 'ق',
    'كاف': 'ك', 'كه': 'ك', 'كاف': 'ك', 'كا': 'ك', 'كي': 'ك', 'ك': 'ك',
    'لام': 'ل', 'له': 'ل', 'لام': 'ل', 'لا': 'ل', 'لي': 'ل', 'ل': 'ل',
    'ميم': 'م', 'مه': 'م', 'ميم': 'م', 'ما': 'م', 'مين': 'م', 'م': 'م',
    'نون': 'ن', 'نه': 'ن', 'نون': 'ن', 'نا': 'ن', 'ني': 'ن', 'ن': 'ن',
    'هاء': 'ه', 'هه': 'ه', 'هاء': 'ه', 'ها': 'ه', 'هـ': 'ه', 'ه': 'ه',
    'واو': 'و', 'وه': 'و', 'واو': 'و', 'وا': 'و', 'و': 'و',
    'ياء': 'ي', 'يه': 'ي', 'ياء': 'ي', 'يا': 'ي', 'ى': 'ي', 'ي': 'ي',
  };

  static final Map<String, List<String>> compounds = {
    'واوقاف': ['و', 'ق'], 'أوقاف': ['و', 'ق'], 'اوقاف': ['و', 'ق'],
    'واوساط': ['و', 'ص'], 'أوساط': ['و', 'ص'], 'اوساط': ['و', 'ص'],
    'اوصاد': ['أ', 'و', 'ص'], 'أوصاد': ['أ', 'و', 'ص'], 'اوص': ['أ', 'و', 'ص'], 'أوص': ['أ', 'و', 'ص'],
    'نوعين': ['ن', 'ع'], 'نهاء': ['ن', 'ه'], 'تقديم': ['ك', 'ه', 'ج'], 'خطه': ['خ', 'ط'],
    'خطف': ['خ', 'ط', 'ف'], 'افلام': ['ل', 'ق'], 'لمن': ['ل', 'م', 'ن'],
    'منوعين': ['م', 'ن', 'ع'], 'وعج': ['و', 'ع', 'ج'], 'عقب': ['ع', 'ق', 'ب'],
  };

  static final Map<String, String> digitsMap = {
    'صفر': '0', 'زيرو': '0', 'واحد': '1', 'واحده': '1',
    'اتنين': '2', 'اثنين': '2', 'إثنين': '2', 'تنين': '2',
    'تلاته': '3', 'ثلاثة': '3', 'تلات': '3', 'تلاتة': '3',
    'اربعة': '4', 'اربعه': '4', 'أربعة': '4', 'اربع': '4',
    'خمسه': '5', 'خمسة': '5', 'خمس': '5',
    'سته': '6', 'ستة': '6', 'ست': '6',
    'سبعه': '7', 'سبعة': '7', 'سبع': '7',
    'تمانيه': '8', 'ثمانية': '8', 'ثمانيه': '8', 'تمن': '8',
    'تسعه': '9', 'تسعة': '9', 'تسع': '9',
  };

  static Map<String, dynamic>? parsePlateAndType(String text) {
    if (text.trim().isEmpty) return null;

    String normalized = normalizeDigits(text);
    List<String> rawTokens = normalized.split(RegExp(r'\s+'));
    List<String> stream = [];

    for (String token in rawTokens) {
      String w = token.replaceAll(RegExp(r'[^\u0621-\u064A0-9]'), '');
      if (w.isEmpty) continue;

      if (digitsMap.containsKey(w)) {
        stream.add(digitsMap[w]!);
      } else if (RegExp(r'^\d+$').hasMatch(w)) {
        for (int i = 0; i < w.length; i++) stream.add(w[i]);
      } else if (compounds.containsKey(w)) {
        stream.addAll(compounds[w]!);
      } else if (lettersMap.containsKey(w)) {
        stream.add(lettersMap[w]!);
      } else {
        for (int i = 0; i < w.length; i++) {
          String ch = w[i];
          if (ch == 'ة' || (ch == 'ه' && i == w.length - 1)) continue;
          if (RegExp(r'[\u0621-\u064A]').hasMatch(ch)) {
            stream.add(ch == 'أ' || ch == 'إ' || ch == 'آ' ? 'أ' : ch);
          }
        }
      }
    }

    List<String> letters = [];
    String digitsStr = '';

    for (String item in stream) {
      if (RegExp(r'^\d$').hasMatch(item)) {
        digitsStr += item;
      } else if (RegExp(r'^[\u0621-\u064A]$').hasMatch(item)) {
        if (digitsStr.length >= 3 && letters.length >= 2) {
          break;
        } else {
          if (letters.length < 3) letters.add(item);
        }
      }
    }

    if (letters.length >= 2 && digitsStr.length >= 3) {
      return {
        'letters': letters.join(' '),
        'digits': digitsStr.substring(0, digitsStr.length > 4 ? 4 : digitsStr.length),
        'type': 'ملاكي',
      };
    }

    return null;
  }

  static String normalizeDigits(String input) {
    String res = input;
    digitsMap.forEach((k, v) {
      res = res.replaceAll(k, v);
    });
    return res;
  }
}
