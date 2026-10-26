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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B132B),
        primaryColor: const Color(0xFF06D6A0),
      ),
      home: const SheekhaHomeScreen(),
    );
  }
}

// محرك التدفق اللحظي للوحات
class LiveStreamPlateEngine {
  static final Map<String, String> validLetters = {
    'الف': 'أ', 'ألف': 'أ', 'الأف': 'أ', 'الاف': 'أ', 'أليف': 'أ', 'ا': 'أ', 'أ': 'أ', 'إ': 'أ', 'ء': 'أ',
    'باء': 'ب', 'با': 'ب', 'به': 'ب', 'بي': 'ب', 'بت': 'ب', 'الباء': 'ب', 'اب': 'ب', 'ب': 'ب',
    'تاء': 'ت', 'تا': 'ت', 'ته': 'ت', 'تي': 'ت', 'التاء': 'ت', 'ات': 'ت', 'ت': 'ت',
    'ثاء': 'ث', 'ثا': 'ث', 'ثه': 'ث', 'الثاء': 'ث', 'اث': 'ث', 'ث': 'ث',
    'جيم': 'ج', 'جا': 'ج', 'جه': 'ج', 'جي': 'ج', 'الجيم': 'ج', 'ديم': 'ج', 'ج': 'ج',
    'حاء': 'ح', 'حا': 'ح', 'حه': 'ح', 'حي': 'ح', 'الحاء': 'ح', 'اح': 'ح', 'ح': 'ح',
    'خاء': 'خ', 'خا': 'خ', 'خه': 'خ', 'خي': 'خ', 'الخاء': 'خ', 'اخ': 'خ', 'خ': 'خ',
    'دال': 'د', 'دا': 'د', 'ده': 'د', 'دي': 'د', 'الدال': 'د', 'اد': 'د', 'د': 'د',
    'ذال': 'ذ', 'ذا': 'ذ', 'ذه': 'ذ', 'الذال': 'ذ', 'ذ': 'ذ',
    'راء': 'ر', 'را': 'ر', 'ره': 'ر', 'ري': 'ر', 'الراء': 'ر', 'ار': 'ر', 'ر': 'ر',
    'زين': 'ز', 'زا': 'ز', 'زه': 'ز', 'زي': 'ز', 'الزين': 'ز', 'زاي': 'ز', 'ز': 'ز',
    'سين': 'س', 'سا': 'س', 'سه': 'س', 'سي': 'س', 'السين': 'س', 'س': 'س',
    'شين': 'ش', 'شا': 'ش', 'شه': 'ش', 'شي': 'ش', 'الشين': 'ش', 'ش': 'ش',
    'صاد': 'ص', 'صا': 'ص', 'صه': 'ص', 'الصاد': 'ص', 'ص': 'ص',
    'ضاد': 'ض', 'ضا': 'ض', 'ضه': 'ض', 'الضاد': 'ض', 'ض': 'ض',
    'طاء': 'ط', 'طا': 'ط', 'طه': 'ط', 'طي': 'ط', 'الطاء': 'ط', 'ط': 'ط',
    'ظاء': 'ظ', 'ظا': 'ظ', 'ظه': 'ظ', 'الظاء': 'ظ', 'ظ': 'ظ',
    'عين': 'ع', 'عا': 'ع', 'عه': 'ع', 'عي': 'ع', 'العين': 'ع', 'ع': 'ع',
    'غين': 'غ', 'غاء': 'غ', 'غا': 'غ', 'غه': 'غ', 'الغين': 'غ', 'غ': 'غ',
    'فاء': 'ف', 'فا': 'ف', 'فه': 'ف', 'في': 'ف', 'الفاء': 'ف', 'ف': 'ف',
    'قاف': 'ق', 'قا': 'ق', 'قه': 'ق', 'قي': 'ق', 'القاف': 'ق', 'قف': 'ق', 'ق': 'ق',
    'كاف': 'ك', 'كا': 'ك', 'كه': 'ك', 'كي': 'ك', 'الكاف': 'ك', 'ك': 'ك',
    'لام': 'ل', 'لا': 'ل', 'له': 'ل', 'لي': 'ل', 'اللام': 'ل', 'ل': 'ل',
    'ميم': 'م', 'مين': 'م', 'ما': 'م', 'مه': 'م', 'الميم': 'م', 'م': 'م',
    'نون': 'ن', 'نا': 'ن', 'نه': 'ن', 'ني': 'ن', 'النون': 'ن', 'ن': 'ن',
    'هاء': 'ه', 'ها': 'ه', 'هه': 'ه', 'الهاء': 'ه', 'هـ': 'ه', 'ه': 'ه',
    'واو': 'و', 'وا': 'و', 'وه': 'و', 'الواو': 'و', 'و': 'و',
    'ياء': 'ي', 'يا': 'ي', 'يه': 'ي', 'الياء': 'ي', 'ى': 'ي', 'ي': 'ي',
  };

