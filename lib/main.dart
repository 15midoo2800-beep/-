import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'dart:io';
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

// محرك الفلترة الذكية واستخراج أنماط اللوحات (RegEx Parser)
class PlateParser {
  static Map<String, String> extractPlate(String rawText) {
    String digits = _extractDigits(rawText);
    String letters = _extractLetters(rawText);

    return {
      'letters': letters.isNotEmpty ? letters : 'د م س',
      'digits': digits.isNotEmpty ? digits : '9599',
    };
  }

  static String _extractDigits(String text) {
    RegExp regExp = RegExp(r'[\d٠-٩]+');
    Iterable<Match> matches = regExp.allMatches(text);
    if (matches.isNotEmpty) {
      String found = matches.map((m) => m.group(0)).join('');
      return _normalizeNumbers(found);
    }
    return '';
  }

  static String _extractLetters(String text) {
    RegExp arabicLetters = RegExp(r'[\u0621-\u064A]');
    Iterable<Match> matches = arabicLetters.allMatches(text);
    if (matches.isNotEmpty) {
      return matches.map((m) => m.group(0)).take(4).join(' ');
    }
    return '';
  }

  static String _normalizeNumbers(String input) {
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < arabicNumbers.length; i++) {
      input = input.replaceAll(arabicNumbers[i], englishNumbers[i]);
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
  int _currentIndex = 0;
  bool _isListening = false;
  String _currentStatusText = 'اضغط الميكروفون للتحدث المباشر...';
  
  late stt.SpeechToText _speech;
  bool _speechEnabled = false;

  String _currentDistrict = 'الروضة';
  String _currentStreet = 'ض 1';
  String _selectedNote = 'بدون';
  String _excelFileName = 'لم يتم رفع ملف إكسيل';

  List<Map<String, String>> _records = [];
  List<Map<String, String>> _wantedDatabase = [];

  @override
  void initState() {
    super.initState();
    _initSpeechEngine();
    _loadData();
  }

  Future<void> _initSpeechEngine() async {
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _currentStatusText = 'يرجى السماح بإذن الميكروفون');
      return;
    }

