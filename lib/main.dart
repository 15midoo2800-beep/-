import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'dart:io';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';

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

// المحرك الفوري لاستخراج اللوحات من الصوت الحي وتجاهل الكلام الخارجي
class LivePlateExtractor {
  // الحروف المعتمدة في اللوحات (المصرية والسعودية)
  static const String validPlateChars = 'ابتثجحخدذرزسشصضطظعغفقكلمنهويىأإآؤئ';

  static final Map<String, String> spokenLetters = {
    'الف': 'أ', 'ألف': 'أ', 'إلف': 'أ', 'ا': 'أ', 'أ': 'أ', 'إ': 'أ', 'آ': 'أ', 'همزه': 'أ', 'همزة': 'أ',
    'ب': 'ب', 'به': 'ب', 'بة': 'ب', 'باء': 'ب', 'با': 'ب', 'بي': 'ب',
    'ت': 'ت', 'ته': 'ت', 'تاء': 'ت',
    'ث': 'ث', 'ثه': 'ث', 'ثاء': 'ث',
    'ج': 'ج', 'جيم': 'ج', 'جم': 'ج',
    'ح': 'ح', 'حه': 'ح', 'حة': 'ح', 'حاء': 'ح', 'حا': 'ح',
    'خ': 'خ', 'خه': 'خ', 'خاء': 'خ',
    'د': 'د', 'دال': 'د', 'دل': 'د',
    'ذ': 'ذ', 'ذال': 'ذ',
    'ر': 'ر', 'ره': 'ر', 'رة': 'ر', 'راء': 'ر', 'را': 'ر',
    'ز': 'ز', 'زين': 'ز', 'زاي': 'ز',
    'س': 'س', 'سين': 'س', 'سن': 'س',
    'ش': 'ش', 'شين': 'ش',
    'ص': 'ص', 'صاد': 'ص', 'صد': 'ص',
    'ض': 'ض', 'ضاد': 'ض', 'ضد': 'ض',
    'ط': 'ط', 'طه': 'ط', 'طة': 'ط', 'طاء': 'ط', 'طا': 'ط',
    'ظ': 'ظ', 'ظه': 'ظ', 'ظاء': 'ظ',
    'ع': 'ع', 'عين': 'ع', 'عن': 'ع',
    'غ': 'غ', 'غين': 'غ',
    'ف': 'ف', 'فه': 'ف', 'فة': 'ف', 'فاء': 'ف', 'فا': 'ف',
    'ق': 'ق', 'قاف': 'ق', 'قف': 'ق',
    'ك': 'ك', 'كاف': 'ك', 'كف': 'ك',
    'ل': 'ل', 'لام': 'ل', 'لم': 'ل',
    'م': 'م', 'ميم': 'م', 'مم': 'م',
    'ن': 'ن', 'نون': 'ن', 'نن': 'ن',
    'ه': 'هـ', 'هه': 'هـ', 'هة': 'هـ', 'هاء': 'هـ', 'ها': 'هـ', 'هـ': 'هـ',
    'و': 'و', 'واو': 'و', 'وو': 'و',
    'ي': 'ي', 'ى': 'ي', 'يه': 'ي', 'ية': 'ي', 'ياء': 'ي', 'يا': 'ي',
  };

  static final Map<String, String> spokenDigits = {
    'صفر': '0', 'زيرو': '0',
    'واحد': '1', 'واحده': '1', 'واحدة': '1', 'وحده': '1',
    'اثنين': '2', 'اتنين': '2', 'إثنين': '2', 'تنين': '2', 'اثنان': '2',
    'ثلاثه': '3', 'ثلاثة': '3', 'تلاته': '3', 'تلاتة': '3', 'تلات': '3', 'ثلاث': '3',
    'اربعه': '4', 'أربعة': '4', 'اربعة': '4', 'اربع': '4', 'أربع': '4', 'أربعه': '4',
    'خمسه': '5', 'خمسة': '5', 'خمس': '5',
    'سته': '6', 'ستة': '6', 'ست': '6',
    'سبعه': '7', 'سبعة': '7', 'سبع': '7',
    'ثمانيه': '8', 'ثمانية': '8', 'تمانيه': '8', 'تمانية': '8', 'تمن': '8', 'ثمان': '8', 'تماني': '8',
    'تسعه': '9', 'تسعة': '9', 'تسع': '9',
  };

