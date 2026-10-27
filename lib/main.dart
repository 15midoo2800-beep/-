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

// نظام حماية التراخيص والتحكم عن بُعد (النسخة التجارية المدعومة بإعادة التفعيل الفوري)
class RasedLicenseManager {
  static const String _secretSalt = "RASED_PRO_2026_SECRET_KEY";
  
  static const String githubApiUrl = "https://api.github.com/repos/15midoo2800-beep/Admin-Rased/contents/clients_control.json";
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

  static Future<String?> _fetchControlJson() async {
    HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 7);

    try {
      Uri apiUri = Uri.parse("$githubApiUrl?t=${DateTime.now().millisecondsSinceEpoch}");
      HttpClientRequest req = await client.getUrl(apiUri);
      req.headers.set(HttpHeaders.userAgentHeader, 'RasedClientApp/2.0');
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github.v3.raw');
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store, must-revalidate');
      HttpClientResponse res = await req.close();

      if (res.statusCode == 200) {
        return await res.transform(utf8.decoder).join();
      }
    } catch (_) {}

    try {
      Uri rawUri = Uri.parse("$remoteControlJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}");
      HttpClientRequest req = await client.getUrl(rawUri);
      req.headers.set(HttpHeaders.userAgentHeader, 'RasedClientApp/2.0');
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store, must-revalidate');
      HttpClientResponse res = await req.close();

      int redirects = 0;
      while ((res.statusCode == HttpStatus.movedPermanently ||
              res.statusCode == HttpStatus.movedTemporarily ||
              res.statusCode == HttpStatus.seeOther ||
              res.statusCode == HttpStatus.temporaryRedirect ||
              res.statusCode == 308) && redirects < 5) {
        redirects++;
        String? loc = res.headers.value(HttpHeaders.locationHeader);
        if (loc == null) break;
        rawUri = Uri.parse(loc);
        await res.drain();
        req = await client.getUrl(rawUri);
        req.headers.set(HttpHeaders.userAgentHeader, 'RasedClientApp/2.0');
        req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
        res = await req.close();
      }

      if (res.statusCode == 200) {
        return await res.transform(utf8.decoder).join();
      }
    } catch (_) {}

    return null;
  }

  static Future<Map<String, dynamic>> checkRemoteStatus(String myDeviceId, String currentExpiryIso) async {
    final prefs = await SharedPreferences.getInstance();
    bool remoteCheckSuccessful = false;

    try {
      if (!remoteControlJsonUrl.contains("YOUR_USERNAME")) {
        String? body = await _fetchControlJson();

        if (body != null && body.trim().isNotEmpty) {
          remoteCheckSuccessful = true;
          List<dynamic> list = json.decode(body);
          
          for (var item in list) {
            if (item['deviceId'].toString().trim().toUpperCase() == myDeviceId.trim().toUpperCase()) {
              bool active = item['isActive'] == true;
              
              if (!active) {
                await prefs.setBool('rased_perm_ban_$myDeviceId', true);
                return {'allowed': false, 'reason': 'تم إيقاف اشتراكك من قِبل الإدارة'};
              } else {
                await prefs.setBool('rased_perm_ban_$myDeviceId', false);
              }

              if (item['expiry'] != null) {
                DateTime remoteExp = DateTime.parse("${item['expiry']}T23:59:59");
                await prefs.setString('rased_license_expiry', remoteExp.toIso8601String());
                if (DateTime.now().isAfter(remoteExp)) {
                  return {'allowed': false, 'reason': 'انتهت فترة اشتراكك، يرجى التجديد'};
                }
                return {'allowed': true, 'expiry': remoteExp.toIso8601String()};
              }
            }
          }
        }
      }
    } catch (_) {
      remoteCheckSuccessful = false;
    }

    if (!remoteCheckSuccessful) {
      bool isPermanentlyBanned = prefs.getBool('rased_perm_ban_$myDeviceId') ?? false;
      if (isPermanentlyBanned) {
        return {'allowed': false, 'reason': 'تم إيقاف اشتراكك من قِبل الإدارة'};
      }
    }

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

class SubscriptionGateScreen extends StatefulWidget {
  final Function(Locale) onLanguageChange;
  const SubscriptionGateScreen({super.key, required this.onLanguageChange});

  @override
  State<SubscriptionGateScreen> createState() => _SubscriptionGateScreenState();
}

class _SubscriptionGateScreenState extends State<SubscriptionGateScreen> with WidgetsBindingObserver {
  bool _isChecking = true;
  bool _isActivated = false;
  String _deviceId = '';
  String _errorMessage = '';
  final TextEditingController _codeCtrl = TextEditingController();
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifyCurrentLicense();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _silentBackgroundCheck();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentBackgroundCheck();
    }
  }

  Future<void> _silentBackgroundCheck() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedExpiry = prefs.getString('rased_license_expiry');
    if (_deviceId.isEmpty || savedExpiry == null) return;

    var remoteCheck = await RasedLicenseManager.checkRemoteStatus(_deviceId, savedExpiry);
    if (mounted) {
      setState(() {
        if (remoteCheck['allowed'] == true) {
          _isActivated = true;
          _errorMessage = '';
        } else {
          _isActivated = false;
          _errorMessage = remoteCheck['reason'] ?? 'تم إيقاف اشتراكك من قِبل الإدارة';
        }
      });
    }
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
      await prefs.setBool('rased_perm_ban_$_deviceId', false);
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

