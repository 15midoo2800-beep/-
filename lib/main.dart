import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const CarTrackerApp());
}

class CarTrackerApp extends StatelessWidget {
  const CarTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'رصد - رصد السيارات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

class CarRecord {
  final String letters;
  final String numbers;
  final String type;
  final DateTime timestamp;

  CarRecord({
    required this.letters,
    required this.numbers,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'letters': letters,
        'numbers': numbers,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CarRecord.fromJson(Map<String, dynamic> json) => CarRecord(
        letters: json['letters'],
        numbers: json['numbers'],
        type: json['type'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _text = 'اضغط على الميكروفون وابدأ الحديث...';
  String _liveTranscript = ''; // الشريط المباشر لما يتم استماعه
  List<CarRecord> _records = [];
  
  // التحكم في حالة انتظار نوع السيارة
  String? _pendingLetters;
  String? _pendingNumbers;
  Timer? _typeWaitTimer;

  // القواميس المخصصة للنطق الشخصي واللهجة المصرية
  final Map<String, String> _lettersMap = {
    'ألف': 'أ', 'الف': 'أ', 'أ': 'أ', 'ا': 'أ', 'آ': 'أ',
    'باء': 'ب', 'به': 'ب', 'بة': 'ب', 'با': 'ب', 'ب': 'ب', 'بي': 'ب',
    'حاء': 'ح', 'حه': 'ح', 'حة': 'ح', 'حا': 'ح', 'ح': 'ح',
    'دال': 'د', 'ده': 'د', 'دا': 'د', 'د': 'د',
    'ر': 'ر', 'راء': 'ر', 'ره': 'ر', 'رة': 'ر', 'را': 'ر',
    'سين': 'س', 'سن': 'س', 'سا': 'س', 'س': 'س',
    'صاد': 'ص', 'صد': 'ص', 'صا': 'ص', 'ص': 'ص',
    'طقم': 'ط', 'طاء': 'ط', 'طه': 'ط', 'طا': 'ط', 'ط': 'ط',
    'عين': 'ع', 'عن': 'ع', 'عاين': 'ع', 'ع': 'ع',
    'قاف': 'ق', 'قف': 'ق', 'قا': 'ق', 'ق': 'ق',
    'كاف': 'ك', 'كف': 'ك', 'كا': 'ك', 'ك': 'ك',
    'لام': 'ل', 'لم': 'ل', 'لا': 'ل', 'ل': 'ل',
    'ميم': 'م', 'مم': 'م', 'ما': 'م', 'م': 'م',
    'نون': 'ن', 'نن': 'ن', 'نا': 'ن', 'ن': 'ن',
    'هاء': 'ه', 'هه': 'ه', 'ها': 'ه', 'ه': 'ه',
    'واو': 'و', 'وو': 'و', 'وا': 'و', 'و': 'و',
    'ياء': 'ي', 'يه': 'ي', 'ية': 'ي', 'يا': 'ي', 'ي': 'ي', 'ى': 'ي',
  };

  final Map<String, String> _digitsMap = {
    'صفر': '0', '0': '0', '٠': '0',
    'واحد': '1', 'واحدة': '1', 'واحده': '1', '1': '1', '١': '1',
    'اثنان': '2', 'اثنين': '2', 'إثنين': '2', 'اتنين': '2', '2': '2', '٢': '2',
    'ثلاثة': '3', 'ثلاثه': '3', 'تلاتة': '3', 'تلاته': '3', '3': '3', '٣': '3',
    'أربعة': '4', 'اربعة': '4', 'اربعة': '4', 'اربعة': '4', 'اربعة': '4', '4': '4', '٤': '4', 'اربعه': '4',
    'خمسة': '5', 'خمسه': '5', '5': '5', '٥': '5',
    'ستة': '6', 'سته': '6', '6': '6', '٦': '6',
    'سبعة': '7', 'سبعه': '7', '7': '7', '٧': '7',
    'ثمانية': '8', 'ثمانيه': '8', 'تمانية': '8', 'تمانيه': '8', '8': '8', '٨': '8',
    'تسعة': '9', 'تسعه': '9', '9': '9', '٩': '9',
  };

  final Map<String, String> _vehicleTypesMap = {
    'جراند ماكس': 'جراند ماكس',
    'قراند ماكس': 'جراند ماكس',
    'جراند مكس': 'جراند ماكس',
    'جراند': 'جراند ماكس',
    'هاي اس': 'هاي اس',
    'هايس': 'هاي اس',
    'هاي آيس': 'هاي اس',
    'هايسن': 'هاي اس',
    'تلاجة كبيرة': 'تلاجة كبيرة',
    'تلاجه كبيره': 'تلاجة كبيرة',
    'ثلاجة كبيرة': 'تلاجة كبيرة',
    'ثلاجه': 'تلاجة كبيرة',
    'تلاجه': 'تلاجة كبيرة',
    'نقل': 'نقل',
    'نقل عام': 'نقل عام',
    'فان': 'فان',
    'بيك اب': 'بيك اب',
    'ملاكي': 'ملاكي',
    'اتوبيس': 'اتوبيس',
    'أوتوبيس': 'اتوبيس',
    'باص': 'باص',
  };

  @override
  void initState() {
    super.initState() ;
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();
    _loadRecords();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("ar-SA");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  void _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsString = prefs.getString('car_records');
    if (recordsString != null) {
      final List<dynamic> jsonList = jsonDecode(recordsString);
      setState(() {
        _records = jsonList.map((item) => CarRecord.fromJson(item)).toList();
      });
    }
  }

  void _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString =
        jsonEncode(_records.map((r) => r.toJson()).toList());
    await prefs.setString('car_records', jsonString);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _liveTranscript = val.recognizedWords;
            _text = val.recognizedWords;
            _processVoiceInput(val.recognizedWords);
          }),
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          localeId: 'ar_SA',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // دالة معالجة الصوت والربط بالأنماط والمصفوفات الذكية
  void _processVoiceInput(String input) {
    if (input.isEmpty) return;

    // حالة انتظار إدخال نوع السيارة للوحات أ أو ب
    if (_pendingLetters != null && _pendingNumbers != null) {
      for (var entry in _vehicleTypesMap.entries) {
        if (input.contains(entry.key)) {
          _commitRecord(_pendingLetters!, _pendingNumbers!, entry.value);
          _clearPendingState();
          return;
        }
      }
    }

    // استخلاص الحروف والأرقام من النص المسموع
    List<String> words = input.trim().split(RegExp(r'\s+'));
    List<String> extractedLetters = [];
    List<String> extractedNumbers = [];

    for (String word in words) {
      if (_lettersMap.containsKey(word)) {
        extractedLetters.add(_lettersMap[word]!);
      } else if (_digitsMap.containsKey(word)) {
        extractedNumbers.add(_digitsMap[word]!);
      } else {
        // فحص الأرقام إذا جاءت كأرقام مدمجة داخل الكلمة
        for (int i = 0; i < word.length; i++) {
          String char = word[i];
          if (_digitsMap.containsKey(char)) {
            extractedNumbers.add(_digitsMap[char]!);
          }
        }
      }
    }

    // مطابقة النمط (3 حروف + 4 أرقام أو أرقام من مكتشف الصوت)
    if (extractedLetters.length >= 3 && extractedNumbers.isNotEmpty) {
      String lettersStr = extractedLetters.take(3).join(' ');
      String numbersStr = extractedNumbers.join();

      if (numbersStr.length > 4) {
        numbersStr = numbersStr.substring(0, 4);
      }

      // التحقق مما إذا كانت اللوحة تبدأ بـ (أ) أو (ب) لاستدعاء حالة الانتظار الذكية للنوع
      String firstLetter = extractedLetters.first;
      if (firstLetter == 'أ' || firstLetter == 'ب') {
        _pendingLetters = lettersStr;
        _pendingNumbers = numbersStr;

        // البحث إن كان النوع قد نُطق بالفعل في نفس الجملة
        String detectedType = 'غير محدد';
        for (var entry in _vehicleTypesMap.entries) {
          if (input.contains(entry.key)) {
            detectedType = entry.value;
            break;
          }
        }

        if (detectedType != 'غير محدد') {
          _commitRecord(lettersStr, numbersStr, detectedType);
          _clearPendingState();
        } else {
          // فتح نافذة انتظار لمدة ثانيتين للالتقاط
          _typeWaitTimer?.cancel();
          _typeWaitTimer = Timer(const Duration(seconds: 2), () {
            if (_pendingLetters != null) {
              _commitRecord(_pendingLetters!, _pendingNumbers!, 'غير محدد');
              _clearPendingState();
            }
          });
        }
      } else {
        // لوحة عادية تسجل فوراً
        _commitRecord(lettersStr, numbersStr, 'عام');
      }
    }
  }

  void _commitRecord(String letters, String numbers, String type) {
    // منع التكرار المباشر للنفس اللوحة
    if (_records.isNotEmpty &&
        _records.first.letters == letters &&
        _records.first.numbers == numbers) {
      return;
    }

    final newRecord = CarRecord(
      letters: letters,
      numbers: numbers,
      type: type,
      timestamp: DateTime.now(),
    );

    setState(() {
      _records.insert(0, newRecord);
    });
    _saveRecords();
    _speak('تم رصد اللوحة $letters $numbers $type');
  }

  void _clearPendingState() {
    _pendingLetters = null;
    _pendingNumbers = null;
    _typeWaitTimer?.cancel();
  }

  void _addManualRecord(String letters, String numbers, String type) {
    if (letters.isEmpty || numbers.isEmpty) return;
    final newRecord = CarRecord(
      letters: letters,
      numbers: numbers,
      type: type.isEmpty ? 'عام' : type,
      timestamp: DateTime.now(),
    );
    setState(() {
      _records.insert(0, newRecord);
    });
    _saveRecords();
  }

  void _showAddDialog() {
    final lettersController = TextEditingController();
    final numbersController = TextEditingController();
    final typeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة سيارة يدويًا', textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: lettersController,
              decoration: const InputDecoration(
                  labelText: 'الأحرف (مثال: ح ص ب)',
                  border: OutlineInputBorder()),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: numbersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'الأرقام (مثال: 6833)',
                  border: OutlineInputBorder()),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: typeController,
              decoration: const InputDecoration(
                  labelText: 'نوع السيارة (اختياري)',
                  border: OutlineInputBorder()),
              textAlign: TextAlign.right,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              _addManualRecord(
                lettersController.text,
                numbersController.text,
                typeController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _deleteRecord(int index) {
    setState(() {
      _records.removeAt(index);
    });
    _saveRecords();
  }

  void _clearAllRecords() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الكل', textAlign: TextAlign.right),
        content: const Text('هل أنت تأكد من حذف جميع السجلات؟',
            textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _records.clear();
              });
              _saveRecords();
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رصد - رصد السيارات المطلوبة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllRecords,
              tooltip: 'حذف الكل',
            ),
        ],
      ),
      body: Column(
        children: [
          // شريط الحالة والاستماع المباشر
          Container(
            padding: const EdgeInsets.all(16.0),
            color: _isListening ? Colors.indigo.shade50 : Colors.grey.shade100,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isListening ? Icons.mic : Icons.mic_off,
                      color: _isListening ? Colors.red : Colors.grey,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isListening ? 'يستمع الآن...' : 'الميكروفون متوقف',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isListening ? Colors.red : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // الشريط اللبني الذي يظهر النص المكتشف فوراً
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.shade50,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.lightBlue.shade200),
                  ),
                  child: Text(
                    _liveTranscript.isEmpty
                        ? _text
                        : 'النص المسموع: $_liveTranscript',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15,
                        color: Colors.indigo,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          
          // عرض القائمة السفلية للسجلات
          Expanded(
            child: _records.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد سجلات حاليًا\nابدأ بالتحدث أو أضف يدويًا',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo,
                            child: Text(
                              '${_records.length - index}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            '${record.letters} | ${record.numbers}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          subtitle: Text(
                            'النوع: ${record.type} - الوقت: ${record.timestamp.hour}:${record.timestamp.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _deleteRecord(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _showAddDialog,
            heroTag: 'add_manual',
            backgroundColor: Colors.orange,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.large(
            onPressed: _listen,
            heroTag: 'mic_listen',
            backgroundColor: _isListening ? Colors.red : Colors.indigo,
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}