  static final Map<String, String> carTypes = {
    'دينا': 'دينا', 'ديانا': 'دينا', 'دينه': 'دينا',
    'تويوتا': 'تويوتا', 'تيوتا': 'تويوتا', 'هايلوكس': 'هايلوكس', 'توسان': 'توسان',
    'هيونداي': 'هيونداي', 'هونداي': 'هيونداي', 'النترا': 'النترا', 'اكسنت': 'اكسنت',
    'كيا': 'كيا', 'سيراتو': 'سيراتو', 'سبورتاج': 'سبورتاج',
    'نيسان': 'نيسان', 'صني': 'صني', 'تيدا': 'تيدا',
    'مرسيدس': 'مرسيدس', 'بي': 'بي ام', 'شفروليه': 'شفروليه', 'شيفروليه': 'شفروليه',
    'ربع': 'ربع نقل', 'جامبو': 'جامبو', 'ملاكي': 'ملاكي', 'نقل': 'نقل', 'ميكروباص': 'ميكروباص',
  };

  /// يحول النص المنطوق بالكامل إلى رموز لوحات ويستخرج اللوحة المكتملة
  static Map<String, String>? extractFromLiveStream(String rawSpeech) {
    if (rawSpeech.trim().isEmpty) return null;

    String normalized = normalizeNumbers(rawSpeech);
    // فصل الأرقام الملتصقة بالحروف (مثل دبد2718 -> دبد 2718)
    normalized = normalized.replaceAllMapped(
        RegExp(r'([\u0621-\u064A])(\d)'), (m) => '${m[1]} ${m[2]}');
    normalized = normalized.replaceAllMapped(
        RegExp(r'(\d)([\u0621-\u064A])'), (m) => '${m[1]} ${m[2]}');

    List<String> tokens = normalized.split(RegExp(r'\s+'));

    List<String> currentLetters = [];
    String currentDigits = '';
    String detectedType = '-';

    for (int i = 0; i < tokens.length; i++) {
      String word = tokens[i].replaceAll(RegExp(r'[^\u0621-\u064A0-9]'), '');
      if (word.isEmpty) continue;

      // 1. فحص هل الكلمة نوع سيارة
      if (carTypes.containsKey(word)) {
        detectedType = carTypes[word]!;
        continue;
      }

      // 2. فحص هل الكلمة رقم منطوق (واحد، اثنين...)
      if (spokenDigits.containsKey(word)) {
        // إذا بدأنا في الأرقام بعد جمع الحروف
        currentDigits += spokenDigits[word]!;
        continue;
      }

      // 3. فحص هل الكلمة أرقام صريحة (مثل 2718 أو 2 7 1 8)
      if (RegExp(r'^\d+$').hasMatch(word)) {
        currentDigits += word;
        continue;
      }

      // 4. فحص هل الكلمة اسم حرف منطوق (دال، به، سين، نون...)
      if (spokenLetters.containsKey(word)) {
        // إذا كان لدينا لوحة سابقة مكتملة وبدأ ينطق حروف لوحة جديدة، نصفر لتسجيل الجديدة
        if (currentLetters.length >= 2 && currentDigits.length >= 3) {
          break;
        }
        if (currentDigits.isEmpty && currentLetters.length < 4) {
          currentLetters.add(spokenLetters[word]!);
        }
        continue;
      }

      // 5. ماذا لو دمج جوجل الحروف المنطوقة في كلمة قصيرة من 2 أو 3 حروف (مثل: "دبد" أو "طسق" أو "اند")؟
      // بشرط ألا تكون من كلمات الكلام العادي الشائعة
      if (word.length >= 2 &&
          word.length <= 3 &&
          currentDigits.isEmpty &&
          currentLetters.isEmpty &&
          !_isCommonFillerWord(word)) {
        // نتحقق هل يتبعها في الجملة أرقام؟ إذا كان بعدها أرقام فهي بالتأكيد حروف لوحة مدمجة!
        bool followedByNumbers = _checkIfFollowedByNumbers(tokens, i + 1);
        if (followedByNumbers) {
          for (int c = 0; c < word.length; c++) {
            String ch = word[c];
            if (spokenLetters.containsKey(ch)) {
              currentLetters.add(spokenLetters[ch]!);
            } else {
              currentLetters.add(ch);
            }
          }
          continue;
        }
      }

      // 6. إذا كانت كلمة كلام عادي طويل (مثل: "تعال"، "نسجل"، "النهارده") ولم يكتمل النمط بعد، نصفر الحروف العشوائية
      if (currentDigits.isEmpty && word.length > 3 && !spokenLetters.containsKey(word)) {
        currentLetters.clear();
      }
    }

    // شرط اعتماد اللوحة: من 2 إلى 4 حروف + من 2 إلى 4 أرقام
    if (currentLetters.length >= 2 && currentDigits.length >= 2) {
      if (currentDigits.length > 4) {
        currentDigits = currentDigits.substring(0, 4);
      }
      return {
        'letters': currentLetters.take(3).join(' '),
        'digits': currentDigits,
        'type': detectedType,
      };
    }

    return null;
  }

