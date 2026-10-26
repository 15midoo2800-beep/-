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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('ar');

  void setLocale(Locale loc) {
    setState(() => _locale = loc);
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
      home: SheekhaHomeScreen(onLanguageChange: setLocale),
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
    'شين': 'ش', 'شه': 'ش', 'شا': 'ش', 'شي': 'ش', 'ش': 'ش',
    'صاد': 'ص', 'صه': 'ص', 'صا': 'ص', 'صي': 'ص', 'ص': 'ص',
    'ضاد': 'ض', 'ضه': 'ض', 'ضا': 'ض', 'ضي': 'ض', 'ض': 'ض',
    'طاء': 'ط', 'طه': 'ط', 'طاء': 'ط', 'طا': 'ط', 'طي': 'ط', 'ط': 'ط',
    'ظاء': 'ظ', 'ظه': 'ظ', 'ظا': 'ظ', 'ظ': 'ظ',
    'عين': 'ع', 'عه': 'ع', 'عين': 'ع', 'عا': 'ع', 'عي': 'ع', 'ع': 'ع',
    'غين': 'غ', 'غه': 'غ', 'غين': 'غ', 'غا': 'غ', 'غاء': 'غ', 'غ': 'غ',
    'فاء': 'ف', 'فه': 'ف', 'فا': 'ف', 'في': 'ف', 'ف': 'ف',
    'قاف': 'ق', 'قه': 'ق', 'قا': 'ق', 'قف': 'ق', 'ق': 'ق',
    'كاف': 'ك', 'كه': 'ك', 'كا': 'ك', 'كي': 'ك', 'ك': 'ك',
    'لام': 'ل', 'له': 'ل', 'لا': 'ل', 'لي': 'ل', 'ل': 'ل',
    'ميم': 'م', 'مه': 'م', 'ما': 'م', 'مين': 'م', 'م': 'م',
    'نون': 'ن', 'نه': 'ن', 'نا': 'ن', 'ني': 'ن', 'ن': 'ن',
    'هاء': 'ه', 'هه': 'ه', 'ها': 'ه', 'هـ': 'ه', 'ه': 'ه',
    'واو': 'و', 'وه': 'و', 'وا': 'و', 'و': 'و',
    'ياء': 'ي', 'يه': 'ي', 'يا': 'ي', 'ى': 'ي', 'ي': 'ي',
  };

  static final Map<String, List<String>> compounds = {
    'واوقاف': ['و', 'ق'], 'أوقاف': ['و', 'ق'], 'اوقاف': ['و', 'ق'],
    'واوساط': ['و', 'ص'], 'أوساط': ['و', 'ص'], 'نوعين': ['ن', 'ع'],
    'نهاء': ['ن', 'ه'], 'تقديم': ['ك', 'ه', 'ج'], 'خطه': ['خ', 'ط'],
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

  static final List<String> allCarTypes = [
    'نقل', 'فان', 'جراند ماكس', 'تلاجة كبيرة', 'ثلاجة كبيرة', 'تلاجة', 'ثلاجة',
    'هاي إس', 'هايس', 'ملاكي', 'ميكروباص', 'أجرة', 'اجرة', 'تاكسي', 'دبابة', 'دبابه',
    'جامبو', 'نصف نقل', 'ربع نقل', 'شفروليه', 'شيفروليه', 'تويوتا', 'هيونداي',
    'كيا', 'نيسان', 'ميتسوبيشي', 'سوزوكي', 'فولكس', 'مرسيدس', 'بي ام', 'بي إم',
    'لوري', 'تريلا', 'تريلة', 'مقطورة', 'قلاب', 'جرار', 'ونش', 'أتوبيس', 'اتوبيس',
    'سوزوكي فان', 'تمناية', 'كبوت', 'بيك اب', 'بيك أب', 'بوكس'
  ];

  static Map<String, dynamic>? parsePlateAndType(String text) {
    if (text.trim().isEmpty) return null;

    String normalized = normalizeDigits(text);
    String detectedType = 'ملاكي';

    for (String type in allCarTypes) {
      if (normalized.contains(type)) {
        detectedType = type;
        normalized = normalized.replaceAll(type, ' ');
        break;
      }
    }

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
        'type': detectedType,
      };
    }

    return null;
  }

  static String normalizeDigits(String input) {
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < ar.length; i++) {
      input = input.replaceAll(ar[i], en[i]);
    }
    return input;
  }

  static String normalizeFlexible(String input) {
    String res = normalizeDigits(input.trim());
    res = res.replaceAll(RegExp(r'[أإآا]'), 'أ');
    res = res.replaceAll(RegExp(r'[يى]'), 'ي');
    res = res.replaceAll(RegExp(r'[ةه]'), 'ه');
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
  String _currentStatusText = 'يستمع الآن...';
  double _soundLevel = 0.0;

  final Map<String, DateTime> _cooldowns = {};
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;

  final List<String> _districts = ['الروضة', 'السلام', 'المنيل', 'المعادي'];
  String _currentDistrict = 'الروضة';
  String _currentStreet = 'ض 1';
  String _currentCoordinates = '';
  String _selectedNote = 'بدون';
  String _wantedFileName = 'لم يتم رفع ملف السيارات المطلوبة';
  String _appendFileName = 'لم يتم اختيار ملف';
  String _savedWhatsAppPhone = '00201155661920';

  List<Map<String, String>> _records = [];
  List<Map<String, String>> _wantedDatabase = [];

  final Set<String> _selectedWantedIds = {};

  final TextEditingController _manualSearchCtrl = TextEditingController();
  List<Map<String, String>> _manualSearchResults = [];
  bool _isManualSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initEngine();
  }

  Future<void> _initEngine() async {
    var micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) return;

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
      setState(() => _speechEnabled = available);
    } catch (_) {}
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
        _currentStatusText = 'يستمع الآن...';
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

        var plateData = SheekhaFullEngine.parsePlateAndType(spoken);
        if (plateData != null) {
          String letters = plateData['letters']!;
          String digits = plateData['digits']!;
          String carType = plateData['type']!;
          String key = '$letters-$digits';

          DateTime now = DateTime.now();
          bool isRecent = _cooldowns.containsKey(key) &&
              now.difference(_cooldowns[key]!).inSeconds < 4;

          if (!isRecent) {
            _cooldowns[key] = now;
            _registerDetectedPlate(letters, digits, carType);

            _speech.stop().then((_) {
              if (_isListening && mounted) {
                _startListeningSession();
              }
            });
          }
        }
      },
    );
  }

  void _registerDetectedPlate(String letters, String digits, String spokenType) {
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

    // اعتماد نوع السيارة القادم من الشيت المرفق إن وجدت، ثم المنطوق صوتياً
    String finalCarType = isWanted && (match['type'] ?? '').isNotEmpty && match['type'] != 'ملاكي'
        ? match['type']!
        : (spokenType != 'ملاكي' ? spokenType : (match['type'] ?? 'ملاكي'));

    setState(() {
      _records.insert(0, {
        'id': (_records.length + 1).toString(),
        'letters': letters,
        'digits': digits,
        'type': finalCarType,
        'district': _currentDistrict,
        'street': _currentStreet,
        'coords': _currentCoordinates,
        'note': _selectedNote == 'بدون' ? '+' : _selectedNote,
        'status': isWanted ? 'مطلوبة' : 'مطابق',
        'owner': match['owner'] ?? 'غير محدد',
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

  Future<void> _pickAndParseWantedDatabaseFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      _showLoadingProgressModal('جاري قراءة ملف السيارات المطلوبة واستخراج أنواعها...');
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        var bytes = File(result.files.single.path!).readAsBytesSync();
        var excel = ex.Excel.decodeBytes(bytes);
        List<Map<String, String>> extractedCars = [];

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table];
          if (sheet != null) {
            for (var row in sheet.rows.skip(1)) {
              if (row.isNotEmpty && row[0] != null) {
                String col0 = row[0]?.value?.toString().trim() ?? '';
                String col1 = row.length > 1 ? (row[1]?.value?.toString().trim() ?? '') : '';
                String col2 = row.length > 2 ? (row[2]?.value?.toString().trim() ?? '') : '';
                String col3 = row.length > 3 ? (row[3]?.value?.toString().trim() ?? '') : '';

                String letters = col0;
                String digits = col1;
                if (col1.isEmpty || !RegExp(r'\d').hasMatch(col1)) {
                  digits = col0.replaceAll(RegExp(r'[^\d]'), '');
                  letters = col0.replaceAll(RegExp(r'[\d]'), '').trim();
                }

                // استخراج نوع السيارة بدقة من أي عمود متاح بالشيت
                String carType = col2.isNotEmpty ? col2 : (col3.isNotEmpty ? col3 : 'ملاكي');
                String owner = col3.isNotEmpty && col3 != carType ? col3 : (col2.isNotEmpty && col2 != carType ? col2 : 'مطلوبة');

                if (digits.isNotEmpty) {
                  extractedCars.add({
                    'letters': letters,
                    'digits': digits,
                    'type': carType,
                    'owner': owner,
                    'status': 'مطلوبة'
                  });
                }
              }
            }
          }
        }

        setState(() {
          _wantedDatabase = extractedCars;
          _wantedFileName = '${result.files.single.name} (${extractedCars.length})';
          _saveData();
        });

        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم رفع ملف السيارات المطلوبة بنجاح! تم استخراج ${extractedCars.length} سيارة بأنواعها.', textDirection: TextDirection.rtl),
              backgroundColor: const Color(0xFF06D6A0),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ أثناء معالجة الملف: $e', textDirection: TextDirection.rtl), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _showLoadingProgressModal(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF06D6A0)),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportExcelDirectlyToDownloads() async {
    try {
      await Permission.storage.request();
      _showLoadingProgressModal('جاري تصدير السجلات إلى مجلد Download...');
      await Future.delayed(const Duration(milliseconds: 50));

      var excel = ex.Excel.createExcel();
      ex.Sheet sheet = excel['سجلات_الرصد'];
      excel.delete('Sheet1');

      sheet.appendRow([
        ex.TextCellValue('م'),
        ex.TextCellValue('اللوحة'),
        ex.TextCellValue('الحالة'),
        ex.TextCellValue('النوع'),
        ex.TextCellValue('الحي'),
        ex.TextCellValue('الشارع'),
        ex.TextCellValue('رابط الخريطة'),
        ex.TextCellValue('ملاحظات'),
        ex.TextCellValue('الوقت'),
      ]);

      for (var r in _records) {
        String coords = r['coords'] ?? '';
        String mapLink = coords.isNotEmpty ? 'https://maps.google.com/?q=$coords' : 'غير متوفر';

        sheet.appendRow([
          ex.TextCellValue(r['id'] ?? ''),
          ex.TextCellValue('${r['letters']} ${r['digits']}'),
          ex.TextCellValue(r['status'] ?? ''),
          ex.TextCellValue(r['type'] ?? ''),
          ex.TextCellValue(r['district'] ?? ''),
          ex.TextCellValue(r['street'] ?? ''),
          ex.TextCellValue(mapLink),
          ex.TextCellValue(r['note'] ?? ''),
          ex.TextCellValue(r['time'] ?? ''),
        ]);
      }

      Directory downloadDir = Directory('/storage/emulated/0/Download');
      if (!downloadDir.existsSync()) {
        downloadDir = await Directory('/storage/emulated/0/Downloads').create(recursive: true);
      }

      DateTime now = DateTime.now();
      String dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour}${now.minute}';
      String safeDistrict = _currentDistrict.replaceAll(RegExp(r'[^\w\s\u0621-\u064A]'), '_').trim();
      if (safeDistrict.isEmpty) safeDistrict = 'سجلات';
      String fileName = '${safeDistrict}_$dateStr.xlsx';

      String filePath = '${downloadDir.path}/$fileName';
      File file = File(filePath);
      await file.writeAsBytes(excel.save()!);

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ شيت "$fileName" في مجلد Download بنجاح!', textDirection: TextDirection.rtl),
            backgroundColor: const Color(0xFF06D6A0),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التصدير: $e', textDirection: TextDirection.rtl), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _pickAndAppendExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      _showLoadingProgressModal('جاري تحميل الشيت واستخراج السجلات للإكمال...');
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        var bytes = File(result.files.single.path!).readAsBytesSync();
        var excel = ex.Excel.decodeBytes(bytes);
        List<Map<String, String>> importedList = [];

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table];
          if (sheet != null) {
            for (var row in sheet.rows.skip(1)) {
              if (row.isNotEmpty && row[0] != null) {
                String col0 = row[0]?.value?.toString() ?? '';
                String col1 = row.length > 1 ? (row[1]?.value?.toString() ?? '') : '';
                String col2 = row.length > 2 ? (row[2]?.value?.toString() ?? 'ملاكي') : 'ملاكي';
                String col3 = row.length > 3 ? (row[3]?.value?.toString() ?? 'سجل سابق') : 'سجل سابق';

                String digits = col1;
                String letters = col0;
                if (col1.isEmpty || !RegExp(r'\d').hasMatch(col1)) {
                  digits = col0.replaceAll(RegExp(r'[^\d]'), '');
                  letters = col0.replaceAll(RegExp(r'[\d]'), '').trim();
                }

                if (digits.isNotEmpty) {
                  importedList.add({
                    'id': (_records.length + importedList.length + 1).toString(),
                    'letters': letters,
                    'digits': digits,
                    'type': col2,
                    'district': _currentDistrict,
                    'street': _currentStreet,
                    'coords': _currentCoordinates,
                    'note': col3,
                    'status': 'مطابق',
                    'time': 'سابق',
                  });
                }
              }
            }
          }
        }

        setState(() {
          _records.addAll(importedList);
          _appendFileName = result.files.single.name;
          _saveData();
        });

        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم استيراد ${importedList.length} سجل بنجاح ومتابعة الإكمال عليها!', textDirection: TextDirection.rtl),
              backgroundColor: const Color(0xFF06D6A0),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في استيراد الشيت: $e', textDirection: TextDirection.rtl), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _editRecordManually(int index) {
    var rec = _records[index];
    TextEditingController letCtrl = TextEditingController(text: rec['letters']);
    TextEditingController digCtrl = TextEditingController(text: rec['digits']);
    TextEditingController typCtrl = TextEditingController(text: rec['type']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('تعديل يدوي للوحة والنوع', style: TextStyle(color: Color(0xFF06D6A0)), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: letCtrl,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'الحروف (مثال: أ ن د)', labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: digCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'الأرقام (مثال: 2718)', labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: typCtrl,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'نوع السيارة (مثال: نقل / فان)', labelStyle: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)),
            onPressed: () {
              setState(() {
                rec['letters'] = letCtrl.text.trim();
                rec['digits'] = digCtrl.text.trim();
                rec['type'] = typCtrl.text.trim();
              });
              _saveData();
              Navigator.pop(context);
            },
            child: const Text('حفظ التعديل', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _sendWantedToWhatsApp() async {
    List<Map<String, String>> toSend = _records.where((r) => r['status'] == 'مطلوبة' && _selectedWantedIds.contains(r['id'])).toList();
    if (toSend.isEmpty) {
      toSend = _records.where((r) => r['status'] == 'مطلوبة').toList();
    }

    if (toSend.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد سيارات مطلوبة لإرسالها', textDirection: TextDirection.rtl)),
      );
      return;
    }

    StringBuffer buffer = StringBuffer();
    buffer.writeln('🚨 *تقرير رصد سيارات مطلوبة - تطبيق SHEEKHA*');
    buffer.writeln('-----------------------------------');
    for (var car in toSend) {
      buffer.writeln('🚗 لوحة: ${car['letters']} ${car['digits']}');
      buffer.writeln('📋 النوع: ${car['type']}');
      buffer.writeln('📍 الموقع: ${car['district']} - ${car['street']}');
      if ((car['coords'] ?? '').isNotEmpty) {
        buffer.writeln('🗺 الخريطة: https://maps.google.com/?q=${car['coords']}');
      }
      buffer.writeln('⏱ الوقت: ${car['time']}');
      buffer.writeln('-----------------------------------');
    }

    String phone = _savedWhatsAppPhone.replaceAll(RegExp(r'[^\d]'), '');
    String encodedText = Uri.encodeComponent(buffer.toString());
    Uri whatsappUri = Uri.parse('whatsapp://send?phone=$phone&text=$encodedText');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        Uri webUri = Uri.parse('https://api.whatsapp.com/send?phone=$phone&text=$encodedText');
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح الواتساب: $e', textDirection: TextDirection.rtl)),
        );
      }
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

    for (var car in _wantedDatabase) {
      String target = SheekhaFullEngine.normalizeFlexible('${car['letters']} ${car['digits']} ${car['type']} ${car['owner']}');
      if (target.contains(normalizedQuery)) {
        matched.add({
          'id': 'مطلوبة',
          'letters': car['letters'] ?? '',
          'digits': car['digits'] ?? '',
          'type': car['type'] ?? 'ملاكي',
          'district': 'شيت المطلوبين',
          'street': car['owner'] ?? 'مطلوبة',
          'coords': '',
          'note': '⚠️ مسجلة في شيت المطلوبين',
          'status': 'مطلوبة',
          'time': 'قاعدة البيانات',
        });
      }
    }

    for (var car in _records) {
      String target = SheekhaFullEngine.normalizeFlexible('${car['letters']} ${car['digits']} ${car['type']}');
      if (target.contains(normalizedQuery)) {
        if (!matched.any((m) => m['digits'] == car['digits'] && m['letters'] == car['letters'])) {
          matched.add(car);
        }
      }
    }

    String cleanDigitsOnly = query.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigitsOnly.length >= 3) {
      var exactMatch = _wantedDatabase.firstWhere(
        (w) => (w['digits'] ?? '').trim() == cleanDigitsOnly,
        orElse: () => {},
      );
      if (exactMatch.isNotEmpty) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        _showWantedAlertModal(exactMatch, exactMatch['letters'] ?? '', exactMatch['digits'] ?? '');
      }
    }

    setState(() {
      _manualSearchResults = matched;
      _isManualSearching = false;
    });
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
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تثبيت إشارة الـ GPS بنجاح', textDirection: TextDirection.rtl), backgroundColor: Color(0xFF06D6A0)),
    );
  }

  void _openGoogleMaps(String coords) async {
    if (coords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم التقاط إحداثيات GPS لهذه اللوحة', textDirection: TextDirection.rtl)),
      );
      return;
    }

    Uri geoUri = Uri.parse('geo:$coords?q=$coords');
    Uri webUri = Uri.parse('https://maps.google.com/?q=$coords');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedRecords = prefs.getString('sheekha_historical_records');
    final String? savedDb = prefs.getString('sheekha_wanted_db');
    final String? savedPhone = prefs.getString('sheekha_wa_phone');
    final String? savedWantedName = prefs.getString('sheekha_wanted_name');
    final String? savedDistricts = prefs.getString('sheekha_districts_list');

    setState(() {
      if (savedRecords != null) {
        _records = List<Map<String, String>>.from(
            json.decode(savedRecords).map((x) => Map<String, String>.from(x)));
      }
      if (savedDb != null) {
        _wantedDatabase = List<Map<String, String>>.from(
            json.decode(savedDb).map((x) => Map<String, String>.from(x)));
      }
      if (savedPhone != null) _savedWhatsAppPhone = savedPhone;
      if (savedWantedName != null) _wantedFileName = savedWantedName;
      if (savedDistricts != null) {
        List<String> loadedDistricts = List<String>.from(json.decode(savedDistricts));
        for (var d in loadedDistricts) {
          if (!_districts.contains(d)) _districts.add(d);
        }
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('sheekha_historical_records', json.encode(_records));
    prefs.setString('sheekha_wanted_db', json.encode(_wantedDatabase));
    prefs.setString('sheekha_wa_phone', _savedWhatsAppPhone);
    prefs.setString('sheekha_wanted_name', _wantedFileName);
    prefs.setString('sheekha_districts_list', json.encode(_districts));
  }

  // إظهار نوع السيارة المستخرج من الشيت في نافذة التنبيه بوضوح
  void _showWantedAlertModal(Map<String, String> car, String letters, String digits) {
    String carType = (car['type'] ?? '').isNotEmpty ? car['type']! : 'ملاكي';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.redAccent, width: 3)),
        title: const Text('🚨 تم رصد سيارة مطلوبة!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
              child: Text('$letters $digits', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade300)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_car, color: Colors.black87, size: 20),
                  const SizedBox(width: 6),
                  Text('النوع: $carType', style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text('الجهة/المالك: ${car['owner'] ?? 'مطلوبة'}', style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
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
          )
        ],
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
          icon: const Icon(Icons.upload_file, color: Color(0xFF06D6A0), size: 28),
          tooltip: 'رفع شيت السيارات المطلوبة',
          onPressed: _pickAndParseWantedDatabaseFile,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('SHEEKHA', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, color: Color(0xFF06D6A0), fontSize: 18)),
            Text(
              _wantedFileName,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: true,
        actions: const [
          SizedBox(width: 48),
        ],
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
      case 0:
        return _buildSettingsTab();
      case 1:
        return _buildManualSearchTab();
      case 2:
        return _buildWantedRecordsTab();
      case 3:
        return _buildRegistrationTab();
      case 4:
      default:
        return _buildCheckingTab();
    }
  }

  Widget _buildCheckingTab() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          _buildLiveMicBox(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('السجلات: ${_records.length}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const Text('اضغط على اللوحة أو النوع لتعديلهما', style: TextStyle(color: Color(0xFF06D6A0), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildRecordsListView(_records)),
        ],
      ),
    );
  }

  Widget _buildRegistrationTab() {
    bool hasGPS = _currentCoordinates.isNotEmpty;

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
                                      if (hasGPS) {
                                        Clipboard.setData(ClipboardData(text: _currentCoordinates));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('تم نسخ الإحداثيات: $_currentCoordinates', textDirection: TextDirection.rtl), backgroundColor: const Color(0xFF06D6A0)),
                                        );
                                      } else {
                                        _fetchGPSLocation();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: hasGPS ? const Color(0xFF06D6A0) : Colors.transparent, borderRadius: BorderRadius.circular(4)),
                                      child: Row(
                                        children: [
                                          Icon(Icons.my_location, color: hasGPS ? Colors.black : const Color(0xFF06D6A0), size: 12),
                                          Text(hasGPS ? ' GPS ✓' : ' GPS', style: TextStyle(color: hasGPS ? Colors.black : const Color(0xFF06D6A0), fontSize: 9, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
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
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)),
                        onPressed: _exportExcelDirectlyToDownloads,
                        icon: const Icon(Icons.download, color: Colors.black, size: 18),
                        label: const Text('تصدير إكسيل (باسم الحي)', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF06D6A0))),
                        onPressed: _pickAndAppendExcelFile,
                        icon: const Icon(Icons.add_to_photos, color: Color(0xFF06D6A0), size: 18),
                        label: const Text('استيراد وإكمال شيت', style: TextStyle(color: Color(0xFF06D6A0), fontSize: 11)),
                      ),
                    ),
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
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B132B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.edit, color: Color(0xFF06D6A0), size: 16),
                        Row(
                          children: [
                            Text(
                              _savedWhatsAppPhone,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              textDirection: TextDirection.ltr,
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.phone, color: Color(0xFF06D6A0), size: 18),
                            const SizedBox(width: 4),
                            const Text('رقم الإرسال:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _sendWantedToWhatsApp,
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  label: const Text('إرسال للواتساب', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'حدد السيارات المراد إرسالها من القائمة أو اضغط إرسال للكل مباشرة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
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
                            Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF06D6A0),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedWantedIds.add(id);
                                  } else {
                                    _selectedWantedIds.remove(id);
                                  }
                                });
                              },
                            ),
                            InkWell(
                              onTap: () => _openGoogleMaps(car['coords'] ?? ''),
                              child: const Icon(Icons.map, color: Color(0xFF06D6A0), size: 24),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${car['letters']} ${car['digits']}', style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('النوع: ${car['type']} | الشارع: ${car['street']}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('الجهة/المالك: ${car['owner']}', style: const TextStyle(color: Colors.amber, fontSize: 11)),
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
        content: TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'مثال: 00201155661920'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)),
            onPressed: () {
              setState(() => _savedWhatsAppPhone = phoneCtrl.text.trim());
              _saveData();
              Navigator.pop(context);
            },
            child: const Text('تثبيت الرقم', style: TextStyle(color: Colors.black)),
          )
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
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06D6A0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isManualSearching ? null : _executeManualSearchAction,
                  icon: _isManualSearching
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.search, color: Colors.black, size: 18),
                  label: const Text('بحث', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _manualSearchCtrl,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _executeManualSearchAction(),
                    decoration: const InputDecoration(
                      hintText: 'اكتب حروف أو أرقام السيارة...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _manualSearchResults.isEmpty
                ? const Center(
                    child: Text(
                      'اكتب كود أو رقم السيارة واضغط "بحث" للفحص الفوري في الشيت',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : _buildRecordsListView(_manualSearchResults),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: const Color(0xFF1C2541),
          leading: const Icon(Icons.language, color: Color(0xFF06D6A0)),
          title: const Text('لغة التطبيق / Language', style: TextStyle(color: Colors.white)),
          trailing: DropdownButton<String>(
            dropdownColor: const Color(0xFF1C2541),
            value: 'العربية',
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'العربية', child: Text('العربية', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 'English', child: Text('English', style: TextStyle(color: Colors.white))),
            ],
            onChanged: (val) {
              if (val == 'English') {
                widget.onLanguageChange(const Locale('en'));
              } else {
                widget.onLanguageChange(const Locale('ar'));
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: const Color(0xFF1C2541),
          leading: const Icon(Icons.support_agent, color: Color(0xFF06D6A0)),
          title: const Text('التواصل مع الدعم وتحديد الاشتراك', style: TextStyle(color: Colors.white)),
          subtitle: const Text('واتساب: 00201155661920', style: TextStyle(color: Colors.grey, fontSize: 11)),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          onTap: () async {
            const phone = '201155661920';
            const text = 'مرحباً، أود الاستفسار وتجديد اشتراك تطبيق SHEEKHA';
            String encodedText = Uri.encodeComponent(text);
            Uri whatsappUri = Uri.parse('whatsapp://send?phone=$phone&text=$encodedText');

            try {
              if (await canLaunchUrl(whatsappUri)) {
                await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
              } else {
                Uri webUri = Uri.parse('https://wa.me/$phone?text=$encodedText');
                await launchUrl(webUri, mode: LaunchMode.externalApplication);
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تعذر فتح الواتساب: $e', textDirection: TextDirection.rtl)),
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildLiveMicBox() {
    return Container(
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
                decoration: BoxDecoration(color: (_isListening ? const Color(0xFF06D6A0) : Colors.grey).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(_isListening ? 'يستمع الآن' : 'متوقف', style: TextStyle(color: _isListening ? const Color(0xFF06D6A0) : Colors.grey, fontSize: 12)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(_currentStatusText, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              GestureDetector(
                onTap: _toggleLiveListening,
                child: CircleAvatar(radius: 26, backgroundColor: _isListening ? const Color(0xFF06D6A0) : Colors.redAccent, child: Icon(_isListening ? Icons.mic : Icons.mic_off, color: Colors.black, size: 28)),
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
                double dynamicWave = _isListening ? baseHeight + (sin(index + _soundLevel) * _soundLevel * 2.2).abs() : baseHeight;
                return AnimatedContainer(duration: const Duration(milliseconds: 60), width: 3.5, height: dynamicWave.clamp(5.0, 35.0), decoration: BoxDecoration(color: _isListening ? const Color(0xFF06D6A0) : Colors.grey.shade700, borderRadius: BorderRadius.circular(2)));
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsListView(List<Map<String, String>> list) {
    if (list.isEmpty) {
      return const Center(child: Text('لا توجد سجلات حالياً...', style: TextStyle(color: Colors.grey)));
    }

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
              // عرض نوع السيارة مع إمكانية التعديل
              InkWell(
                onTap: () => _editRecordManually(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isWanted ? Colors.redAccent.withOpacity(0.3) : const Color(0xFF06D6A0).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r['type'] ?? 'ملاكي',
                    style: TextStyle(color: isWanted ? Colors.white : const Color(0xFF06D6A0), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
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
          ..._districts.map((d) => ListTile(
            title: Text(d, style: const TextStyle(color: Colors.white), textDirection: TextDirection.rtl),
            trailing: Icon(_currentDistrict == d ? Icons.check_circle : Icons.circle_outlined, color: const Color(0xFF06D6A0), size: 18),
            onTap: () {
              setState(() => _currentDistrict = d);
              Navigator.pop(context);
            },
          )),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.add, color: Color(0xFF06D6A0)),
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
    TextEditingController districtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('إضافة حي جديد', style: TextStyle(color: Color(0xFF06D6A0)), textAlign: TextAlign.center),
        content: TextField(
          controller: districtCtrl,
          autofocus: true,
          textDirection: TextDirection.rtl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'اكتب اسم الحي الجديد...', hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)),
            onPressed: () {
              String newD = districtCtrl.text.trim();
              if (newD.isNotEmpty) {
                setState(() {
                  if (!_districts.contains(newD)) _districts.add(newD);
                  _currentDistrict = newD;
                });
                _saveData();
              }
              Navigator.pop(context);
            },
            child: const Text('إضافة وتحديد', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
        title: const Text('الشارع', style: TextStyle(color: Colors.white)),
        content: TextField(controller: ctrl, textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white)),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() => _currentStreet = ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          )
        ],
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
        children: notes.map((n) => ListTile(
          title: Text(n, style: const TextStyle(color: Colors.white), textDirection: TextDirection.rtl),
          onTap: () {
            setState(() => _selectedNote = n);
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }
}