// محرك المعالجة والذكاء الصوتي المطور (يقبل التعلم التلقائي وقواميس الحروف والسيارات)
class SheekhaFullEngine {
  // قاموس الحروف الأساسي واللهجة المصرية
  static final Map<String, String> lettersMap = {
    'الف': 'أ', 'ألف': 'أ', 'ا': 'أ', 'أ': 'أ', 'إ': 'أ', 'آ': 'أ', 'ء': 'أ',
    'باء': 'ب', 'به': 'ب', 'بة': 'ب', 'با': 'ب', 'بي': 'ب', 'ب': 'ب',
    'تاء': 'ت', 'ته': 'ت', 'تا': 'ت', 'تي': 'ت', 'ت': 'ت',
    'ثاء': 'ث', 'ثه': 'ث', 'ثا': 'ث', 'ث': 'ث',
    'جيم': 'ج', 'جه': 'ج', 'جا': 'ج', 'جي': 'ج', 'ج': 'ج',
    'حاء': 'ح', 'حه': 'ح', 'حا': 'ح', 'حي': 'ح', 'ح': 'ح',
    'خاء': 'خ', 'خه': 'خ', 'خا': 'خ', 'خي': 'خ', 'خ': 'خ',
    'دال': 'د', 'ده': 'د', 'دا': 'د', 'دي': 'د', 'د': 'د',
    'ذال': 'ذ', 'ذه': 'ذ', 'ذا': 'ذ', 'ذ': 'ذ',
    'راء': 'ر', 'ره': 'ر', 'را': 'ر', 'ري': 'ر', 'ر': 'ر',
    'زين': 'ز', 'زه': 'ز', 'زا': 'ز', 'زاي': 'ز', 'ز': 'ز',
    'سين': 'س', 'سه': 'س', 'سا': 'س', 'سي': 'س', 'س': 'س',
    'شين': 'ش', 'شه': 'ش', 'شا': 'ش', 'شي': 'ش', 'ش': 'ش',
    'صاد': 'ص', 'صاه': 'ص', 'صا': 'ص', 'صي': 'ص', 'ص': 'ص',
    'ضاد': 'ض', 'ضه': 'ض', 'ضا': 'ض', 'ضي': 'ض', 'ض': 'ض',
    'طاء': 'ط', 'طه': 'ط', 'طا': 'ط', 'ط': 'ط',
    'ظاء': 'ظ', 'ظه': 'ظ', 'ظا': 'ظ', 'ظ': 'ظ',
    'عين': 'ع', 'عن': 'ع', 'عاه': 'ع', 'عا': 'ع', 'عي': 'ع', 'ع': 'ع',
    'غين': 'غ', 'غه': 'غ', 'غا': 'غ', 'غ': 'غ',
    'فاء': 'ف', 'فه': 'ف', 'فا': 'ف', 'ف': 'ف',
    'قاف': 'ق', 'قه': 'ق', 'قا': 'ق', 'ق': 'ق',
    'كاف': 'ك', 'كه': 'ك', 'كا': 'ك', 'ك': 'ك',
    'لام': 'ل', 'له': 'ل', 'لا': 'ل', 'ل': 'ل',
    'ميم': 'م', 'مه': 'م', 'ما': 'م', 'م': 'م',
    'نون': 'ن', 'نه': 'ن', 'نا': 'ن', 'ن': 'ن',
    'هاء': 'ه', 'هح': 'ه', 'هه': 'ه', 'ها': 'ه', 'ه': 'ه',
    'واو': 'و', 'وه': 'و', 'وا': 'و', 'و': 'و',
    'ياء': 'ي', 'يه': 'ي', 'ية': 'ي', 'يا': 'ي', 'ي': 'ي',
  };

