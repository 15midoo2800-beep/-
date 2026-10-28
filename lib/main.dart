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
      if (res.statusCode == 200) return await res.transform(utf8.decoder).join();
    } catch (_) {}

    try {
      Uri rawUri = Uri.parse("$remoteControlJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}");
      HttpClientRequest req = await client.getUrl(rawUri);
      req.headers.set(HttpHeaders.userAgentHeader, 'RasedClientApp/2.0');
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store, must-revalidate');
      HttpClientResponse res = await req.close();
      int redirects = 0;
      while ((res.statusCode == HttpStatus.movedPermanently || res.statusCode == HttpStatus.movedTemporarily || res.statusCode == HttpStatus.seeOther || res.statusCode == HttpStatus.temporaryRedirect || res.statusCode == 308) && redirects < 5) {
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
      if (res.statusCode == 200) return await res.transform(utf8.decoder).join();
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
      if (isPermanentlyBanned) return {'allowed': false, 'reason': 'تم إيقاف اشتراكك من قِبل الإدارة'};
    }

    DateTime exp = DateTime.parse(currentExpiryIso);
    if (DateTime.now().isAfter(exp)) return {'allowed': false, 'reason': 'انتهت فترة اشتراكك، يرجى التواصل للتجديد'};
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
    if (state == AppLifecycleState.resumed) _silentBackgroundCheck();
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
    if (_isChecking) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF06D6A0))));
    if (_isActivated) return SheekhaHomeScreen(onLanguageChange: widget.onLanguageChange);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF06D6A0), width: 1.5)),
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
                    decoration: InputDecoration(hintText: 'أدخل كود التفعيل هنا (ACT-...)', hintStyle: const TextStyle(color: Colors.grey, fontSize: 12), filled: true, fillColor: const Color(0xFF0B132B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
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
                      if (await canLaunchUrl(wa)) await launchUrl(wa, mode: LaunchMode.externalApplication);
                      else await launchUrl(Uri.parse("https://wa.me/201155661920?text=$msg"), mode: LaunchMode.externalApplication);
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
  static Map<String, dynamic> userLearnedMap = {};
  
  static Future<void> loadLearnedDictionary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString('rased_user_learned_v8');
      if (saved != null && saved.isNotEmpty) {
        userLearnedMap = json.decode(saved);
      }
    } catch (_) {}
  }

  static Future<void> saveLearnedMapping(String rawSpoken, String correctLetters, String correctDigits, String correctType) async {
    String cleanSpoken = normalizeFlexible(rawSpoken);
    if (cleanSpoken.isEmpty) return;

    userLearnedMap[cleanSpoken] = {
      'letters': correctLetters.trim(),
      'digits': correctDigits.trim(),
      'type': correctType.trim(),
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rased_user_learned_v8', json.encode(userLearnedMap));
    } catch (_) {}
  }

  static final Map<String, String> lettersMap = {
    'الف': 'أ', 'ألف': 'أ', 'إلف': 'أ', 'ا': 'أ', 'أ': 'أ', 'إ': 'أ', 'آ': 'أ',
    'باء': 'ب', 'به': 'ب', 'بة': 'ب', 'با': 'ب', 'بي': 'ب', 'ب': 'ب',
    'تاء': 'ت', 'ته': 'ت', 'تا': 'ت', 'ت': 'ت',
    'ثاء': 'ث', 'ثه': 'ث', 'ثا': 'ث', 'ث': 'ث',
    'جيم': 'ج', 'جه': 'ج', 'جا': 'ج', 'ج': 'ج',
    'حاء': 'ح', 'حه': 'ح', 'حة': 'ح', 'حا': 'ح', 'ح': 'ح',
    'خاء': 'خ', 'خه': 'خ', 'خا': 'خ', 'خ': 'خ',
    'دال': 'د', 'ده': 'د', 'دا': 'د', 'د': 'د',
    'ذال': 'ذ', 'ذه': 'ذ', 'ذا': 'ذ', 'ذ': 'ذ',
    'راء': 'ر', 'ره': 'ر', 'رة': 'ر', 'را': 'ر', 'ر': 'ر',
    'زين': 'ز', 'زه': 'ز', 'زا': 'ز', 'زاي': 'ز', 'ز': 'ز',
    'سين': 'س', 'سه': 'س', 'سا': 'س', 'س': 'س',
    'شين': 'ش', 'شه': 'ش', 'شا': 'ش', 'ش': 'ش',
    'صاد': 'ص', 'صاه': 'ص', 'صه': 'ص', 'صا': 'ص', 'ص': 'ص',
    'ضاد': 'ض', 'ضه': 'ض', 'ضا': 'ض', 'ض': 'ض',
    'طاء': 'ط', 'طه': 'ط', 'طا': 'ط', 'ط': 'ط',
    'ظاء': 'ظ', 'ظه': 'ظ', 'ظا': 'ظ', 'ظ': 'ظ',
    'عين': 'ع', 'عه': 'ع', 'عا': 'ع', 'عن': 'ع', 'ع': 'ع',
    'غين': 'غ', 'غه': 'غ', 'غا': 'غ', 'غ': 'غ',
    'فاء': 'ف', 'فه': 'ف', 'فة': 'ف', 'فا': 'ف', 'ف': 'ف',
    'قاف': 'ق', 'قه': 'ق', 'قا': 'ق', 'ق': 'ق',
    'كاف': 'ك', 'كه': 'ك', 'كا': 'ك', 'ك': 'ك',
    'لام': 'ل', 'له': 'ل', 'لا': 'ل', 'ل': 'ل',
    'ميم': 'م', 'مه': 'م', 'ما': 'م', 'م': 'م',
    'نون': 'ن', 'نه': 'ن', 'نا': 'ن', 'ن': 'ن',
    'هاء': 'ه', 'هه': 'ه', 'ها': 'ه', 'ه': 'ه',
    'واو': 'و', 'وه': 'و', 'وا': 'و', 'و': 'و',
    'ياء': 'ي', 'يه': 'ي', 'ية': 'ي', 'يا': 'ي', 'ى': 'ي', 'ي': 'ي',
  };

  static final Map<String, List<String>> compounds = {
    'واويه': ['و', 'ي'], 'واوية': ['و', 'ي'], 'واوياء': ['و', 'ي'],
    'واودال': ['و', 'د'], 'واوقاف': ['و', 'ق'], 'أوقاف': ['و', 'ق'],
    'واوساط': ['و', 'ص'], 'أوساط': ['و', 'ص'], 'اوصاد': ['أ', 'و', 'ص'], 'أوصاد': ['أ', 'و', 'ص'],
    'راهدال': ['ر', 'د'], 'رادال': ['ر', 'د'], 'رهدال': ['ر', 'د'],
    'عينرا': ['ع', 'ر'], 'عينره': ['ع', 'ر'], 'الفنون': ['أ', 'ن'], 'ألفنون': ['أ', 'ن'],
    'بهلام': ['ب', 'ل'], 'بالام': ['ب', 'ل'], 'بلام': ['ب', 'ل'],
    'نونواو': ['ن', 'و'], 'نونواوه': ['ن', 'و', 'ي'], 'يهبه': ['ي', 'ب'], 'يهدال': ['ي', 'د'],
    'نوعين': ['ن', 'ع'], 'نهاء': ['ن', 'ه'],
  };

  static final Map<String, String> digitsMap = {
    'صفر': '0', 'صِفر': '0', 'زيرو': '0', 'واحد': '1', 'واحده': '1', 'واحدة': '1', 'وحد': '1',
    'اتنين': '2', 'اثنين': '2', 'إثنين': '2', 'تنين': '2', 'اثنان': '2', 'اتنان': '2',
    'تلاته': '3', 'ثلاثة': '3', 'تلات': '3', 'تلاتة': '3', 'ثلاثه': '3', 'ثلاث': '3',
    'اربعة': '4', 'اربعه': '4', 'أربعة': '4', 'أربعه': '4', 'اربع': '4', 'أربع': '4',
    'خمسه': '5', 'خمسة': '5', 'خمس': '5', 'سته': '6', 'ستة': '6', 'ست': '6',
    'سبعه': '7', 'سبعة': '7', 'سبع': '7', 'تمانيه': '8', 'ثمانية': '8', 'ثمانيه': '8', 'تمانية': '8', 'تمن': '8',
    'تسعه': '9', 'تسعة': '9', 'تسع': '9',
  };

  static final Map<String, List<String>> vehicleTypesMap = {
    'نقل عام': ['نقل عام', 'نقلي عام'], 'جراند ماكس': ['جراند ماكس', 'قراند ماكس', 'جراند مكس', 'جراند', 'قراند'],
    'تلاجة كبيرة': ['تلاجة كبيرة', 'تلاجه كبيره', 'ثلاجة كبيرة', 'ثلاجه كبيره', 'تلاجه', 'ثلاجة'],
    'هاي اس': ['هاي اس', 'هايس', 'هاي آيس', 'هايسن', 'هاي ايس', 'هاي إس'], 'فان': ['فان', 'فن', 'بان'],
    'نقل': ['نقل', 'ناقل'], 'بيك اب': ['بيك اب', 'بيك آب', 'بيكب', 'دباب'],
    'اتوبيس': ['اتوبيس', 'أتوبيس', 'باص', 'ميكروباص'], 'تويوتا': ['تويوتا', 'تيوتا', 'تايوتا'],
    'نيسان': ['نيسان', 'نسان'], 'مازدا': ['مازدا', 'مزدا'], 'هوندا': ['هوندا', 'هندا'],
    'لكزس': ['لكزس', 'لكزيس', 'لكسز'], 'سوزوكي': ['سوزوكي', 'سزوكي'],
    'هيونداي': ['هيونداي', 'هونداي', 'هينداي'], 'كيا': ['كيا'], 'جينيسيس': ['جينيسيس', 'جنسس', 'جينسس'],
    'فورد': ['فورد'], 'شيفروليه': ['شيفروليه', 'شفروليه', 'شفر'], 'جي إم سي': ['جي إم سي', 'جي ام سي', 'جيمس', 'جمس'],
    'كاديلاك': ['كاديلاك', 'كديلاك'], 'رام': ['رام'], 'هافال': ['هافال'], 'شانجان': ['شانجان', 'شنجان'],
    'جيلي': ['جيلي', 'جلي'], 'جيتور': ['جيتور'], 'إم جي': ['إم جي', 'ام جي', 'امجي'], 'شيري': ['شيري', 'شري'],
    'بي واي دي': ['بي واي دي', 'بي وايدي'], 'مرسيدس-بنز': ['مرسيدس بنز', 'مرسيدس-بنز', 'مرسيدس', 'بنز'],
    'بي إم دبليو': ['بي إم دبليو', 'بي ام دبليو', 'بي ام'], 'أودي': ['أودي', 'اودي'],
    'فولكس فاجن': ['فولكس فاجن', 'فولكس واجن', 'فولكس'], 'لاند روفر': ['لاند روفر', 'لاندروفر', 'رنج روفر'],
    'بورش': ['بورش', 'بورشه'], 'ملاكي': ['ملاكي', 'خصوصي'],
  };

  static String? extractVehicleType(String text) {
    String clean = text.trim();
    if (clean.isEmpty) return null;
    for (var entry in vehicleTypesMap.entries) {
      for (String synonym in entry.value) {
        if (clean.contains(synonym)) return entry.key;
      }
    }
    return null;
  }

  // تطبيق خوارزمية Stream Buffer والتقاط الأنماط عبر النافذة المنزلقة (Regex-like parsing)
  static Map<String, dynamic>? parsePlateAndType(String bufferText) {
    if (bufferText.trim().isEmpty) return null;

    String normalizedVoice = normalizeFlexible(bufferText);
    if (userLearnedMap.containsKey(normalizedVoice)) {
      var learned = userLearnedMap[normalizedVoice];
      return {'letters': learned['letters'], 'digits': learned['digits'], 'type': learned['type'] ?? '-', 'hasExplicitType': true, 'startsWithAlefOrBaa': false};
    }

    String normalized = normalizeDigits(bufferText);
    String? detectedType = extractVehicleType(normalized);

    String textForPlate = normalized;
    if (detectedType != null && vehicleTypesMap.containsKey(detectedType)) {
      for (String syn in vehicleTypesMap[detectedType]!) textForPlate = textForPlate.replaceAll(syn, ' ');
    }

    compounds.forEach((k, v) => textForPlate = textForPlate.replaceAll(k, ' ${v.join(' ')} '));
    List<String> rawTokens = textForPlate.split(RegExp(r'\s+'));
    List<String> stream = [];

    for (String token in rawTokens) {
      String w = token.replaceAll(RegExp(r'[^\u0621-\u064A0-9]'), '');
      if (w.isEmpty) continue;

      if (digitsMap.containsKey(w)) {
        stream.add(digitsMap[w]!);
      } else if (RegExp(r'^\d+$').hasMatch(w)) {
        for (int i = 0; i < w.length; i++) stream.add(w[i]);
      } else if (lettersMap.containsKey(w)) {
        stream.add(lettersMap[w]!);
      } else {
        for (int i = 0; i < w.length; i++) {
          String ch = w[i];
          if (lettersMap.containsKey(ch)) stream.add(lettersMap[ch]!);
        }
      }
    }

    for (int i = stream.length - 1; i >= 0; i--) {
      if (RegExp(r'^\d$').hasMatch(stream[i])) {
        int dEnd = i;
        int dStart = i;
        while (dStart - 1 >= 0 && RegExp(r'^\d$').hasMatch(stream[dStart - 1])) dStart--;
        
        int numDigits = dEnd - dStart + 1;
        if (numDigits >= 3 && numDigits <= 4) {
          List<String> lettersFound = [];
          for (int j = dStart - 1; j >= 0 && lettersFound.length < 3; j--) {
            if (RegExp(r'^[\u0621-\u064A]$').hasMatch(stream[j])) {
              lettersFound.insert(0, stream[j]);
            } else break;
          }
          if (lettersFound.length >= 2) {
            String digitsStr = stream.sublist(dStart, dEnd + 1).join('');
            String firstL = lettersFound.first;
            bool startsWithAorB = (firstL == 'أ' || firstL == 'ا' || firstL == 'إ' || firstL == 'ب');
            return {
              'letters': lettersFound.join(' '),
              'digits': digitsStr,
              'type': detectedType ?? (startsWithAorB ? '-' : 'ملاكي'),
              'hasExplicitType': detectedType != null,
              'startsWithAlefOrBaa': startsWithAorB,
            };
          }
        }
        i = dStart;
      }
    }
    return null;
  }

  static String normalizeDigits(String input) {
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < ar.length; i++) input = input.replaceAll(ar[i], en[i]);
    return input;
  }

  static String normalizeFlexible(String input) {
    String res = normalizeDigits(input.trim());
    res = res.replaceAll(RegExp(r'[أإآا]'), 'ا');
    res = res.replaceAll(RegExp(r'[يى]'), 'ي');
    res = res.replaceAll(RegExp(r'[ةه]'), 'ه');
    res = res.replaceAll(RegExp(r'\s+'), '');
    return res;
  }
}