  static bool _checkIfFollowedByNumbers(List<String> tokens, int startIndex) {
    for (int j = startIndex; j < min(tokens.length, startIndex + 3); j++) {
      String w = tokens[j].replaceAll(RegExp(r'[^\u0621-\u064A0-9]'), '');
      if (RegExp(r'^\d+$').hasMatch(w) || spokenDigits.containsKey(w)) {
        return true;
      }
    }
    return false;
  }

  static bool _isCommonFillerWord(String w) {
    const fillers = {
      'انا', 'أنت', 'انت', 'مش', 'من', 'في', 'على', 'علي', 'عن', 'مع', 'ده', 'دي',
      'كده', 'كدا', 'هنا', 'بس', 'لو', 'او', 'أو', 'ثم', 'اي', 'أي', 'كل', 'ولا',
      'يا', 'اه', 'لا', 'طيب', 'طب', 'عم', 'اللي', 'الي', 'هو', 'هي', 'هم'
    };
    return fillers.contains(w);
  }

  static String normalizeNumbers(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < arabic.length; i++) {
      input = input.replaceAll(arabic[i], english[i]);
    }
    return input;
  }

  // توحيد شكل الحروف والأرقام عند المقارنة مع شيت الإكسيل
  static String normalizeForComparison(String text) {
    String s = normalizeNumbers(text);
    s = s.replaceAll(RegExp(r'\s+'), '');
    s = s.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
    s = s.replaceAll('هـ', 'ه').replaceAll('ة', 'ه');
    s = s.replaceAll('ى', 'ي');
    return s;
  }
}

class SheekhaHomeScreen extends StatefulWidget {
  const SheekhaHomeScreen({super.key});

  @override
  State<SheekhaHomeScreen> createState() => _SheekhaHomeScreenState();
}

class _SheekhaHomeScreenState extends State<SheekhaHomeScreen> {
  int _currentIndex = 1; // تبويب التسجيل
  bool _isListening = false;
  String _currentStatusText = 'اضغط الميكروفون وابدأ نطق اللوحة...';
  double _soundLevel = 0.0;