  static final Map<String, List<String>> compoundDict = {
    'واوقاف': ['و', 'ق'], 'أوقاف': ['و', 'ق'], 'اوقاف': ['و', 'ق'], 'وقاف': ['و', 'ق'],
    'واوساط': ['و', 'ص'], 'أوساط': ['و', 'ص'], 'اوساط': ['و', 'ص'], 'وساط': ['و', 'ص'],
    'نوعين': ['ن', 'ع'], 'نوعان': ['ن', 'ع'], 'نوع': ['ن', 'ع'],
    'نهاء': ['ن', 'ه'], 'نها': ['ن', 'ه'], 'منهاء': ['م', 'ن', 'ه'], 'منها': ['م', 'ن', 'ه'],
    'تقديم': ['ك', 'ه', 'ج'], 'كهج': ['ك', 'ه', 'ج'],
    'خطه': ['خ', 'ط'], 'خطة': ['خ', 'ط'], 'خطف': ['خ', 'ط', 'ف'],
    'افلام': ['ل', 'ق'], 'أفلام': ['ل', 'ق'], 'فلام': ['ل', 'ق'],
    'لمن': ['ل', 'م', 'ن'], 'لم': ['ل', 'م'], 'من': ['م', 'ن'], 'منع': ['م', 'ن', 'ع'],
    'منوعين': ['م', 'ن', 'ع'], 'وعج': ['و', 'ع', 'ج'], 'لفق': ['ل', 'ف', 'ق'],
    'عقب': ['ع', 'ق', 'ب'], 'ابت': ['أ', 'ب', 'ت'],
    'بهاء': ['ب', 'ه'], 'مها': ['م', 'ه'], 'سها': ['س', 'ه'],
  };

  static final Map<String, String> digitsDict = {
    'صفر': '0', 'زيرو': '0',
    'واحد': '1', 'واحده': '1', 'واحدة': '1', 'حد': '1',
    'اتنين': '2', 'اثنين': '2', 'إثنين': '2', 'تنين': '2',
    'تلاته': '3', 'ثلاثة': '3', 'تلاتة': '3', 'تلات': '3', 'ثلاث': '3', 'تلت': '3',
    'اربعة': '4', 'اربعه': '4', 'اربع': '4', 'أربع': '4',
    'خمسه': '5', 'خمسة': '5', 'خمس': '5',
    'سته': '6', 'ستة': '6', 'ست': '6',
    'سبعه': '7', 'سبعة': '7', 'سبع': '7',
    'تمانيه': '8', 'ثمانية': '8', 'ثمانيه': '8', 'تمن': '8', 'تمان': '8',
    'تسعه': '9', 'تسعة': '9', 'تسع': '9',
  };

  // تفكيك لحظي مباشر وتحويل فوري إلى قائمة رموز
  static List<String> tokenize(String text) {
    if (text.trim().isEmpty) return [];

    String cleaned = _cleanNumbers(text);
    List<String> raw = cleaned.split(RegExp(r'\s+'));
    List<String> tokens = [];

    for (String r in raw) {
      String w = r.replaceAll(RegExp(r'[^\u0621-\u064A0-9]'), '');
      if (w.isEmpty) continue;

      if (digitsDict.containsKey(w)) {
        tokens.add(digitsDict[w]!);
      } else if (RegExp(r'^\d+$').hasMatch(w)) {
        for (int i = 0; i < w.length; i++) tokens.add(w[i]);
      } else if (compoundDict.containsKey(w)) {
        tokens.addAll(compoundDict[w]!);
      } else if (validLetters.containsKey(w)) {
        tokens.add(validLetters[w]!);
      } else {
        for (int i = 0; i < w.length; i++) {
          String ch = w[i];
          if (ch == 'ة' || (ch == 'ه' && i == w.length - 1)) continue;
          if (RegExp(r'[\u0621-\u064A]').hasMatch(ch)) {
            tokens.add(ch == 'أ' || ch == 'إ' || ch == 'آ' ? 'أ' : ch);
          }
        }
      }
    }
    return tokens;
  }