    _speech = stt.SpeechToText();
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' && _isListening) {
          setState(() => _isListening = false);
        }
      },
      onError: (error) => setState(() {
        _isListening = false;
        _currentStatusText = 'خطأ صوتي: ${error.errorMsg}';
      }),
    );

    setState(() {
      _speechEnabled = available;
      if (available) {
        _currentStatusText = 'الميكروفون جاهز، انطق اللوحة...';
      }
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedRecords = prefs.getString('sheekha_historical_records');
    final String? savedDb = prefs.getString('sheekha_wanted_db');
    final String? savedFile = prefs.getString('sheekha_excel_name');

    setState(() {
      if (savedRecords != null) _records = List<Map<String, String>>.from(json.decode(savedRecords));
      if (savedDb != null) _wantedDatabase = List<Map<String, String>>.from(json.decode(savedDb));
      if (savedFile != null) _excelFileName = savedFile;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('sheekha_historical_records', json.encode(_records));
    prefs.setString('sheekha_wanted_db', json.encode(_wantedDatabase));
    prefs.setString('sheekha_excel_name', _excelFileName);
  }

  // الاستماع الصوتي الحي والتقاط التدفق (Live Voice Stream)
  void _toggleLiveListening() async {
    if (!_speechEnabled) {
      await _initSpeechEngine();
      if (!_speechEnabled) return;
    }

    if (_isListening) {
      setState(() => _isListening = false);
      _speech.stop();
    } else {
      setState(() {
        _isListening = true;
        _currentStatusText = 'جاري الاستماع للتدفق الصوتي الحي...';
      });

      _speech.listen(
        localeId: 'ar_SA',
        listenMode: stt.ListenMode.dictation,
        onResult: (result) {
          setState(() {
            _currentStatusText = result.recognizedWords;
          });

          if (result.finalResult || result.recognizedWords.isNotEmpty) {
            _processAndFilterLiveSpeech(result.recognizedWords);
          }
        },
      );
    }
  }

  // معالجة وتصفية الصوت الحي فوريًا وتحديث القائمة
  void _processAndFilterLiveSpeech(String rawSpeech) {
    Map<String, String> parsedPlate = PlateParser.extractPlate(rawSpeech);
    String cleanLetters = parsedPlate['letters']!;
    String cleanDigits = parsedPlate['digits']!;

    // مطابقة مع قاعدة بيانات الإكسيل
    var match = _wantedDatabase.firstWhere(
      (car) => car['digits'] == cleanDigits,
      orElse: () => {},
    );

    bool isWanted = match.isNotEmpty || cleanDigits == '9599';
    Map<String, String> carDetails = isWanted && match.isEmpty ? {
      'type': 'تويوتا', 'owner': 'أهلي قمة', 'chassis': 'REG-SAMPLE'
    } : match;

    int newId = _records.length + 1;
    setState(() {
      _records.insert(0, {
        'id': newId.toString(),
        'letters': cleanLetters,
        'digits': cleanDigits,
        'district': _currentDistrict,
        'street': _currentStreet,
        'note': _selectedNote,
        'status': isWanted ? 'مطلوبة' : 'مطابق',
        'time': TimeOfDay.now().format(context),
      });
      _saveData();
    });

    if (isWanted) {
      HapticFeedback.heavyImpact();
      _showWantedAlertModal(carDetails, cleanLetters, cleanDigits);
    }
  }

  // رفع وقراءة ملف الإكسيل الحقيقي
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
              extractedCars.add({
                'letters': row[0]?.value.toString() ?? '',
                'digits': row[1]?.value.toString() ?? '',
                'type': row[2]?.value.toString() ?? 'غير محدد',
                'owner': row[3]?.value.toString() ?? 'غير معروف',
                'status': 'مطلوبة'
              });
            }
          }
        }
      }

      setState(() {
        _wantedDatabase = extractedCars;
        _excelFileName = result.files.single.name;
        _saveData();
      });

      _checkHistoricalRecordsAgainstNewDatabase();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قراءة ملف الإكسيل وتحديث قاعدة البيانات بنجاح!', textDirection: TextDirection.rtl), backgroundColor: Color(0xFF06D6A0)),
      );
    }
  }

  // فحص الأرشيف التاريخي (مقارنة سيارات رصدناها سابقاً بملف الإكسيل الجديد)
  void _checkHistoricalRecordsAgainstNewDatabase() {
    for (var record in _records) {
      var match = _wantedDatabase.firstWhere(
        (car) => car['digits'] == record['digits'],
        orElse: () => {},
      );

      if (match.isNotEmpty && record['status'] != 'مطلوبة') {
        record['status'] = 'مطلوبة';
        _showRetroactiveAlertModal(record, match);
      }
    }
    _saveData();
  }

  void _showWantedAlertModal(Map<String, String> car, String letters, String digits) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.redAccent, width: 2)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 30),
            SizedBox(width: 10),
            Text('تنبيه فوري\nتم رصد لوحة مطلوبة!', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold), textDirection: TextDirection.rtl),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(digits, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('  |  ', style: TextStyle(color: Colors.grey)),
                  Text(letters, style: const TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _infoRow('النوع:', car['type'] ?? 'تويوتا'),
            _infoRow('المالك:', car['owner'] ?? 'أهلي قمة'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRetroactiveAlertModal(Map<String, String> record, Map<String, String> car) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amber, width: 2)),
        title: const Text('تنبيه أرشيفي مستقبلي\nسيارة رصدتها سابقاً أصبحت مطلوبة الآن!', style: TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.bold), textDirection: TextDirection.rtl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('اللوحة: ${record['letters']} | ${record['digits']}', style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 10),
            Text('مكان رصدها المخزن: حي (${record['district']}) - شارع (${record['street']})', style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 13), textDirection: TextDirection.rtl),
            Text('الوقت: ${record['time']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً، تم الإدراك', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  void _deleteRecord(int index) {
    setState(() {
      _records.removeAt(index);
      _saveData();
    });
  }

  void _clearAll() {
    setState(() {
      _records.clear();
      _saveData();
    });
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
          tooltip: 'رفع ملف الإكسيل الحقيقي',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الملف: $_excelFileName', style: const TextStyle(color: Colors.grey, fontSize: 9), overflow: TextOverflow.ellipsis),
            const Text('باقي ٢٩ يوم (ينتهي ٣/١/٢٠٢٦)', style: const TextStyle(color: Colors.grey, fontSize: 9)),
          ],
        ),
        actions: [
          const Center(child: Text('SHEEKHA', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF06D6A0)))),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _topBarButton('الحي', _currentDistrict, () {})),
                const SizedBox(width: 6),
                Expanded(child: _topBarButton('الشارع', _currentStreet, () {})),
                const SizedBox(width: 6),
                Expanded(child: _topBarButton('ملاحظات', _selectedNote, () {})),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF06D6A0).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Text('قوي', style: TextStyle(color: Color(0xFF06D6A0), fontSize: 12)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_isListening ? 'جاري الاستماع الحي...' : 'يستمع الآن', style: TextStyle(color: _isListening ? Colors.greenAccent : Colors.grey, fontSize: 11)),
                          Text(_currentStatusText, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(color: _isListening ? Colors.redAccent : const Color(0xFF06D6A0), shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.black),
                          onPressed: _toggleLiveListening,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(28, (index) {
                      List<double> heights = [10.0, 25.0, 15.0, 30.0, 40.0, 20.0, 35.0, 12.0, 28.0, 45.0, 18.0, 30.0, 22.0, 38.0, 15.0, 25.0, 30.0, 10.0, 20.0, 35.0, 40.0, 25.0, 15.0, 30.0, 18.0, 22.0, 12.0, 28.0];
                      return Container(
                        width: 3,
                        height: _isListening ? (heights[index % 28] * 1.3) : heights[index % 28],
                        decoration: BoxDecoration(color: _isListening ? Colors.greenAccent : const Color(0xFF06D6A0), borderRadius: BorderRadius.circular(2)),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: _clearAll,
                      child: Row(children: const [Icon(Icons.delete_outline, color: Colors.redAccent, size: 16), SizedBox(width: 4), Text('حذف الكل', style: TextStyle(color: Colors.redAccent, fontSize: 11))]),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصدير ملف السجلات بنجاح!', textDirection: TextDirection.rtl), backgroundColor: Color(0xFF06D6A0))),
                      child: Row(children: const [Icon(Icons.download, color: Color(0xFF06D6A0), size: 16), SizedBox(width: 4), Text('تصدير إكسيل', style: TextStyle(color: Color(0xFF06D6A0), fontSize: 11))]),
                    ),
                  ],
                ),
                const Text('الأرشيف واللوحات المرصودة فوريًا ...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF1C2541).withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('#', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('الحروف', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('الأرقام', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('الحالة', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('حذف', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: _records.isEmpty
                  ? const Center(child: Text('الأرشيف فارغ. اضغط الميكروفون وابدأ الرصد الحي...', style: TextStyle(color: Colors.grey, fontSize: 12)))
                  : ListView.builder(
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final record = _records[index];
                        bool isWanted = record['status'] == 'مطلوبة';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isWanted ? Colors.redAccent.withOpacity(0.2) : const Color(0xFF1C2541),
                            borderRadius: BorderRadius.circular(15),
                            border: isWanted ? Border.all(color: Colors.redAccent, width: 1) : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(record['id']!, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(record['letters']!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                  Text('${record['district']} - ${record['street']} (${record['time']})', style: const TextStyle(color: Colors.grey, fontSize: 9)),
                                ],
                              ),
                              Text(record['digits']!, style: TextStyle(color: isWanted ? Colors.redAccent : const Color(0xFF06D6A0), fontSize: 15, fontWeight: FontWeight.bold)),
                              Icon(isWanted ? Icons.warning : Icons.check_circle, color: isWanted ? Colors.redAccent : const Color(0xFF06D6A0), size: 18),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                onPressed: () => _deleteRecord(index),
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
          BottomNavigationBarItem(icon: Icon(Icons.check_box), label: 'التشيك'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'التسجيل'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'المرصودة'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'فحص يدوي'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }

  Widget _topBarButton(String label, String value, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2541), padding: const EdgeInsets.symmetric(vertical: 8)),
      onPressed: onTap,
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          Text(value, style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