  // لتتبع الكلمات التي تمت معالجتها داخل نفس الجملة الصوتية المستمرة
  int _processedWordIndex = 0;
  String _lastAddedPlateKey = '';
  DateTime _lastAddedTime = DateTime.fromMillisecondsSinceEpoch(0);

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  String _selectedLocaleId = 'ar_EG';

  final List<String> _districts = ['الروضة', 'السلام', 'المنيل', 'المعادي'];
  String _currentDistrict = 'الروضة';
  String _currentStreet = 'ض 1';
  String _selectedNote = 'بدون';
  String _excelFileName = 'لم يتم رفع ملف إكسيل';

  List<Map<String, String>> _records = [];
  List<Map<String, String>> _wantedDatabase = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _initSpeechEngine();
  }

  Future<void> _initSpeechEngine() async {
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _currentStatusText = 'يرجى منح إذن الميكروفون من الإعدادات');
      return;
    }

    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && _isListening) {
            Future.delayed(const Duration(milliseconds: 150), () {
              if (_isListening && mounted) {
                _startListeningSession();
              }
            });
          }
        },
        onError: (error) {
          if (_isListening && mounted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_isListening && mounted) {
                _startListeningSession();
              }
            });
          }
        },
      );

      if (available) {
        var locales = await _speech.locales();
        // اختيار اللغة العربية الأنسب في الجهاز
        var arLocale = locales.firstWhere(
          (l) => l.localeId.toLowerCase().contains('ar_eg') || l.localeId.toLowerCase().contains('ar_sa'),
          orElse: () => locales.firstWhere(
            (l) => l.localeId.toLowerCase().startsWith('ar'),
            orElse: () => stt.LocaleName('ar', 'Arabic'),
          ),
        );
        _selectedLocaleId = arLocale.localeId;
      }

      setState(() {
        _speechEnabled = available;
        _currentStatusText = available
            ? 'جاهز للرصد الصوتي - اضغط الميكروفون وتحدث'
            : 'خدمة التعرف الصوتي من Google غير مفعلة بالهاتف';
      });
    } catch (e) {
      setState(() => _currentStatusText = 'خطأ في الميكروفون: $e');
    }
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
        await _initSpeechEngine();
        if (!_speechEnabled) return;
      }
      setState(() {
        _isListening = true;
        _processedWordIndex = 0;
        _currentStatusText = 'تكلم الآن... (مثال: دال به دال 2718)';
      });
      _startListeningSession();
    }
  }

  void _startListeningSession() async {
    if (!_isListening) return;
    _processedWordIndex = 0;

    await _speech.listen(
      localeId: _selectedLocaleId,
      listenMode: stt.ListenMode.dictation,
      partialResults: true, // حاسم جداً: يقرأ كلامك لحظياً قبل انتهاء الجملة!
      cancelOnError: false,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      onSoundLevelChange: (level) {
        if (mounted) {
          setState(() {
            _soundLevel = level.clamp(0.0, 15.0);
          });
        }
      },
      onResult: (result) {
        if (!mounted) return;
        String fullSpoken = result.recognizedWords.trim();
        if (fullSpoken.isEmpty) return;

        // عرض النص المنطوق أمامك في الشريط العلوي لحظة بلحظة كما في الفيديو
        setState(() {
          _currentStatusText = fullSpoken;
        });

        // أخذ الجزء الجديد فقط من الكلام الذي لم نتحقق منه بعد في هذه الجلسة
        List<String> allWords = fullSpoken.split(RegExp(r'\s+'));
        if (_processedWordIndex > allWords.length) {
          _processedWordIndex = 0;
        }
        StringunprocessedSegment = allWords.sublist(_processedWordIndex).join(' ');

        // محاولة استخراج لوحة من الكلمات المنطوقة حالياً
        var extracted = LivePlateExtractor.extractFromLiveStream(unprocessedSegment);
        if (extracted != null) {
          // انتظر جزءاً صغيراً من الثانية أو تأكد من اكتمال 3-4 أرقام حتى لا يقطع الرقم قبل أن تكمل نطقه
          String digits = extracted['digits']!;
          if (digits.length >= 3 || result.finalResult) {
            _processedWordIndex = allWords.length; // تصفير المؤشر للبدء في التقاط اللوحة التالية!
            _addCapturedPlateToList(extracted);
          }
        }
      },
    );
  }

  void _addCapturedPlateToList(Map<String, String> parsed) {
    String letters = parsed['letters']!;
    String digits = parsed['digits']!;
    String carType = parsed['type']!;
    String plateKey = '${LivePlateExtractor.normalizeForComparison(letters)}-$digits';

    // منع إضافة نفس اللوحة مرتين في نفس الثانيتين بسبب تحديثات الصوت السريعة
    if (plateKey == _lastAddedPlateKey &&
        DateTime.now().difference(_lastAddedTime).inSeconds < 3) {
      return;
    }
    _lastAddedPlateKey = plateKey;
    _lastAddedTime = DateTime.now();

    // البحث في شيت الإكسيل للسيارات المطلوبة
    Map<String, String> matchedCar = _findInWantedDatabase(letters, digits);
    bool isWanted = matchedCar.isNotEmpty;

    setState(() {
      _records.insert(0, {
        'id': (_records.length + 1).toString(),
        'letters': letters,
        'digits': digits,
        'type': isWanted && (matchedCar['type'] ?? '').isNotEmpty && matchedCar['type'] != '-'
            ? matchedCar['type']!
            : carType,
        'district': _currentDistrict,
        'street': _currentStreet,
        'note': _selectedNote == 'بدون' ? '+' : _selectedNote,
        'status': isWanted ? 'مطلوبة' : 'مطابق',
        'time': TimeOfDay.now().format(context),
      });
      _saveData();
    });

    HapticFeedback.mediumImpact();

    if (isWanted) {
      // إطلاق الإنذار الصوتي والاهتزاز القوي وفتح نافذة التحذير الحمراء
      _triggerAlarmAndModal(matchedCar, letters, digits);
    }
  }

  Map<String, String> _findInWantedDatabase(String spokenLetters, String spokenDigits) {
    String normSpokenLetters = LivePlateExtractor.normalizeForComparison(spokenLetters);
    String normSpokenDigits = LivePlateExtractor.normalizeNumbers(spokenDigits).trim();

    for (var car in _wantedDatabase) {
      String dbDigits = LivePlateExtractor.normalizeNumbers(car['digits'] ?? '').trim();
      String dbLetters = LivePlateExtractor.normalizeForComparison(car['letters'] ?? '');

      if (dbDigits == normSpokenDigits && dbDigits.isNotEmpty) {
        if (dbLetters.isEmpty || dbLetters == normSpokenLetters || dbLetters.contains(normSpokenLetters) || normSpokenLetters.contains(dbLetters)) {
          return car;
        }
      }
    }
    return {};
  }

  void _triggerAlarmAndModal(Map<String, String> car, String letters, String digits) async {
    // تكرار نغمة التنبيه والاهتزاز لتنبيه المستخدم بقوة كما في الفيديو
    for (int i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 350));
    }
    if (mounted) {
      _showWantedAlertModal(car, letters, digits);
    }
  }

  // قراءة شيت الإكسيل بذكاء مهما كان ترتيب الأعمدة
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
        if (sheet == null) continue;

        for (int rowIndex = 0; rowIndex < sheet.rows.length; rowIndex++) {
          var row = sheet.rows[rowIndex];
          if (row.isEmpty) continue;

          // تجميع خلايا الصف
          List<String> cells = row.map((c) => c?.value?.toString().trim() ?? '').toList();
          String joinedRow = cells.join(' ');
          if (joinedRow.trim().isEmpty || joinedRow.contains('اللوحة') || joinedRow.contains('الحروف')) {
            continue; // تخطي صف العناوين
          }

          String foundDigits = '';
          String foundLetters = '';
          String type = '-';
          String owner = 'مطلوبة في الشيت';
          String chassis = '-';

          // البحث في خلايا الصف عن اللوحة (سواء في خلية واحدة مثل "د م س 9599" أو في خليتين)
          for (int c = 0; c < cells.length; c++) {
            String cellVal = LivePlateExtractor.normalizeNumbers(cells[c]);
            if (cellVal.isEmpty) continue;

            // هل الخلية تحتوي على حروف وأرقام معاً؟ (مثل: دمس 9599 أو د ب د 2718)
            var digitMatches = RegExp(r'\d{2,4}').allMatches(cellVal);
            var letterMatches = RegExp(r'[\u0621-\u064A\s]{2,10}').allMatches(cellVal);

            if (digitMatches.isNotEmpty && letterMatches.isNotEmpty && cellVal.length <= 15 && foundDigits.isEmpty) {
              foundDigits = digitMatches.first.group(0)!;
              String rawL = cellVal.replaceAll(RegExp(r'[\d\-\|_]'), '').trim();
              // تفريق الحروف إذا كانت ملتصقة مثل "دمس" -> "د م س"
              foundLetters = rawL.replaceAll(' ', '').split('').join(' ');
            } else if (RegExp(r'^\d{2,4}$').hasMatch(cellVal) && foundDigits.isEmpty) {
              foundDigits = cellVal;
            } else if (RegExp(r'^[\u0621-\u064A\s]{2,7}$').hasMatch(cellVal) && foundLetters.isEmpty && cellVal.replaceAll(' ', '').length <= 4) {
              foundLetters = cellVal.replaceAll(' ', '').split('').join(' ');
            } else if (RegExp(r'^[A-Za-z0-9]{10,20}$').hasMatch(cellVal)) {
              chassis = cellVal; // رقم الشاسيه / الهيكل
            } else if (type == '-') {
              type = cellVal;
            } else if (owner == 'مطلوبة في الشيت') {
              owner = cellVal;
            }
          }

          if (foundDigits.isNotEmpty) {
            extractedCars.add({
              'letters': foundLetters,
              'digits': foundDigits,
              'type': type,
              'owner': owner,
              'chassis': chassis,
              'row': (rowIndex + 1).toString(),
            });
          }
        }
      }

      setState(() {
        _wantedDatabase = extractedCars;
        _excelFileName = '${result.files.single.name} (${extractedCars.length} سيارة)';
        _saveData();
      });

      _checkHistoricalRecordsAgainstNewDatabase();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحميل شيت السيارات المطلوبة بنجاح (${extractedCars.length} لوحة)!', textDirection: TextDirection.rtl),
            backgroundColor: const Color(0xFF06D6A0),
          ),
        );
      }
    }
  }

  void _checkHistoricalRecordsAgainstNewDatabase() {
    for (var record in _records) {
      var match = _findInWantedDatabase(record['letters'] ?? '', record['digits'] ?? '');
      if (match.isNotEmpty && record['status'] != 'مطلوبة') {
        record['status'] = 'مطلوبة';
        _triggerAlarmAndModal(match, record['letters']!, record['digits']!);
      }
    }
    _saveData();
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

  // إضافة لوحة يدوياً للاختبار السريع أو الفحص اليدوي
  void _showManualCheckDialog() {
    TextEditingController lettersCtrl = TextEditingController();
    TextEditingController digitsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('فحص وإضافة لوحة يدوياً', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: lettersCtrl,
              textDirection: TextDirection.rtl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'الحروف (مثال: د ب د)', labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: digitsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'الأرقام (مثال: 2718)', labelStyle: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)),
            onPressed: () {
              if (digitsCtrl.text.trim().isNotEmpty) {
                String fLetters = lettersCtrl.text.trim().replaceAll(' ', '').split('').join(' ');
                Navigator.pop(context);
                _addCapturedPlateToList({
                  'letters