  // التقاط مباشر للوحات الكاملة أثناء الحديث
  static List<Map<String, String>> extractPlatesDirect(List<String> tokens) {
    List<Map<String, String>> plates = [];
    List<String> letters = [];
    String digits = '';

    for (String t in tokens) {
      if (RegExp(r'^\d$').hasMatch(t)) {
        digits += t;
      } else if (RegExp(r'^[\u0621-\u064A]$').hasMatch(t)) {
        if (digits.length >= 3 && letters.length >= 2) {
          plates.add({
            'letters': letters.take(3).join(' '),
            'digits': digits.substring(0, digits.length > 4 ? 4 : digits.length),
          });
          letters = [t];
          digits = '';
        } else {
          if (letters.length < 3) letters.add(t);
        }
      }
    }

    if (letters.length >= 2 && digits.length >= 3) {
      plates.add({
        'letters': letters.take(3).join(' '),
        'digits': digits.substring(0, digits.length > 4 ? 4 : digits.length),
      });
    }

    return plates;
  }

  static String _cleanNumbers(String input) {
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < ar.length; i++) {
      input = input.replaceAll(ar[i], en[i]);
    }
    return input;
  }
}

class SheekhaHomeScreen extends StatefulWidget {
  const SheekhaHomeScreen({super.key});

  @override
  State<SheekhaHomeScreen> createState() => _SheekhaHomeScreenState();
}

class _SheekhaHomeScreenState extends State<SheekhaHomeScreen> {
  int _currentIndex = 3;
  bool _isListening = false;
  String _currentStatusText = 'اضغط الميكروفون لبدء الرصد المباشر...';
  double _soundLevel = 0.0;

  final Map<String, DateTime> _cooldowns = {};
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;

  final List<String> _districts = ['الروضة', 'السلام', 'المنيل', 'المعادي'];
  String _currentDistrict = 'الروضة';
  String _currentStreet = 'ض 1';
  String _currentCoordinates = '';
  String _selectedNote = 'بدون';
  String _excelFileName = 'لم يتم رفع ملف إكسيل';

