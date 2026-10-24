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

class SheekhaHomeScreen extends StatelessWidget {
  const SheekhaHomeScreen({super.key});

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
            // بطاقة التسجيل الصوتي والموجات
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
                        children: const [
                          Text('يستمع الآن', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Text('واو نون سين أربع', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF06D6A0),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.mic, color: Colors.black),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // رسم الموجات الصوتية
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
                        height: heights[index % 28],
                        decoration: BoxDecoration(
                          color: const Color(0xFF06D6A0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // شريط الإجراءات العلوي (حذف الكل والتصدير)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    SizedBox(width: 4),
                    Text('حذف الكل', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    SizedBox(width: 12),
                    Icon(Icons.download, color: Color(0xFF06D6A0), size: 18),
                    SizedBox(width: 4),
                    Text('تصدير إكسيل', style: TextStyle(color: Color(0xFF06D6A0), fontSize: 12)),
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
            // قائمة السجلات المطابقة للصورة
            Expanded(
              child: ListView(
                children: [
                  _buildRecordRow('4', 'و ن س', '7777'),
                  _buildRecordRow('3', 'ب ل د', '7474'),
                  _buildRecordRow('2', 'ا ع ك', '2828'),
                  _buildRecordRow('1', 'ا ر د', '2121'),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0B132B),
        selectedItemColor: const Color(0xFF06D6A0),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
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

  Widget _buildRecordRow(String number, String letters, String digits) {
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
          Text(number, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(letters, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          Text(digits, style: const TextStyle(color: Color(0xFF06D6A0), fontSize: 16, fontWeight: FontWeight.bold)),
          const Icon(Icons.check_circle, color: Color(0xFF06D6A0), size: 20),
          const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
        ],
      ),
    );
  }
}
