import 'package:flutter/material.dart';

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
  String _currentStatusText = 'واو نون سين أربع';

  // قائمة السجلات الديناميكية القابلة للتعديل والحذف
  final List<Map<String, String>> _records = [
    {'id': '4', 'letters': 'و ن س', 'digits': '7777'},
    {'id': '3', 'letters': 'ب ل د', 'digits': '7474'},
    {'id': '2', 'letters': 'ا ع ك', 'digits': '2828'},
    {'id': '1', 'letters': 'ا ر د', 'digits': '2121'},
  ];

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _currentStatusText = 'جاري الاستماع للوحات...';
      } else {
        _currentStatusText = 'تم التقاط لوحة جديدة بنجاح!';
        // محاكاة إضافة لوحة جديدة عند انتهاء التسجيل الصوتي
        int newId = _records.length + 1;
        _records.insert(0, {
          'id': newId.toString(),
          'letters': 'س ر م',
          'digits': '9988',
        });
      }
    });
  }

  void _deleteRecord(int index) {
    setState(() {
      _records.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف اللوحة بنجاح', textDirection: TextDirection.rtl),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _records.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف جميع السجلات', textDirection: TextDirection.rtl),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  void _exportExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تصدير البيانات إلى ملف Excel بنجاح!', textDirection: TextDirection.rtl),
        backgroundColor: Color(0xFF06D6A0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(Icons.exit_to_app, color: Colors.grey),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('باقي ٢٩ يوم', style: TextStyle(color: Colors.grey, fontSize: 10)),
            Text('ينتهي ٣/١/٢٠٢٦', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
        actions: [
          const Center(
            child: Text('SHEEKHA', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF06D6A0))),
          ),
          const SizedBox(width: 10),
          IconButton(icon: const Icon(Icons.widgets_outlined, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // بطاقة التسجيل الصوتي والموجات التفاعلية
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06D6A0).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('قوي', style: TextStyle(color: Color(0xFF06D6A0), fontSize: 12)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_isListening ? 'جاري الاستماع...' : 'يستمع الآن', style: TextStyle(color: _isListening ? Colors.greenAccent : Colors.grey, fontSize: 11)),
                          Text(_currentStatusText, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.redAccent : const Color(0xFF06D6A0),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.black),
                          onPressed: _toggleListening,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // رسم الموجات الصوتية التفاعلية
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(28, (index) {
                      List<double> heights = [
                        10.0, 25.0, 15.0, 30.0, 40.0, 20.0, 35.0, 12.0, 
                        28.0, 45.0, 18.0, 30.0, 22.0, 38.0, 15.0, 25.0, 
                        30.0, 10.0, 20.0, 35.0, 40.0, 25.0, 15.0, 30.0, 
                        18.0, 22.0, 12.0, 28.0
                      ];
                      return Container(
                        width: 3,
                        height: _isListening ? (heights[index % 28] * 1.3) : heights[index % 28],
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.greenAccent : const Color(0xFF06D6A0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // شريط الإجراءات العلوي الفعال
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: _clearAll,
                      child: Row(
                        children: const [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          SizedBox(width: 4),
                          Text('حذف الكل', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _exportExcel,
                      child: Row(
                        children: const [
                          Icon(Icons.download, color: Color(0xFF06D6A0), size: 18),
                          SizedBox(width: 4),
                          Text('تصدير إكسيل', style: TextStyle(color: Color(0xFF06D6A0), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Text('اللوحات المسجلة ...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            // رأس الجدول
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541).withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('#', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text('الحروف', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text('الأرقام', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text('الحالة', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text('حذف', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // قائمة السجلات الديناميكية
            Expanded(
              child: _records.isEmpty
                  ? const Center(
                      child: Text('لا توجد لوحات مسجلة حالياً', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final record = _records[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C2541),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(record['id']!, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              Text(record['letters']!, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                              Text(record['digits']!, style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 16, fontWeight: FontWeight.bold)),
                              const Icon(Icons.check_circle, color: Color(0xFF06D6A0), size: 20),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
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
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          String tabName = ['التشيك', 'التسجيل', 'المرصودة', 'فحص يدوي', 'الإعدادات'][index];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('الانتقال إلى: $tabName', textDirection: TextDirection.rtl),
              duration: const Duration(milliseconds: 500),
            ),
          );
        },
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
}