class SheekhaHomeScreen extends StatefulWidget {
  final Function(Locale) onLanguageChange;
  const SheekhaHomeScreen({super.key, required this.onLanguageChange});
  @override
  State<SheekhaHomeScreen> createState() => _SheekhaHomeScreenState();
}

class _SheekhaHomeScreenState extends State<SheekhaHomeScreen> {
  int _currentIndex = 4;
  bool _isListening = false;
  String _currentStatusText = AppStrings.listeningNow;
  double _soundLevel = 0.0;

  final Map<String, DateTime> _cooldowns = {};
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  
  // Stream Buffer Variables
  String _circularBuffer = '';
  Timer? _pendingTimer;
  Map<String, String>? _pendingPlate;

  final List<String> _districts = ['الروضة', 'السلام', 'المنيل', 'المعادي'];
  String _currentDistrict = 'الروضة';
  String _currentStreet = 'ض 1';
  String _currentCoordinates = '';
  String _selectedNote = 'بدون';
  String _wantedFileName = 'لم يتم رفع ملف السيارات المطلوبة';
  String _appendFileName = 'لم يتم اختيار ملف';
  String _savedWhatsAppPhone = '00201155661920';
  bool _isGpsEnabled = true;

  List<Map<String, String>> _records = [];
  
  // O(1) Hash-Map Index for extreme fast searching
  Map<String, List<Map<String, String>>> _wantedDatabaseIndexed = {};
  final Set<String> _selectedWantedIds = {};
  int _totalWantedCount = 0;

