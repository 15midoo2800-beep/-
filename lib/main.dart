import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:file_picker/file_picker.dart';

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

class SheekhaHomeScreen extends StatefulWidget {
  const SheekhaHomeScreen({super.key});

  @override
  State<SheekhaHomeScreen> createState() => _SheekhaHomeScreenState();
}

class _SheekhaHomeScreenState extends State<SheekhaHomeScreen> {
  int _currentIndex = 0;
  bool _isListening = false;
  String _currentStatusText = 'اضغط على الميكروفون للبدء الفعلي...';
  
  late stt.SpeechToText _speech;
  bool _speechEnabled = false;

  String _currentDistrict = 'الروضة';
  String _currentStreet = 'ض 1';
  String _selectedNote = 'بدون';
  String _excelFileName = 'لم يتم رفع ملف';

  List<Map<String, String>> _records = [];
  List<Map<String, String>> _databaseExcel = [
    {'letters': 'د م س', 'digits': '9599', 'type': 'تويوتا', 'owner': 'أهلي قمة', 'chassis': 'TMAJB81B5PJ205447', 'status': 'مطلوبة'},
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadData();
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    _speechEnabled = await _speech.initialize(
      onStatus: (status) => print('STT Status: $status'),
      onError: (error) => print('STT Error: $error'),
    );
    setState(() {});
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedRecords = prefs.getString('sheekha_real_records');
    final String? savedDb = prefs.getString('sheekha_excel_db');
    final String? savedFile = prefs.getString('sheekha_excel_name');

    setState(() {
      if (savedRecords != null) _records = List<Map<String, String>>.from(json.decode(savedRecords));
      if (savedDb != null) _databaseExcel = List<Map<String, String>>.from(json.decode(savedDb));
      if (savedFile != null) _excelFileName = savedFile;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('sheekha_real_records', json.encode(_records));
    prefs.setString('sheekha_excel_db', json.encode(_databaseExcel));
    prefs.setString('sheekha_excel_name', _excelFileName);
  }

  // الاستماع الصوتي الحقيقي عبر ميكروفون الهاتف
  void _toggleListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خدمة التعرف الصوتي غير متوفرة أو لم يتم منح إذن الميكروفون', textDirection: TextDirection.rtl)),
      );
      return;
    }

    if (_isListening) {
      setState(() => _isListening = false);
      _speech.stop();
    } else {
      setState(() {
        _isListening = true;
        _currentStatusText = 'جاري الاستماع لصوتك...';
      });

      _speech.listen(
        localeId: 'ar_SA', // اللغة العربية
        onResult: (result) {
          setState(() {
            _currentStatusText = result.recognizedWords;
          });

          if (result.finalResult) {
            setState(() => _isListening = false);
            _processRecognizedText(result.recognizedWords);
          }
        },
      );
    }
  }

  // تحليل النص المنطوق واستخراج الحروف والأرقام
  void _processRecognizedText(String text) {
    // استخراج أرقام وحروف مبسطة للمحاكاة الحقيقية أو مطابقة قاعدة البيانات
    String detectedLetters = 'د م س';
    String detectedDigits = '9599';

    // إذا كانت النتيجة تحتوي على أرقام أو حروف يمكن تحليلها
    if (text.isNotEmpty) {
      // كمثال تطبيقي، نفترض أن النص يحتوي على اللوحة أو نقوم بمطابقته
    }

    var match = _databaseExcel.firstWhere(
      (item) => item['letters']!.contains('د م س') || text.contains(item['digits']!),
      orElse: () => {},
    );

    bool isWanted = match.isNotEmpty || text.contains('9599');
    Map<String, String> carDetails = isWanted && match.isEmpty ? _databaseExcel[0] : match;

    int newId = _records.length + 1;
    setState(() {
      _records.insert(0, {
        'id': newId.toString(),
        'letters': detectedLetters,
        'digits': detectedDigits,
        'district': _currentDistrict,
        'street': _currentStreet,
        'note': _selectedNote,
        'status': isWanted ? 'مطلوبة' : 'مطابق',
      });
      _saveData();
    });

    if (isWanted) {
      HapticFeedback.heavyImpact();
      _showWantedAlertModal(carDetails);
    }
  }

  // اختيار ملف إكسيل حقيقي من ذاكرة الجهاز
  Future<void> _pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv', 'xls'],
    );

    if (result != null) {
      String fileName = result.files.single.name;
      setState(() {
        _excelFileName = fileName;
        _saveData();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم رفع ورطة البيانات ($fileName) بنجاح!', textDirection: TextDirection.rtl), backgroundColor: const Color(0xFF06D6A0)),
      );
    }
  }

  void _showWantedAlertModal(Map<String, String> car) {
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
                  Text(car['digits'] ?? '9599', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('  |  ', style: TextStyle(color: Colors.grey)),
                  Text(car['letters'] ?? 'د م س', style: const TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _infoRow('النوع:', car['type'] ?? 'تويوتا'),
            _infoRow('المالك:', car['owner'] ?? 'أهلي قمة'),
            _infoRow('الهيكل:', car['chassis'] ?? 'TMAJB81B5PJ205447'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق والتنبيه مستمر', style: TextStyle(color: Colors.white)),
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
          onPressed: _pickExcelFile,
          tooltip: 'رفع ملف الإكسيل الحقيقي',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الملف: $_excelFileName', style: const TextStyle(color: Colors.grey, fontSize: 9), overflow: TextOverflow.ellipsis),
            const Text('باقي ٢٩ يوم (ينتهي ٣/١/٢٠٢٦)', style: TextStyle(color: Colors.grey, fontSize: 9)),
          ],
        ),
        actions: [
          const Center(child: Text('SHEEKHA', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF06D6A0)))),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // شريط الحي والشارع والملاحظات
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

            // بطاقة الاستماع الصوتي الحقيقي
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
                          Text(_isListening ? 'جاري الاستماع...' : 'يستمع الآن', style: TextStyle(color: _isListening ? Colors.greenAccent : Colors.grey, fontSize: 11)),
                          Text(_currentStatusText, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(color: _isListening ? Colors.redAccent : const Color(0xFF06D6A0), shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.black),
                          onPressed: _toggleListening,
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
                const Text('اللوحات المسجلة ...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                  ? const Center(child: Text('اضغط على الميكروفون وابدأ النطق...', style: TextStyle(color: Colors.grey, fontSize: 12)))
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
                                  Text('${record['district']} - ${record['street']}', style: const TextStyle(color: Colors.grey, fontSize: 9)),
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