  // قاموس الأرقام العربية والعامية
  static final Map<String, String> numbersMap = {
    'صفر': '0', 'صِفر': '0',
    'واحد': '1', 'واحده': '1',
    'اثنين': '2', 'اتنين': '2', 'ثنين': '2', 'تنين': '2',
    'ثلاثة': '3', 'تلاته': '3', 'تلاتة': '3', 'ثلاثه': '3',
    'أربعة': '4', 'اربعة': '4', 'اربع': '4',
    'خمسة': '5', 'خمسه': '5',
    'ستة': '6', 'سته': '6',
    'سبعة': '7', 'سبعه': '7',
    'ثمانية': '8', 'تمانيه': '8', 'ثمانيه': '8',
    'تسعة': '9', 'تسعه': '9',
  };

  // قاموس أنواع السيارات المطلوب كاملاً
  static final List<String> vehicleTypes = [
    'تويوتا', 'نيسان', 'مازدا', 'هوندا', 'لكزس', 'سوزوكي', 'هيونداي', 'كيا',
    'جينيسيس', 'فورد', 'شيفروليه', 'جي إم سي', 'كاديلاك', 'رام', 'هافال',
    'شانجان', 'جيلي', 'جيتور', 'إم جي', 'شيري', 'بي واي دي', 'مرسيدس-بنز',
    'بي إم دبليو', 'أودي', 'فولكس فاجن', 'لاند روفر', 'بورش', 'نقل', 'فان',
    'باص', 'تلاجة كبيرة', 'ج랜드 ماكس', 'هاي اس', 'نقل عام', 'ملاكي'
  ];

  // دالة الحفظ والتعلم الذاتي: إذا تم تعديل حرف أو كلمة خطأ يدوياً، يتم حفظها في SharedPreferences
  static Future<void> learnNewPronunciation(String spokenWord, String correctTarget) async {
    final prefs = await SharedPreferences.getInstance();
    String? customMapJson = prefs.getString('custom_pronunciation_map');
    Map<String, dynamic> customMap = {};
    if (customMapJson != null) {
      customMap = json.decode(customMapJson);
    }
    customMap[spokenWord.trim().toLowerCase()] = correctTarget.trim();
    await prefs.setString('custom_pronunciation_map', json.encode(customMap));
  }

  // استرجاع القاموس المخصص والمحدث بتعلم المستخدم
  static Future<String?> getLearnedPronunciation(String spokenWord) async {
    final prefs = await SharedPreferences.getInstance();
    String? customMapJson = prefs.getString('custom_pronunciation_map');
    if (customMapJson != null) {
      Map<String, dynamic> customMap = json.decode(customMapJson);
      return customMap[spokenWord.trim().toLowerCase()];
    }
    return null;
  }

  // تحليل النص المنطوق واستخراج اللوحة والنوع بدقة
  static Future<Map<String, String>> parseVoiceInput(String rawText) async {
    List<String> words = rawText.split(RegExp(r'\s+'));
    List<String> plateLetters = [];
    List<String> plateDigits = [];
    String detectedType = '';

    for (String w in words) {
      // 1. فحص هل الكلمة مسجلة في الذاكرة المخصصة للتعلم السابق؟
      String? learned = await getLearnedPronunciation(w);
      if (learned != null) {
        if (lettersMap.containsValue(learned) || learned.length == 1) {
          plateLetters.add(learned);
        } else if (int.tryParse(learned) != null) {
          plateDigits.add(learned);
        } else {
          detectedType = learned;
        }
        continue;
      }

      // 2. فحص الحروف
      if (lettersMap.containsKey(w)) {
        plateLetters.add(lettersMap[w]!);
      } 
      // 3. فحص الأرقام
      else if (numbersMap.containsKey(w)) {
        plateDigits.add(numbersMap[w]!);
      } 
      // 4. فحص رقم صريح (مثل 2517)
      else if (int.tryParse(w) != null) {
        plateDigits.addAll(w.split(''));
      } 
      // 5. فحص أنواع السيارات
      else {
        for (String v in vehicleTypes) {
          if (w.contains(v) || v.contains(w)) {
            detectedType = v;
            break;
          }
        }
      }
    }

    String finalPlate = "${plateLetters.join('')} ${plateDigits.join('')}".trim();
    return {
      'plate': finalPlate,
      'type': detectedType,
    };
  }
}