  final TextEditingController _manualSearchCtrl = TextEditingController();
  List<Map<String, String>> _manualSearchResults = [];
  bool _isManualSearching = false;

  @override
  void initState() {
    super.initState();
    SheekhaFullEngine.loadLearnedDictionary();
    _loadData();
    _initEngine();
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initEngine() async {
    var micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) return;
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && _isListening && mounted) _restartListeningSafely();
        },
        onError: (error) {
          if (_isListening && mounted) _restartListeningSafely();
        },
      );
      setState(() => _speechEnabled = available);
    } catch (_) {}
  }

  void _restartListeningSafely() {
    if (!_isListening) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isListening && mounted && !_speech.isListening) _startListeningSession();
    });
  }

  void _toggleLiveListening() async {
    if (_isListening) {
      _commitPendingPlate();
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
        _currentStatusText = AppStrings.stopped;
        _circularBuffer = '';
      });
      await _speech.stop();
    } else {
      await SheekhaFullEngine.loadLearnedDictionary();
      if (!_speechEnabled) {
        await _initEngine();
        if (!_speechEnabled) return;
      }
      setState(() {
        _isListening = true;
        _currentStatusText = AppStrings.listeningNow;
        _circularBuffer = '';
      });
      _startListeningSession();
    }
  }

  void _commitPendingPlate() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    if (_pendingPlate != null) {
      var p = _pendingPlate!;
      _pendingPlate = null;
      _registerDetectedPlate(p['letters']!, p['digits']!, p['type']!, rawSpoken: p['raw'] ?? '');
    }
  }

  void _startListeningSession() async {
    if (!_isListening) return;
    await _speech.listen(
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
      onSoundLevelChange: (level) {
        if (mounted) setState(() => _soundLevel = level.clamp(0.0, 15.0));
      },
      onResult: (result) {
        if (!mounted) return;
        String spoken = result.recognizedWords.trim();
        if (spoken.isEmpty) return;

        setState(() => _currentStatusText = spoken);
        
        // Add to Stream Buffer (keep only last ~15 words to avoid memory pollution)
        List<String> words = spoken.split(' ');
        if (words.length > 15) words = words.sublist(words.length - 15);
        _circularBuffer = words.join(' ');

        if (_pendingPlate != null) {
          String? carType = SheekhaFullEngine.extractVehicleType(spoken);
          if (carType != null) {
            _pendingPlate!['type'] = carType;
            _pendingPlate!['raw'] = spoken;
            _commitPendingPlate();
            _circularBuffer = ''; // Flush buffer
            return;
          }
        }

        String? standaloneType = SheekhaFullEngine.extractVehicleType(spoken);
        if (standaloneType != null && _records.isNotEmpty) {
          if (_records[0]['type'] == 'ملاكي' || _records[0]['type'] == '-') {
            setState(() { _records[0]['type'] = standaloneType; _saveData(); });
            _circularBuffer = ''; // Flush buffer
          }
        }

        var plateData = SheekhaFullEngine.parsePlateAndType(_circularBuffer);
        if (plateData != null) {
          String letters = plateData['letters']!;
          String digits = plateData['digits']!;
          String carType = plateData['type']!;
          bool hasExplicitType = plateData['hasExplicitType'] == true;
          bool startsWithAlefOrBaa = plateData['startsWithAlefOrBaa'] == true;
          String key = '$letters-$digits';

          if (_pendingPlate != null && _pendingPlate!['key'] == key) {
            if (hasExplicitType) {
              _pendingPlate!['type'] = carType;
              _commitPendingPlate();
              _circularBuffer = ''; // Flush buffer
            }
            return;
          }

          if (_pendingPlate != null && _pendingPlate!['key'] != key) _commitPendingPlate();

          DateTime now = DateTime.now();
          bool isRecent = _cooldowns.containsKey(key) && now.difference(_cooldowns[key]!).inMilliseconds < 3000;

          if (!isRecent) {
            _cooldowns[key] = now;
            if (startsWithAlefOrBaa && !hasExplicitType) {
              _pendingPlate = {'key': key, 'letters': letters, 'digits': digits, 'type': '-', 'raw': spoken};
              _pendingTimer?.cancel();
              _pendingTimer = Timer(const Duration(milliseconds: 1500), () {
                if (mounted) { _commitPendingPlate(); _circularBuffer = ''; }
              });
            } else {
              _registerDetectedPlate(letters, digits, carType, rawSpoken: spoken);
              _circularBuffer = ''; // Flush buffer to avoid re-capturing
            }
          }
        }
      },
    );
  }

  void _registerDetectedPlate(String letters, String digits, String spokenType, {String rawSpoken = ''}) async {
    String cleanDigits = SheekhaFullEngine.normalizeDigits(digits.trim());
    String normalizedSearchLetters = SheekhaFullEngine.normalizeFlexible(letters);

    Map<String, String> match = {};
    
    // 🚀 O(1) Fast Hash-Map searching instead of Linear search
    if (_wantedDatabaseIndexed.containsKey(cleanDigits)) {
      var possibleMatches = _wantedDatabaseIndexed[cleanDigits]!;
      for (var car in possibleMatches) {
        String dbLetters = SheekhaFullEngine.normalizeFlexible(car['letters'] ?? '');
        if (dbLetters.isEmpty || dbLetters == normalizedSearchLetters) {
          match = car;
          break;
        }
      }
    }

    bool isWanted = match.isNotEmpty;
    String finalCarType = (spokenType.isNotEmpty && spokenType != '-' && spokenType != 'ملاكي')
        ? spokenType
        : (isWanted && (match['type'] ?? '').isNotEmpty ? match['type']! : '-');

    String currentCoords = _isGpsEnabled ? _currentCoordinates : '';
    if (_isGpsEnabled && currentCoords.isEmpty) {
      try {
        if (await Geolocator.isLocationServiceEnabled()) {
          var perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
            Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
            currentCoords = '${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}';
            _currentCoordinates = currentCoords;
          }
        }
      } catch (_) {}
    }

    setState(() {
      _records.insert(0, {
        'id': (_records.length + 1).toString(),
        'letters': letters,
        'digits': digits,
        'type': finalCarType,
        'district': _currentDistrict,
        'street': _currentStreet,
        'coords': currentCoords,
        'note': _selectedNote == 'بدون' ? '+' : _selectedNote,
        'status': isWanted ? 'مطلوبة' : 'مطابق',
        'owner': match['owner'] ?? 'غير محدد',
        'shassis': match['shassis'] ?? 'غير متوفر',
        'time': TimeOfDay.now().format(context),
        'rawSpoken': rawSpoken,
      });
      _saveData();
    });

    HapticFeedback.lightImpact();
    if (isWanted) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      _showWantedAlertModal(match, letters, digits);
    }
  }

  Future<void> _processExcelWithProgress(Uint8List bytes, String fileName, {required bool isWantedSheet}) async {
    ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
    ValueNotifier<int> processedNotifier = ValueNotifier<int>(0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isWantedSheet ? 'جاري بناء الفهرس السريع لملف المطلوبين...' : 'جاري استيراد السجلات السابقة...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, val, _) {
                  int percent = (val * 100).clamp(0, 100).toInt();
                  return Column(
                    children: [
                      LinearProgressIndicator(value: val > 0 ? val : null, minHeight: 10, backgroundColor: const Color(0xFF0B132B), color: const Color(0xFF06D6A0), borderRadius: BorderRadius.circular(5)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ValueListenableBuilder<int>(valueListenable: processedNotifier, builder: (context, count, _) => Text('$count سيارة', style: const TextStyle(color: Colors.grey, fontSize: 11))),
                          Text('$percent%', style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 50));
    try {
      var excel = ex.Excel.decodeBytes(bytes);
      List<Map<String, String>> extracted = [];
      List<String> targetSheets = excel.tables.keys.toList();
      if (isWantedSheet && targetSheets.contains('بيانات')) targetSheets = ['بيانات'];

      int totalRowsCount = 0;
      for (var t in targetSheets) totalRowsCount += (excel.tables[t]?.rows.length ?? 0);
      if (totalRowsCount == 0) totalRowsCount = 1;

      int currentProcessed = 0;
      for (var tableName in targetSheets) {
        var sheet = excel.tables[tableName];
        if (sheet == null || sheet.rows.isEmpty) continue;

        var headerRow = sheet.rows.first;
        int plateColIdx = 0;
        bool isExportedRasedFormat = false;

        if (headerRow.length > 1) {
          String h0 = headerRow[0]?.value?.toString().trim() ?? '';
          String h1 = headerRow[1]?.value?.toString().trim() ?? '';
          if (h0 == 'م' && (h1.contains('اللوحة') || h1.contains('اللوحه') || h1.toLowerCase().contains('plate'))) {
            plateColIdx = 1;
            isExportedRasedFormat = true;
          }
        }

        for (var row in sheet.rows.skip(1)) {
          currentProcessed++;
          if (currentProcessed % 300 == 0 || currentProcessed == totalRowsCount) {
            progressNotifier.value = (currentProcessed / totalRowsCount).clamp(0.0, 1.0);
            processedNotifier.value = extracted.length;
            await Future.delayed(Duration.zero);
          }

          if (row.isEmpty) continue;
          String cellVal(int idx) => (idx < row.length && row[idx]?.value != null) ? row[idx]!.value.toString().trim() : '';

          bool rowUsesRasedCols = isExportedRasedFormat;
          String rawPlate = cellVal(plateColIdx);
          
          if (!rowUsesRasedCols && RegExp(r'^\d{1,5}$').hasMatch(cellVal(0)) && cellVal(1).contains(RegExp(r'[\u0621-\u064A]'))) {
            String d1 = SheekhaFullEngine.normalizeDigits(cellVal(1)).replaceAll(RegExp(r'[^\d]'), '');
            if (d1.length >= 3) {
              rowUsesRasedCols = true;
              rawPlate = cellVal(1);
            }
          }

          if (rawPlate.isEmpty || rawPlate == 'اللوحة' || rawPlate == 'اللوحه') continue;

          String normalizedPlate = SheekhaFullEngine.normalizeDigits(rawPlate);
          String digits = normalizedPlate.replaceAll(RegExp(r'[^\d]'), '');
          String letters = normalizedPlate.replaceAll(RegExp(r'[\d]'), '').trim();
          if (letters.isNotEmpty && !letters.contains(' ') && letters.length <= 3) letters = letters.split('').join(' ');

          if (digits.length >= 3) {
            if (isWantedSheet) {
              extracted.add({
                'letters': letters,
                'digits': digits,
                'type': rowUsesRasedCols ? cellVal(3) : cellVal(1),
                'owner': rowUsesRasedCols ? cellVal(7) : cellVal(2),
                'shassis': rowUsesRasedCols ? cellVal(6) : cellVal(3),
                'status': 'مطلوبة'
              });
            } else {
              extracted.add({
                'id': (_records.length + extracted.length + 1).toString(),
                'letters': letters,
                'digits': digits,
                'type': rowUsesRasedCols ? cellVal(3) : cellVal(1),
                'district': rowUsesRasedCols && cellVal(4).isNotEmpty ? cellVal(4) : _currentDistrict,
                'street': rowUsesRasedCols && cellVal(5).isNotEmpty ? cellVal(5) : _currentStreet,
                'coords': _isGpsEnabled ? _currentCoordinates : '',
                'owner': rowUsesRasedCols ? cellVal(7) : cellVal(2),
                'shassis': rowUsesRasedCols ? cellVal(6) : cellVal(3),
                'note': rowUsesRasedCols && cellVal(9).isNotEmpty ? cellVal(9) : 'سجل سابق',
                'status': rowUsesRasedCols && cellVal(2).isNotEmpty ? cellVal(2) : 'مطابق',
                'time': rowUsesRasedCols && cellVal(10).isNotEmpty ? cellVal(10) : 'سابق',
              });
            }
          }
        }
      }

      progressNotifier.value = 1.0;
      processedNotifier.value = extracted.length;
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) Navigator.pop(context);

      setState(() {
        if (isWantedSheet) {
          // 🚀 بناء الفهرس اللحظي عند رفع الشيت لضمان سرعة البحث الفائقة
          _wantedDatabaseIndexed.clear();
          _totalWantedCount = extracted.length;
          for (var car in extracted) {
            String d = SheekhaFullEngine.normalizeDigits(car['digits'] ?? '');
            if (_wantedDatabaseIndexed[d] == null) _wantedDatabaseIndexed[d] = [];
            _wantedDatabaseIndexed[d]!.add(car);
          }
          _wantedFileName = '$fileName (${extracted.length})';
        } else {
          _records.addAll(extracted);
          _appendFileName = fileName;
        }
        _saveData();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isWantedSheet ? 'تم فهرسة واستخراج ${extracted.length} سيارة مطلوبة بنجاح!' : 'تم استيراد ${extracted.length} سجل بنجاح!', textDirection: TextDirection.rtl), backgroundColor: const Color(0xFF06D6A0), duration: const Duration(seconds: 4)));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _pickAndParseWantedDatabaseFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv']);
    if (result != null && result.files.single.path != null) {
      var bytes = File(result.files.single.path!).readAsBytesSync();
      await _processExcelWithProgress(bytes, result.files.single.name, isWantedSheet: true);
    }
  }

  Future<void> _pickAndAppendExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv']);
    if (result != null && result.files.single.path != null) {
      var bytes = File(result.files.single.path!).readAsBytesSync();
      await _processExcelWithProgress(bytes, result.files.single.name, isWantedSheet: false);
    }
  }

  Future<void> _exportExcelDirectlyToDownloads() async {
    try {
      await Permission.storage.request();
      var excel = ex.Excel.createExcel();
      ex.Sheet sheet = excel['سجلات_الرصد'];
      excel.delete('Sheet1');
      sheet.appendRow([
        ex.TextCellValue('م'), ex.TextCellValue('اللوحة'), ex.TextCellValue('الحالة'), ex.TextCellValue('النوع'),
        ex.TextCellValue('الحي'), ex.TextCellValue('الشارع'), ex.TextCellValue('رقم الشاص'),
        ex.TextCellValue('البنك / الجهة'), ex.TextCellValue('رابط الخريطة'), ex.TextCellValue('ملاحظات'), ex.TextCellValue('الوقت'),
      ]);
      for (var r in _records) {
        String coords = r['coords'] ?? '';
        String mapLink = coords.isNotEmpty ? 'https://maps.google.com/?q=$coords' : 'غير متوفر';
        sheet.appendRow([
          ex.TextCellValue(r['id'] ?? ''), ex.TextCellValue('${r['letters']} ${r['digits']}'),
          ex.TextCellValue(r['status'] ?? ''), ex.TextCellValue(r['type'] ?? ''),
          ex.TextCellValue(r['district'] ?? ''), ex.TextCellValue(r['street'] ?? ''),
          ex.TextCellValue(r['shassis'] ?? 'غير متوفر'), ex.TextCellValue(r['owner'] ?? 'غير متوفر'),
          ex.TextCellValue(mapLink), ex.TextCellValue(r['note'] ?? ''), ex.TextCellValue(r['time'] ?? ''),
        ]);
      }
      Directory downloadDir = Directory('/storage/emulated/0/Download');
      if (!downloadDir.existsSync()) downloadDir = await Directory('/storage/emulated/0/Downloads').create(recursive: true);
      DateTime now = DateTime.now();
      String dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour}${now.minute}';
      String safeDistrict = _currentDistrict.replaceAll(RegExp(r'[^\w\s\u0621-\u064A]'), '_').trim();
      if (safeDistrict.isEmpty) safeDistrict = 'Rased';
      String fileName = 'Rased_${safeDistrict}_$dateStr.xlsx';
      File file = File('${downloadDir.path}/$fileName');
      await file.writeAsBytes(excel.save()!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ شيت "$fileName" في مجلد Download بنجاح!', textDirection: TextDirection.rtl), backgroundColor: const Color(0xFF06D6A0), duration: const Duration(seconds: 4)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
    }
  }

  void _editRecordManually(int index) {
    var rec = _records[index];
    TextEditingController letCtrl = TextEditingController(text: rec['letters'] ?? '');
    TextEditingController digCtrl = TextEditingController(text: rec['digits'] ?? '');
    TextEditingController typCtrl = TextEditingController(text: rec['type'] ?? '');
    String rawSpoken = rec['rawSpoken'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('تعديل السجل وتدريب الذكاء الصوتي', style: TextStyle(color: Color(0xFF06D6A0), fontSize: 16), textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rawSpoken.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: const Color(0xFF0B132B), borderRadius: BorderRadius.circular(8)),
                  child: Text('المنطوق الأصلي: "$rawSpoken"', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              TextField(controller: letCtrl, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), decoration: const InputDecoration(labelText: 'الحروف الصحيحة (مثال: ن و ي)', labelStyle: TextStyle(color: Colors.grey))),
              const SizedBox(height: 6),
              TextField(controller: digCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), decoration: const InputDecoration(labelText: 'الأرقام الصحيحة (مثال: 715)', labelStyle: TextStyle(color: Colors.grey))),
              const SizedBox(height: 6),
              TextField(controller: typCtrl, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'نوع السيارة (مثال: كيا / نقل)', labelStyle: TextStyle(color: Colors.grey))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)),
            onPressed: () async {
              String newLettersStr = letCtrl.text.trim();
              if (newLettersStr.isNotEmpty && !newLettersStr.contains(' ') && newLettersStr.length <= 3) newLettersStr = newLettersStr.split('').join(' ');
              if (rawSpoken.isNotEmpty) await SheekhaFullEngine.saveLearnedMapping(rawSpoken, newLettersStr, digCtrl.text.trim(), typCtrl.text.trim());
              setState(() {
                rec['letters'] = newLettersStr;
                rec['digits'] = digCtrl.text.trim();
                rec['type'] = typCtrl.text.trim();
              });
              _saveData();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('حفظ وتثبيت بالذاكرة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _sendWantedToWhatsApp() async {
    List<Map<String, String>> toSend = _records.where((r) => r['status'] == 'مطلوبة' && _selectedWantedIds.contains(r['id'])).toList();
    if (toSend.isEmpty) toSend = _records.where((r) => r['status'] == 'مطلوبة').toList();
    if (toSend.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد سيارات مطلوبة لإرسالها')));
      return;
    }
    StringBuffer buffer = StringBuffer();
    buffer.writeln('🚨 *تقرير رصد سيارات مطلوبة - تطبيق RASED*');
    buffer.writeln('-----------------------------------');
    for (var car in toSend) {
      buffer.writeln('🚗 لوحة: ${car['letters']} ${car['digits']}');
      buffer.writeln('📋 النوع: ${car['type']}');
      buffer.writeln('🔑 الشاص: ${car['shassis']}');
      buffer.writeln('🏦 البنك / الجهة: ${car['owner']}');
      buffer.writeln('📍 الموقع: ${car['district']} - ${car['street']}');
      if ((car['coords'] ?? '').isNotEmpty) buffer.writeln('🗺 الخريطة: https://maps.google.com/?q=${car['coords']}');
      buffer.writeln('⏱ الوقت: ${car['time']}');
      buffer.writeln('-----------------------------------');
    }
    String phone = _savedWhatsAppPhone.replaceAll(RegExp(r'[^\d]'), '');
    String encodedText = Uri.encodeComponent(buffer.toString());
    try {
      if (await canLaunchUrl(Uri.parse('whatsapp://send?phone=$phone&text=$encodedText'))) await launchUrl(Uri.parse('whatsapp://send?phone=$phone&text=$encodedText'), mode: LaunchMode.externalApplication);
      else await launchUrl(Uri.parse('https://api.whatsapp.com/send?phone=$phone&text=$encodedText'), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _executeManualSearchAction() {
    String query = _manualSearchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() => _manualSearchResults = []);
      return;
    }
    setState(() => _isManualSearching = true);
    String normalizedQuery = SheekhaFullEngine.normalizeFlexible(query);
    List<Map<String, String>> matched = [];
    
    // البحث اليدوي في الفهرس
    _wantedDatabaseIndexed.values.forEach((list) {
      for (var car in list) {
        if (SheekhaFullEngine.normalizeFlexible('${car['letters']}${car['digits']} ${car['type']} ${car['owner']} ${car['shassis']}').contains(normalizedQuery)) {
          matched.add({'id': 'مطلوبة', 'letters': car['letters'] ?? '', 'digits': car['digits'] ?? '', 'type': car['type'] ?? '-', 'district': 'شيت المطلوبين', 'street': car['owner'] ?? 'مطلوبة', 'coords': '', 'shassis': car['shassis'] ?? 'غير متوفر', 'note': '⚠️ مسجلة في شيت المطلوبين', 'status': 'مطلوبة', 'time': 'قاعدة البيانات'});
        }
      }
    });

    for (var car in _records) {
      if (SheekhaFullEngine.normalizeFlexible('${car['letters']}${car['digits']} ${car['type']}').contains(normalizedQuery)) {
        if (!matched.any((m) => m['digits'] == car['digits'] && m['letters'] == car['letters'])) matched.add(car);
      }
    }
    
    String cleanDigitsOnly = SheekhaFullEngine.normalizeDigits(query.replaceAll(RegExp(r'[^\d]'), ''));
    if (cleanDigitsOnly.length >= 3 && _wantedDatabaseIndexed.containsKey(cleanDigitsOnly)) {
      var exactMatch = _wantedDatabaseIndexed[cleanDigitsOnly]!.firstWhere((w) => SheekhaFullEngine.normalizeDigits((w['digits'] ?? '').trim()) == cleanDigitsOnly && (normalizedQuery.isEmpty || normalizedQuery.contains(SheekhaFullEngine.normalizeFlexible(w['letters'] ?? ''))), orElse: () => {});
      if (exactMatch.isNotEmpty) _registerDetectedPlate(exactMatch['letters'] ?? '', exactMatch['digits'] ?? '', exactMatch['type'] ?? '-');
    }
    setState(() {
      _manualSearchResults = matched;
      _isManualSearching = false;
    });
  }

  Future<void> _fetchGPSLocation() async {
    if (!_isGpsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الـ GPS معطل من الإعدادات، يرجى تفعيله أولاً')));
      return;
    }
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() => _currentCoordinates = '${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS Signal Captured ✓'), backgroundColor: Color(0xFF06D6A0)));
  }

  void _openGoogleMaps(String coords) async {
    if (coords.isEmpty) return;
    try {
      if (await canLaunchUrl(Uri.parse('geo:$coords?q=$coords'))) await launchUrl(Uri.parse('geo:$coords?q=$coords'), mode: LaunchMode.externalApplication);
      else await launchUrl(Uri.parse('https://maps.google.com/?q=$coords'), mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(Uri.parse('https://maps.google.com/?q=$coords'), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedRecords = prefs.getString('rased_historical_records');
    final String? savedDb = prefs.getString('rased_wanted_db');
    
    setState(() {
      if (savedRecords != null) _records = List<Map<String, String>>.from(json.decode(savedRecords).map((x) => Map<String, String>.from(x)));
      if (savedDb != null) {
        List<Map<String, String>> flatDb = List<Map<String, String>>.from(json.decode(savedDb).map((x) => Map<String, String>.from(x)));
        _wantedDatabaseIndexed.clear();
        _totalWantedCount = flatDb.length;
        for (var car in flatDb) {
          String d = SheekhaFullEngine.normalizeDigits(car['digits'] ?? '');
          if (_wantedDatabaseIndexed[d] == null) _wantedDatabaseIndexed[d] = [];
          _wantedDatabaseIndexed[d]!.add(car);
        }
      }
      _savedWhatsAppPhone = prefs.getString('rased_wa_phone') ?? _savedWhatsAppPhone;
      _wantedFileName = prefs.getString('rased_wanted_name') ?? _wantedFileName;
      _isGpsEnabled = prefs.getBool('rased_gps_enabled') ?? _isGpsEnabled;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('rased_historical_records', json.encode(_records));
    
    List<Map<String, String>> flatDb = [];
    _wantedDatabaseIndexed.values.forEach((list) => flatDb.addAll(list));
    prefs.setString('rased_wanted_db', json.encode(flatDb));
    
    prefs.setString('rased_wa_phone', _savedWhatsAppPhone);
    prefs.setString('rased_wanted_name', _wantedFileName);
    prefs.setBool('rased_gps_enabled', _isGpsEnabled);
  }

  void _showWantedAlertModal(Map<String, String> car, String letters, String digits) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.redAccent, width: 3)),
        title: const Text('🚨 تم رصد سيارة مطلوبة!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)), child: Text('$letters $digits', textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87))),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text((car['type'] ?? '').isNotEmpty ? car['type']! : '-', textAlign: TextAlign.right, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold))), const Text('النوع / الموديل: ', style: TextStyle(color: Colors.grey, fontSize: 13))]),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text((car['owner'] ?? '').isNotEmpty ? car['owner']! : 'غير متوفر', textAlign: TextAlign.right, style: const TextStyle(color: Colors.indigo, fontSize: 13, fontWeight: FontWeight.bold))), const Text('الجهة الطالبة / البنك: ', style: TextStyle(color: Colors.grey, fontSize: 13))]),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text((car['shassis'] ?? '').isNotEmpty ? car['shassis']! : 'غير متوفر', textAlign: TextAlign.right, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold))), const Text('رقم الشاصي: ', style: TextStyle(color: Colors.grey, fontSize: 13))]),
          ],
        ),
        actions: [SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () => Navigator.pop(context), child: const Text('إغلاق ومتابعة الرصد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.upload_file, color: Color(0xFF06D6A0), size: 28), onPressed: _pickAndParseWantedDatabaseFile),
        title: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [const Text('RASED', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, color: Color(0xFF06D6A0), fontSize: 18)), Text(_wantedFileName, style: const TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis)]),
        centerTitle: true,
        actions: const [SizedBox(width: 48)],
      ),
      body: _buildCurrentTabBody(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0B132B),
        selectedItemColor: const Color(0xFF06D6A0),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'فحص يدوي'),
          BottomNavigationBarItem(icon: Icon(Icons.warning_amber_rounded), label: 'المرصودة'),
          BottomNavigationBarItem(icon: Icon(Icons.app_registration), label: 'التسجيل'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'التشييك'),
        ],
      ),
    );
  }

  Widget _buildCurrentTabBody() {
    switch (_currentIndex) {
      case 0: return _buildSettingsTab();
      case 1: return _buildManualSearchTab();
      case 2: return _buildWantedRecordsTab();
      case 3: return _buildRegistrationTab();
      case 4: default: return _buildCheckingTab();
    }
  }

  Widget _buildCheckingTab() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(20), border: Border.all(color: _isListening ? const Color(0xFF06D6A0) : Colors.transparent, width: 1.5)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (_isListening ? const Color(0xFF06D6A0) : Colors.grey).withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text(_isListening ? 'يستمع الآن' : 'متوقف', style: TextStyle(color: _isListening ? const Color(0xFF06D6A0) : Colors.grey, fontSize: 12))),
                    Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(_currentStatusText, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)))),
                    GestureDetector(onTap: _toggleLiveListening, child: CircleAvatar(radius: 26, backgroundColor: _isListening ? const Color(0xFF06D6A0) : Colors.redAccent, child: Icon(_isListening ? Icons.mic : Icons.mic_off, color: Colors.black, size: 28))),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(height: 35, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(30, (index) {
                  double baseHeight = 6.0;
                  double dynamicWave = _isListening ? baseHeight + (sin(index + _soundLevel) * _soundLevel * 2.2).abs() : baseHeight;
                  return AnimatedContainer(duration: const Duration(milliseconds: 60), width: 3.5, height: dynamicWave.clamp(5.0, 35.0), decoration: BoxDecoration(color: _isListening ? const Color(0xFF06D6A0) : Colors.grey.shade700, borderRadius: BorderRadius.circular(2)));
                }))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('السجلات: ${_records.length}', style: const TextStyle(color: Colors.grey, fontSize: 13)), const Text('اضغط على اللوحة أو النوع لتعديلهما', style: TextStyle(color: Color(0xFF06D6A0), fontSize: 11))]),
          const SizedBox(height: 8),
          Expanded(child: _buildRecordsListView(_records)),
        ],
      ),
    );
  }

  Widget _buildRegistrationTab() {
    bool hasGPS = _isGpsEnabled && _currentCoordinates.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _controlCard('ملاحظات', _selectedNote, Icons.edit, Colors.amber, _showNotesMenu)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: _showStreetDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(color: const Color(0xFF0B132B), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF06D6A0).withOpacity(0.6))),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (!_isGpsEnabled) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الـ GPS معطل من الإعدادات')));
                                      else if (hasGPS) {
                                        Clipboard.setData(ClipboardData(text: _currentCoordinates));
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied GPS: $_currentCoordinates'), backgroundColor: const Color(0xFF06D6A0)));
                                      } else _fetchGPSLocation();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: hasGPS ? const Color(0xFF06D6A0) : Colors.transparent, borderRadius: BorderRadius.circular(4)),
                                      child: Row(children: [Icon(Icons.my_location, color: hasGPS ? Colors.black : const Color(0xFF06D6A0), size: 12), Text(hasGPS ? ' GPS ✓' : (_isGpsEnabled ? ' GPS' : ' GPS ✕'), style: TextStyle(color: hasGPS ? Colors.black : const Color(0xFF06D6A0), fontSize: 9, fontWeight: FontWeight.bold))]),
                                    ),
                                  ),
                                  const Text('الشارع', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(_currentStreet, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: _controlCard('الحي', _currentDistrict, Icons.folder, Colors.blueAccent, _showDistrictMenu)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)), onPressed: _exportExcelDirectlyToDownloads, icon: const Icon(Icons.download, color: Colors.black, size: 18), label: const Text('تصدير إكسيل', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF06D6A0))), onPressed: _pickAndAppendExcelFile, icon: const Icon(Icons.add_to_photos, color: Color(0xFF06D6A0), size: 18), label: const Text('استيراد شيت', style: TextStyle(color: Color(0xFF06D6A0), fontSize: 11)))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildRecordsListView(_records)),
        ],
      ),
    );
  }

  Widget _buildWantedRecordsTab() {
    List<Map<String, String>> wantedList = _records.where((r) => r['status'] == 'مطلوبة').toList();
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: _showSetWhatsAppPhoneDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFF0B132B), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.edit, color: Color(0xFF06D6A0), size: 16),
                        Row(children: [Text(_savedWhatsAppPhone, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), textDirection: TextDirection.ltr), const SizedBox(width: 8), const Icon(Icons.phone, color: Color(0xFF06D6A0), size: 18), const SizedBox(width: 4), const Text('رقم الإرسال:', style: TextStyle(color: Colors.grey, fontSize: 12))]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _sendWantedToWhatsApp, icon: const Icon(Icons.send, color: Colors.white, size: 20), label: const Text('إرسال للواتساب', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: wantedList.isEmpty
                ? const Center(child: Text('لا توجد سيارات مطلوبة مرصودة حتى الآن', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: wantedList.length,
                    itemBuilder: (context, index) {
                      final car = wantedList[index];
                      String id = car['id'] ?? '';
                      bool isSelected = _selectedWantedIds.contains(id);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Checkbox(value: isSelected, activeColor: const Color(0xFF06D6A0), onChanged: (val) => setState(() => val == true ? _selectedWantedIds.add(id) : _selectedWantedIds.remove(id))),
                            InkWell(onTap: () => _openGoogleMaps(car['coords'] ?? ''), child: const Icon(Icons.map, color: Color(0xFF06D6A0), size: 24)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${car['letters']} ${car['digits']}', style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('النوع: ${car['type']} | الشارع: ${car['street']}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('الجهة/البنك: ${car['owner']}', style: const TextStyle(color: Colors.amber, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showSetWhatsAppPhoneDialog() {
    TextEditingController phoneCtrl = TextEditingController(text: _savedWhatsAppPhone);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('تثبيت رقم الواتساب للتقارير', style: TextStyle(color: Color(0xFF06D6A0)), textAlign: TextAlign.center),
        content: TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: '00201155661920')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () { setState(() => _savedWhatsAppPhone = phoneCtrl.text.trim()); _saveData(); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)), child: const Text('تثبيت الرقم', style: TextStyle(color: Colors.black))),
        ],
      ),
    );
  }

  Widget _buildManualSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _isManualSearching ? null : _executeManualSearchAction,
                  icon: _isManualSearching ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.search, color: Colors.black, size: 18),
                  label: const Text('بحث', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _manualSearchCtrl,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _executeManualSearchAction(),
                    decoration: const InputDecoration(hintText: 'اكتب حروف أو أرقام السيارة...', hintStyle: TextStyle(color: Colors.grey, fontSize: 12), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _manualSearchResults.isEmpty ? const Center(child: Text('اكتب كود أو رقم السيارة واضغط "بحث"', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13))) : _buildRecordsListView(_manualSearchResults)),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: const Color(0xFF1C2541),
          activeColor: const Color(0xFF06D6A0),
          secondary: const Icon(Icons.location_on, color: Color(0xFF06D6A0)),
          title: const Text('تفعيل موقع GPS عند الرصد', style: TextStyle(color: Colors.white)),
          subtitle: const Text('التقاط الإحداثيات تلقائياً وتثبيتها في الشيت', style: TextStyle(color: Colors.grey, fontSize: 11)),
          value: _isGpsEnabled,
          onChanged: (bool value) {
            setState(() { _isGpsEnabled = value; if (!value) _currentCoordinates = ''; });
            _saveData();
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: const Color(0xFF1C2541),
          leading: const Icon(Icons.support_agent, color: Color(0xFF06D6A0)),
          title: const Text('التواصل مع الدعم الفني', style: TextStyle(color: Colors.white)),
          subtitle: const Text('واتساب: 00201155661920', style: TextStyle(color: Colors.grey, fontSize: 11)),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          onTap: () async {
            try {
              if (await canLaunchUrl(Uri.parse('whatsapp://send?phone=201155661920&text=مرحباً'))) await launchUrl(Uri.parse('whatsapp://send?phone=201155661920&text=مرحباً'), mode: LaunchMode.externalApplication);
              else await launchUrl(Uri.parse('https://wa.me/201155661920?text=مرحباً'), mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
        ),
      ],
    );
  }

  Widget _buildRecordsListView(List<Map<String, String>> list) {
    if (list.isEmpty) return const Center(child: Text('لا توجد سجلات حالياً...', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final r = list[index];
        bool isWanted = r['status'] == 'مطلوبة';
        String coords = r['coords'] ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(color: isWanted ? Colors.redAccent.withOpacity(0.2) : const Color(0xFF1C2541), borderRadius: BorderRadius.circular(10), border: isWanted ? Border.all(color: Colors.redAccent) : null),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(onTap: coords.isNotEmpty ? () => _openGoogleMaps(coords) : null, child: Icon(Icons.map_outlined, color: coords.isNotEmpty ? const Color(0xFF06D6A0) : Colors.grey, size: 18)),
              InkWell(onTap: () => setState(() => list.removeAt(index)), child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18)),
              Text(r['note'] ?? '+', style: const TextStyle(color: Colors.amber, fontSize: 11)),
              Text(r['street'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              InkWell(
                onTap: () => _editRecordManually(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: isWanted ? Colors.redAccent.withOpacity(0.3) : const Color(0xFF06D6A0).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(r['type'] ?? '-', style: TextStyle(color: isWanted ? Colors.white : const Color(0xFF06D6A0), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              Icon(isWanted ? Icons.warning_amber_rounded : Icons.check_circle, color: isWanted ? Colors.redAccent : const Color(0xFF06D6A0), size: 18),
              InkWell(
                onTap: () => _editRecordManually(index),
                child: Text('${r['letters']} ${r['digits']}', style: TextStyle(color: isWanted ? Colors.redAccent : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _controlCard(String title, String value, IconData icon, Color borderColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(color: const Color(0xFF0B132B), borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor.withOpacity(0.6))),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                const SizedBox(width: 4),
                Icon(icon, color: borderColor, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDistrictMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2541),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._districts.map((d) => ListTile(title: Text(d, style: const TextStyle(color: Colors.white), textDirection: TextDirection.rtl), trailing: Icon(_currentDistrict == d ? Icons.check_circle : Icons.circle_outlined, color: const Color(0xFF06D6A0), size: 18), onTap: () { setState(() => _currentDistrict = d); Navigator.pop(context); })),
          const Divider(color: Colors.white24),
          ListTile(leading: const Icon(Icons.add, color: Color(0xFF06D6A0)), title: const Text('إضافة حي +', style: TextStyle(color: Color(0xFF06D6A0), fontWeight: FontWeight.bold), textDirection: TextDirection.rtl), onTap: () { Navigator.pop(context); _showAddDistrictDialog(); }),
        ],
      ),
    );
  }

  void _showAddDistrictDialog() {
    TextEditingController districtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('إضافة حي جديد', style: TextStyle(color: Color(0xFF06D6A0)), textAlign: TextAlign.center),
        content: TextField(controller: districtCtrl, autofocus: true, textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'اكتب اسم الحي الجديد...', hintStyle: TextStyle(color: Colors.grey))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () { String newD = districtCtrl.text.trim(); if (newD.isNotEmpty) { setState(() { if (!_districts.contains(newD)) _districts.add(newD); _currentDistrict = newD; }); _saveData(); } Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)), child: const Text('إضافة وتحديد', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showStreetDialog() {
    TextEditingController ctrl = TextEditingController(text: _currentStreet);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('الشارع', style: TextStyle(color: Colors.white)),
        content: TextField(controller: ctrl, textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white)),
        actions: [ElevatedButton(onPressed: () { setState(() => _currentStreet = ctrl.text.trim()); Navigator.pop(context); }, child: const Text('حفظ'))],
      ),
    );
  }

  void _showNotesMenu() {
    final notes = ['بدون', 'برحة', 'برحة يمين', 'برحة يسار', 'تحت تندة'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2541),
      builder: (context) => ListView(
        shrinkWrap: true,
        children: notes.map((n) => ListTile(title: Text(n, style: const TextStyle(color: Colors.white), textDirection: TextDirection.rtl), onTap: () { setState(() => _selectedNote = n); Navigator.pop(context); })).toList(),
      ),
    );
  }
}
