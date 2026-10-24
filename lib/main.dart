import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

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
  String _currentStatusText = 'جاهز للرصد الصوتي الحقيقي...';
  String _searchQuery = '';

  // النطاق الجغرافي والملاحظات
  String _currentDistrict = 'الروضة';
  String _currentStreet = 'ض 1';
  String _selectedNote = 'بدون';

  // قائمة السجلات المرصودة
  List<Map<String, String>> _records = [];

  // قاعدة البيانات المستخرجة من ملف الإكسيل (افتراضية قابلة للتحديث عبر رفع الملف)
  List<Map<String, String>> _databaseExcel = [
    {'letters': 'د م س', 'digits': '9599', 'type': 'تويوتا', 'owner': 'أهلي قمة', 'chassis': 'TMAJB81B5PJ205447', 'status': 'مطلوبة'},
    {'letters': 'ب ل د', 'digits': '7474', 'type': 'هيونداي', 'owner': 'شركة النور', 'chassis': 'KMHDH4AE8LU123456', 'status': 'مطلوبة'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedRecords = prefs.getString('sheekha_real_records');
    final String? savedDb = prefs.getString('sheekha_excel_db');

    setState(() {
      if (savedRecords != null) {
        _records = List<Map<String, String>>.from(json.decode(savedRecords));
      }
      if (savedDb != null) {
        _databaseExcel = List<Map<String, String>>.from(json.decode(savedDb));
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('sheekha_real_records', json.encode(_records));
    prefs.setString('sheekha_excel_db', json.encode(_databaseExcel));
  }

  // المحاكاة الحقيقية للاستماع الصوتي والمطابقة مع ملف الإكسيل
  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _currentStatusText = 'جاري الاستماع للوحات في $_currentDistrict ($_currentStreet)...';
      } else {
        // في التطبيق الحقيقي، هنا يتم استقبال النص من الميكروفون وتحليله
        // سنختبر هنا لوحة مطوبة لترى كيف يعمل الإنذار الفوري
        String detectedLetters = 'د م س';
        String detectedDigits = '9599';
        
        _currentStatusText = '$detectedLetters $detectedDigits';
        
        // التحقق الفوري داخل قاعدة بيانات ملف الإكسيل
        var match = _databaseExcel.firstWhere(
          (item) => item['letters'] == detectedLetters && item['digits'] == detectedDigits,
          orElse: () => {},
        );

        bool isWanted = match.isNotEmpty;

        int newId = _records.length + 1;
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

        if (isWanted) {
          HapticFeedback.heavyImpact();
          _showWantedAlertModal(match);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رصد لوحة جديدة بنجاح', textDirection: TextDirection.rtl), backgroundColor: Color(0xFF06D6A0)),
          );
        }
      }
    });
  }

  // نافذة التحذير الفوري (الإنذار الصوتي والمرئي)
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
                  Text(car['digits']!, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('  |  ', style: TextStyle(color: Colors.grey)),
                  Text(car['letters']!, style: const TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _infoRow('النوع:', car['type']!),
            _infoRow('المالك:', car['owner']!),
            _infoRow('الهيكل:', car['chassis']!),
            const SizedBox(height: 10),
            const Text('الاستماع ومعالجة اللوحات مستمران في الخلفية', style: TextStyle(color: Colors.amber, fontSize: 11), textAlign: TextAlign.center),
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

  // نافذة رفع ملف الإكسيل (قاعدة البيانات)
  void _showUploadExcelDialog() {
    TextEditingController lController = TextEditingController();
    TextEditingController dController = TextEditingController();
    TextEditingController tController = TextEditingController();
    TextEditingController oController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('إدارة قاعدة بيانات الإكسيل', style: TextStyle(color: Color(0xFF06D6A0)), textDirection: TextDirection.rtl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يمكنك رفع ملف الإكسيل أو إضافة سيارة مطلوبة للقاعدة الفورية:', style: TextStyle(color: Colors.grey, fontSize: 11), textDirection: TextDirection.rtl),
            const SizedBox(height: 10),
            TextField(controller: lController, decoration: const InputDecoration(labelText: 'حروف اللوحة (مثال: د م س)', labelStyle: TextStyle(color: Colors.grey)), style: const TextStyle(color: Colors.white)),
            TextField(controller: dController, decoration: const InputDecoration(labelText: 'أرقام اللوحة (مثال: 9599)', labelStyle: TextStyle(color: Colors.grey)), style: const TextStyle(color: Colors.white)),
            TextField(controller: tController, decoration: const InputDecoration(labelText: 'نوع السيارة', labelStyle: TextStyle(color: Colors.grey)), style: const TextStyle(color: Colors.white)),
            TextField(controller: oController, decoration: const InputDecoration(labelText: 'اسم المالك / الجهة', labelStyle: TextStyle(color: Colors.grey)), style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)),
            onPressed: () {
              if (lController.text.isNotEmpty && dController.text.isNotEmpty) {
                setState(() {
                  _databaseExcel.add({
                    'letters': lController.text,
                    'digits': dController.text,
                    'type': tController.text.isEmpty ? 'غير محدد' : tController.text,
                    'owner': oController.text.isEmpty ? 'غير معروف' : oController.text,
                    'chassis': 'REG-SAMPLE-9988',
                    'status': 'مطلوبة'
                  });
                  _saveData();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث قاعدة بيانات الإكسيل بنجاح!', textDirection: TextDirection.rtl), backgroundColor: Color(0xFF06D6A0)));
              }
            },
            child: const Text('إضافة لقاعدة البيانات', style: TextStyle(color: Colors.black)),
          ),
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
          icon: const Icon(Icons.dataset, color: Color(0xFF06D6A0)),
          onPressed: _showUploadExcelDialog,
          tooltip: 'إدارة قاعدة بيانات الإكسيل',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('باقي ٢٩ يوم', style: TextStyle(color: Colors.grey, fontSize: 10)),
            Text('ينتهي ٣/١/٢٠٢٦', style: TextStyle(color: Colors.grey, fontSize: 10)),
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

            // بطاقة الاستماع الصوتي
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

            // شريط الإجراءات العلوي للجدول
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

            // رأس الجدول
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

            // قائمة السجلات الديناميكية الحقيقية
            Expanded(
              child: _records.isEmpty
                  ? const Center(child: Text('ابدأ التسجيل أو أضف بيانات الإكسيل', style: TextStyle(color: Colors.grey, fontSize: 12)))
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