  List<Map<String, String>> _records = [];
  List<Map<String, String>> _wantedDatabase = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _initEngine();
  }

  Future<void> _initEngine() async {
    var micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() => _currentStatusText = 'يرجى تفعيل إذن الميكروفون من الإعدادات');
      return;
    }

    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && _isListening && mounted) {
            _restartListeningSafely();
          }
        },
        onError: (error) {
          if (_isListening && mounted) {
            _restartListeningSafely();
          }
        },
      );

      setState(() {
        _speechEnabled = available;
        _currentStatusText = available
            ? 'الميكروفون مستعد للرصد المباشر واللحظي'
            : 'تأكد من تفعيل خدمات التعرف الصوتي بالجهاز';
      });
    } catch (e) {
      setState(() => _currentStatusText = 'خطأ في الميكروفون: $e');
    }
  }

  void _restartListeningSafely() {
    if (!_isListening) return;
    Future.microtask(() {
      if (_isListening && mounted && !_speech.isListening) {
        _startListeningSession();
      }
    });
  }

  void _toggleLiveListening() async {
    if (_isListening) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
        _currentStatusText = 'تم إيقاف الاستماع';
      });
      await _speech.stop();
    } else {
      if (!_speechEnabled) {
        await _initEngine();
        if (!_speechEnabled) return;
      }
      setState(() {
        _isListening = true;
        _currentStatusText = 'الرصد المباشر نشط... انطق اللوحات بطلاقة';
      });
      _startListeningSession();
    }
  }

  void _startListeningSession() async {
    if (!_isListening) return;

    await _speech.listen(
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
      listenFor: const Duration(hours: 2),
      pauseFor: const Duration(minutes: 5),
      onSoundLevelChange: (level) {
        if (mounted) setState(() => _soundLevel = level.clamp(0.0, 15.0));
      },
      onResult: (result) {
        if (!mounted) return;
        String spoken = result.recognizedWords.trim();
        if (spoken.isEmpty) return;

        setState(() => _currentStatusText = spoken);

        // تحليل فوري مباشر على الكلمات اللحظية بدون مؤقت وبدون انتظار صمت
        List<String> tokens = LiveStreamPlateEngine.tokenize(spoken);
        List<Map<String, String>> detected = LiveStreamPlateEngine.extractPlatesDirect(tokens);

        for (var p in detected) {
          String letters = p['letters']!;
          String digits = p['digits']!;
          String key = '$letters-$digits';

          DateTime now = DateTime.now();
          bool isRecent = _cooldowns.containsKey(key) &&
              now.difference(_cooldowns[key]!).inSeconds < 4;

          if (!isRecent) {
            _cooldowns[key] = now;
            _registerDetectedPlate(letters, digits);
          }
        }
      },
    );
  }

  void _registerDetectedPlate(String letters, String digits) {
    String cleanDigits = digits.trim();
    String cleanLetters = letters.replaceAll(' ', '');

    var match = _wantedDatabase.firstWhere(
      (car) {
        String dbDigits = (car['digits'] ?? '').trim();
        String dbLetters = (car['letters'] ?? '').replaceAll(' ', '');
        return dbDigits == cleanDigits && (dbLetters.isEmpty || dbLetters == cleanLetters);
      },
      orElse: () => {},
    );

    bool isWanted = match.isNotEmpty;

    setState(() {
      _records.insert(0, {
        'id': (_records.length + 1).toString(),
        'letters': letters,
        'digits': digits,
        'type': isWanted ? (match['type'] ?? 'ملاكي') : 'ملاكي',
        'district': _currentDistrict,
        'street': _currentStreet,
        'coords': _currentCoordinates,
        'note': _selectedNote == 'بدون' ? '+' : _selectedNote,
        'status': isWanted ? 'مطلوبة' : 'مطابق',
        'time': TimeOfDay.now().format(context),
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

  Future<void> _fetchGPSLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تفعيل خدمة الموقع (GPS) بالهاتف', textDirection: TextDirection.rtl)),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentCoordinates = '${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}';
      _currentStreet = 'GPS ($_currentCoordinates)';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تثبيت الإحداثيات: $_currentCoordinates', textDirection: TextDirection.rtl), backgroundColor: const Color(0xFF06D6A0)),
    );
  }

  void _openGoogleMaps(String coords) async {
    if (coords.isEmpty) return;
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$coords');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedRecords = prefs.getString('sheekha_historical_records');
    final String? savedDb = prefs.getString('sheekha_wanted_db');
    final String? savedFile = prefs.getString('sheekha_excel_name');

    setState(() {
      if (savedRecords != null) {
        _records = List<Map<String, String>>.from(
            json.decode(savedRecords).map((x) => Map<String, String>.from(x)));
      }
      if (savedDb != null) {
        _wantedDatabase = List<Map<String, String>>.from(
            json.decode(savedDb).map((x) => Map<String, String>.from(x)));
      }
      if (savedFile != null) _excelFileName = savedFile;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('sheekha_historical_records', json.encode(_records));
    prefs.setString('sheekha_wanted_db', json.encode(_wantedDatabase));
    prefs.setString('sheekha_excel_name', _excelFileName);
  }

  Future<void> _pickAndParseExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      var bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = ex.Excel.decodeBytes(bytes);
      List<Map<String, String>> extractedCars = [];

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet != null) {
          for (var row in sheet.rows.skip(1)) {
            if (row.isNotEmpty && row[0] != null) {
              String col0 = row[0]?.value?.toString() ?? '';
              String col1 = row.length > 1 ? (row[1]?.value?.toString() ?? '') : '';
              String col2 = row.length > 2 ? (row[2]?.value?.toString() ?? 'ملاكي') : 'ملاكي';
              String col3 = row.length > 3 ? (row[3]?.value?.toString() ?? 'مطلوبة') : 'مطلوبة';

              String letters = col0;
              String digits = col1;
              if (col1.isEmpty || !RegExp(r'\d').hasMatch(col1)) {
                digits = col0.replaceAll(RegExp(r'[^\d]'), '');
                letters = col0.replaceAll(RegExp(r'[\d]'), '').trim();
              }

              if (digits.isNotEmpty) {
                extractedCars.add({
                  'letters': letters,
                  'digits': digits,
                  'type': col2,
                  'owner': col3,
                  'status': 'مطلوبة'
                });
              }
            }
          }
        }
      }

      setState(() {
        _wantedDatabase = extractedCars;
        _excelFileName = '${result.files.single.name} (${extractedCars.length})';
        _saveData();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم استيراد ${extractedCars.length} لوحة مطلوبة بنجاح!', textDirection: TextDirection.rtl),
            backgroundColor: const Color(0xFF06D6A0),
          ),
        );
      }
    }
  }

  void _showWantedAlertModal(Map<String, String> car, String letters, String digits) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 3),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.close, color: Colors.black54), onPressed: () => Navigator.pop(context)),
            const Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('تنبيه فوري', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('تم رصد لوحة مطلوبة', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(width: 8),
                CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.priority_high, color: Colors.white)),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(digits, style: const TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold)),
                  Container(width: 2, height: 25, color: Colors.red.shade300),
                  Text(letters, style: const TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _infoRowLight('اللوحة', '$letters $digits'),
            _infoRowLight('النوع', car['type'] ?? 'ملاكي'),
            _infoRowLight('الجهة/المالك', car['owner'] ?? 'مطلوبة'),
            _infoRowLight('الموقع', '$_currentDistrict - $_currentStreet'),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق ومتابعة الرصد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowLight(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
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
          ..._districts.map((d) => ListTile(
                title: Text(d, style: const TextStyle(color: Colors.white), textDirection: TextDirection.rtl),
                trailing: Icon(
                  _currentDistrict == d ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: const Color(0xFF06D6A0),
                ),
                onTap: () {
                  setState(() => _currentDistrict = d);
                  Navigator.pop(context);
                },
              )),
          ListTile(
            title: const Text('إضافة حي +', style: TextStyle(color: Color(0xFF06D6A0), fontWeight: FontWeight.bold), textDirection: TextDirection.rtl),
            onTap: () {
              Navigator.pop(context);
              _showAddDistrictDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showAddDistrictDialog() {
    TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('إضافة حي', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textDirection: TextDirection.rtl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'اسم الحي', hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() {
                  _districts.add(ctrl.text.trim());
                  _currentDistrict = ctrl.text.trim();
                });
              }
              Navigator.pop(context);
            },
            child: const Text('إضافة', style: TextStyle(color: Colors.black)),
          ),
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
        title: const Text('الشارع', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textDirection: TextDirection.rtl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'مثال: ض 1 أو س 1', hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _currentStreet = ctrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showNotesMenu() {
    final notes = ['بدون', 'برحة', 'برحة يمين', 'برحة يسار', 'برحة آخر الشارع', 'برحة وسط الشارع', 'تحت تندة'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2541),
      builder: (context) => ListView(
        shrinkWrap: true,
        children: notes
            .map((n) => ListTile(
                  title: Text(n, style: const TextStyle(color: Colors.white), textDirection: TextDirection.rtl),
                  trailing: Icon(
                    _selectedNote == n ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: const Color(0xFF06D6A0),
                  ),
                  onTap: () {
                    setState(() => _selectedNote = n);
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.upload_file, color: Color(0xFF06D6A0)),
          onPressed: _pickAndParseExcelFile,
          tooltip: 'رفع ملف الإكسيل للسيارات المطلوبة',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الملف: $_excelFileName', style: const TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis),
            const Text('باقي ٢٩ يوم (ينتهي ٣/١/٢٠٢٦)', style: const TextStyle(color: Colors.grey, fontSize: 9)),
          ],
        ),
        actions: const [
          Center(
            child: Text(
              'SHEEKHA',
              style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF06D6A0)),
            ),
          ),
          SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isListening ? const Color(0xFF06D6A0) : Colors.transparent, width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_isListening ? const Color(0xFF06D6A0) : Colors.grey).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isListening ? 'رصد متدفق' : 'متوقف',
                          style: TextStyle(color: _isListening ? const Color(0xFF06D6A0) : Colors.grey, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _isListening ? 'يرصد الحروف والأرقام مباشرة:' : 'اضغط للتسجيل',
                                style: TextStyle(color: _isListening ? const Color(0xFF06D6A0) : Colors.grey, fontSize: 11),
                              ),
                              Text(
                                _currentStatusText,
                                textAlign: TextAlign.right,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleLiveListening,
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: _isListening ? const Color(0xFF06D6A0) : Colors.redAccent,
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_off,
                            color: Colors.black,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 35,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(30, (index) {
                        double baseHeight = 6.0;
                        double dynamicWave = _isListening
                            ? baseHeight + (sin(index + _soundLevel) * _soundLevel * 2.2).abs()
                            : baseHeight;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 60),
                          width: 3.5,
                          height: dynamicWave.clamp(5.0, 35.0),
                          decoration: BoxDecoration(
                            color: _isListening ? const Color(0xFF06D6A0) : Colors.grey.shade700,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _controlCard('ملاحظات', _selectedNote, Icons.edit, Colors.amber, _showNotesMenu)),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: _showStreetDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2541),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF06D6A0).withOpacity(0.6)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: _fetchGPSLocation,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(color: const Color(0xFF06D6A0).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.my_location, color: Color(0xFF06D6A0), size: 12),
                                      SizedBox(width: 2),
                                      Text('GPS', style: TextStyle(color: Color(0xFF06D6A0), fontSize: 9, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const Text('الشارع', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  _currentStreet,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.location_on, color: Color(0xFF06D6A0), size: 14),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: _controlCard('الحي', _currentDistrict, Icons.folder, Colors.blueAccent, _showDistrictMenu)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                      onPressed: () {
                        setState(() => _records.clear());
                        _saveData();
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                      label: const Text('حذف الكل', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF06D6A0))),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم حفظ ملف الإكسيل مع روابط خرائط Google في التنزيلات', textDirection: TextDirection.rtl)),
                        );
                      },
                      icon: const Icon(Icons.download, color: Color(0xFF06D6A0), size: 16),
                      label: const Text('تصدير إكسيل', style: TextStyle(color: Color(0xFF06D6A0), fontSize: 11)),
                    ),
                  ],
                ),
                Text('عدد السجلات: ${_records.length}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541).withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('خريطة', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text('حذف', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text('ملاحظات', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text('الشارع', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text('النوع', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text('الحالة', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text('اللوحة', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _records.isEmpty
                  ? const Center(
                      child: Text(
                        'الرصد مباشر ومتدفق... انطق اللوحات بطلاقة وحرية',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final r = _records[index];
                        bool isWanted = r['status'] == 'مطلوبة';
                        String coords = r['coords'] ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: isWanted ? Colors.redAccent.withOpacity(0.2) : const Color(0xFF1C2541),
                            borderRadius: BorderRadius.circular(10),
                            border: isWanted ? Border.all(color: Colors.redAccent) : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: coords.isNotEmpty ? () => _openGoogleMaps(coords) : null,
                                child: Icon(
                                  Icons.map_outlined,
                                  color: coords.isNotEmpty ? const Color(0xFF06D6A0) : Colors.grey,
                                  size: 18,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  setState(() => _records.removeAt(index));
                                  _saveData();
                                },
                                child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              ),
                              Text(r['note'] ?? '+', style: const TextStyle(color: Colors.amber, fontSize: 11)),
                              Flexible(
                                child: Text(
                                  r['street'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ),
                              Text(r['type'] ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              Icon(
                                isWanted ? Icons.warning_amber_rounded : Icons.check_circle,
                                color: isWanted ? Colors.redAccent : const Color(0xFF06D6A0),
                                size: 18,
                              ),
                              Text(
                                '${r['letters']} ${r['digits']}',
                                style: TextStyle(
                                  color: isWanted ? Colors.redAccent : const Color(0xFF06D6A0),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
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
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'المرصودة'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'التسجيل'),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), label: 'التشييك'),
        ],
      ),
    );
  }

  Widget _controlCard(String title, String value, IconData icon, Color borderColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2541),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor.withOpacity(0.6)),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(icon, color: borderColor, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
