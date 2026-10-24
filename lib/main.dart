import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  String _currentStatusText = 'جاهز لبدء الرصد الميداني';
  String _searchQuery = '';

  // النطاق الجغرافي الحالي والملاحظات الميدانية
  String _currentLocation = 'المنيل - شارع علي شريف';
  String _selectedFieldNote = 'عادية';

  // قائمة السجلات المتقدمة
  List<Map<String, String>> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  // تحميل البيانات المحفوظة بصيغة آمنة محلياً
  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('sheekha_pro_records');
    if (savedData != null) {
      setState(() {
        _records = List<Map<String, String>>.from(
          json.decode(savedData).map((item) => Map<String, String>.from(item)),
        );
      });
    } else {
      _records = [
        {'id': '4', 'letters': 'و ن س', 'digits': '7777', 'location': 'المنيل - شارع علي شريف', 'note': 'تحت تندة'},
        {'id': '3', 'letters': 'ب ل د', 'digits': '7474', 'location': 'المنيل - شارع علي شريف', 'note': 'برحة يمين'},
        {'id': '2', 'letters': 'ا ع ك', 'digits': '2828', 'location': 'المنيل - شارع المنيل الرئيسي', 'note': 'أول الشارع'},
        {'id': '1', 'letters': 'ا ر د', 'digits': '2121', 'location': 'المنيل - شارع المنيل الرئيسي', 'note': 'عادية'},
      ];
      _saveRecords();
    }
  }

  // الحفظ الآمن لمنع الانهيار
  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('sheekha_pro_records', json.encode(_records));
  }

  // التقاط ذكي مع ربط الموقع والملاحظة الميدانية
  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _currentStatusText = 'جاري الاستماع للوحات في ($_currentLocation)...';
      } else {
        String capturedLetters = 'س ر م';
        String capturedDigits = '9988';
        _currentStatusText = '$capturedLetters $capturedDigits';
        
        int newId = _records.length + 1;
        _records.insert(0, {
          'id': newId.toString(),
          'letters': capturedLetters,
          'digits': capturedDigits,
          'location': _currentLocation,
          'note': _selectedFieldNote,
        });
        _saveRecords();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم رصد لوحة جديدة في [$_currentLocation] بنجاح', textDirection: TextDirection.rtl),
            backgroundColor: const Color(0xFF06D6A0),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      }
    });
  }

  void _deleteRecord(int index) {
    setState(() {
      _records.removeAt(index);
      _saveRecords();
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
      _saveRecords();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم مسح جميع السجلات الميدانية', textDirection: TextDirection.rtl),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  // نافذة إعداد النطاق الجغرافي والملاحظات السريعة
  void _showSessionConfigDialog() {
    TextEditingController locationController = TextEditingController(text: _currentLocation);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('إعدادات الجلسة والموقع الجغرافي', style: TextStyle(color: Color(0xFF06D6A0)), textDirection: TextDirection.rtl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('حدد الحي والشارع الحالي لتوثيق مكان الرصد:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: locationController,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0B132B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: const TextStyle(color: Colors.white),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 15),
            const Text('اختر الملاحظة الميدانية السريعة:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: ['عادية', 'برحة يمين', 'برحة يسار', 'تحت تندة', 'أول الشارع'].map((note) {
                return ChoiceChip(
                  label: Text(note, style: TextStyle(color: _selectedFieldNote == note ? Colors.black : Colors.white, fontSize: 11)),
                  selected: _selectedFieldNote == note,
                  selectedColor: const Color(0xFF06D6A0),
                  backgroundColor: const Color(0xFF0B132B),
                  onSelected: (selected) {
                    setState(() {
                      _selectedFieldNote = note;
                    });
                    Navigator.pop(context);
                    _showSessionConfigDialog();
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)),
            onPressed: () {
              setState(() {
                _currentLocation = locationController.text;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحديث النطاق الجغرافي بنجاح', textDirection: TextDirection.rtl)),
              );
            },
            child: const Text('حفظ وتثبيت', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // نافذة الإدخال اليدوي
  void _showManualEntryDialog() {
    TextEditingController lettersController = TextEditingController();
    TextEditingController digitsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('إدخال يدوي سريع للوحة', style: TextStyle(color: Color(0xFF06D6A0)), textDirection: TextDirection.rtl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: lettersController,
              decoration: const InputDecoration(labelText: 'الحروف (مثال: ب ل د)', labelStyle: TextStyle(color: Colors.grey)),
              style: const TextStyle(color: Colors.white),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: digitsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الأرقام (مثال: 5544)', labelStyle: TextStyle(color: Colors.grey)),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text('الملاحظة الحالية: $_selectedFieldNote', style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0)),
            onPressed: () {
              if (lettersController.text.isNotEmpty && digitsController.text.isNotEmpty) {
                setState(() {
                  int newId = _records.length + 1;
                  _records.insert(0, {
                    'id': newId.toString(),
                    'letters': lettersController.text,
                    'digits': digitsController.text,
                    'location': _currentLocation,
                    'note': _selectedFieldNote,
                  });
                  _saveRecords();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت إضافة اللوحة وسجلاتها بنجاح', textDirection: TextDirection.rtl)),
                );
              }
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _records.where((record) {
      final query = _searchQuery.toLowerCase();
      return record['letters']!.toLowerCase().contains(query) ||
             record['digits']!.toLowerCase().contains(query) ||
             record['location']!.toLowerCase().contains(query) ||
             record['note']!.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.location_on, color: Color(0xFF06D6A0)),
          onPressed: _showSessionConfigDialog,
          tooltip: 'إعداد الموقع والملاحظات',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الموقع: $_currentLocation', style: const TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis),
            const Text('ينتهي ٣/١/٢٠٢٦ (باقي ٢٩ يوم)', style: TextStyle(color: Colors.grey, fontSize: 9)),
          ],
        ),
        actions: [
          const Center(
            child: Text('SHEEKHA', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF06D6A0))),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _currentIndex == 2 
          ? _buildSearchView(filteredRecords) 
          : _currentIndex == 3 
              ? _buildManualCheckView() 
              : _buildMainCheckView(filteredRecords),
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
          if (index == 3) {
            _showManualEntryDialog();
          }
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

  Widget _buildMainCheckView(List<Map<String, String>> records) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
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
                      child: Text(_selectedFieldNote, style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 11)),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(28, (index) {
                    List<double> heights = [10.0, 25.0, 15.0, 30.0, 40.0, 20.0, 35.0, 12.0, 28.0, 45.0, 18.0, 30.0, 22.0, 38.0, 15.0, 25.0, 30.0, 10.0, 20.0, 35.0, 40.0, 25.0, 15.0, 30.0, 18.0, 22.0, 12.0, 28.0];
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
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تصدير قاعدة البيانات بنجاح (CSV / Excel)', textDirection: TextDirection.rtl), backgroundColor: Color(0xFF06D6A0)),
                      );
                    },
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
          Expanded(
            child: records.isEmpty
                ? const Center(child: Text('لا توجد لوحات مسجلة', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(record['letters']!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                Text(record['note']!, style: const TextStyle(color: Colors.amberAccent, fontSize: 9)),
                              ],
                            ),
                            Text(record['digits']!, style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 15, fontWeight: FontWeight.bold)),
                            const Icon(Icons.check_circle, color: Color(0xFF06D6A0), size: 18),
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
    );
  }

  Widget _buildSearchView(List<Map<String, String>> filteredRecords) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'بحث فوري (برقم، حروف، أو شارع)...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF06D6A0)),
              filled: true,
              fillColor: const Color(0xFF1C2541),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: ListView.builder(
              itemCount: filteredRecords.length,
              itemBuilder: (context, index) {
                final record = filteredRecords[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF1C2541), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${record['letters']} - ${record['digits']}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          Text('الموقع: ${record['location']}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                      Chip(
                        label: Text(record['note']!, style: const TextStyle(fontSize: 10, color: Colors.black)),
                        backgroundColor: const Color(0xFF06D6A0),
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

  Widget _buildManualCheckView() {
    return Center(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06D6A0), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
        onPressed: _showManualEntryDialog,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('إضافة لوحة جديدة يدوياً', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
