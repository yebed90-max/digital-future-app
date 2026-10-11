import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('marketing_ideas_box');
  runApp(const DigitalFutureApp());
}

class DigitalFutureApp extends StatelessWidget {
  const DigitalFutureApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Digital Future AI Marketing',
      locale: const Locale('ar', 'SA'),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F13),
        primaryColor: const Color(0xFF7C3AED),
        cardColor: const Color(0xFF181820),
        fontFamily: 'Cairo',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFFA855F7),
          surface: Color(0xFF181820),
        ),
      ),
      home: const MarketingHomeScreen(),
    );
  }
}

class MarketingHomeScreen extends StatefulWidget {
  const MarketingHomeScreen({Key? key}) : super(key: key);

  @override
  _MarketingHomeScreenState createState() => _MarketingHomeScreenState();
}

class _MarketingHomeScreenState extends State<MarketingHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const GenerateIdeaScreen(),
    const SavedIdeasScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF181820),
          border: Border(top: BorderSide(color: Colors.purple.withOpacity(0.2))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFA855F7),
          unselectedItemColor: Colors.grey,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.psychology_rounded),
              label: 'توليد ذكي',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_rounded),
              label: 'المحفوظات',
            ),
          ],
        ),
      ),
    );
  }
}

// ================= 1. شاشة التوليد الذكي (AI Marketing Generator) =================
class GenerateIdeaScreen extends StatefulWidget {
  const GenerateIdeaScreen({Key? key}) : super(key: key);

  @override
  _GenerateIdeaScreenState createState() => _GenerateIdeaScreenState();
}

class _GenerateIdeaScreenState extends State<GenerateIdeaScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _refineController = TextEditingController();
  
  String _aiResult = "اكتب مجال مشروعك أو منتجك بالأسفل، ودع الذكاء الاصطناعي يبدع لك خطة تسويقية حقيقية! 🚀";
  bool _isLoading = false;
  bool _isRefining = false;
  late Box _box;

  // خيارات التخصيص
  String _selectedMode = 'full_plan';
  String _selectedPlatform = 'all';
  String _selectedTone = 'persuasive';

  // ضع مفتاح Gemini API الخاص بك
  final String apiKey = "YOUR_GEMINI_API_KEY_HERE";

  final List<String> _popularPrompts = [
    'متجر عبايات فاخرة أونلاين',
    'كافيه قهوة مختصة في الرياض',
    'عيادة تجميل وزراعة أسنان',
    'تطبيق توصيل طلبات سريعة',
    'دورة تدريبية في الذكاء الاصطناعي',
  ];

  @override
  void initState() {
    super.initState();
    _box = Hive.box('marketing_ideas_box');
  }

  Future<void> _generateIdeaWithGemini(String topic) async {
    if (topic.trim().isEmpty) return;

    setState(() => _isLoading = true);

    String promptInstruction = "";
    switch (_selectedMode) {
      case 'content_ideas':
        promptInstruction = "أنت خبير سوشيال ميديا. اصنع تقويماً وأفكار محتوى فيروسية و10 خطافات فيديو تيك توك وريلز لمشروع: $topic. المنصة: $_selectedPlatform، نبرة الصوت: $_selectedTone.";
        break;
      case 'ad_copies':
        promptInstruction = "أنت كاتب إعلانات محترف. اكتب 4 نماذج إعلانية احترافية (PAS و AIDA و ستوري قصير) لمجال: $topic. المنصة: $_selectedPlatform، نبرة الصوت: $_selectedTone.";
        break;
      case 'audience_analysis':
        promptInstruction = "حلل الجمهور المستهدف بدقة ونقاط الألم وأكبر مخاوف تمنعهم من الشراء لمجال: $topic. المنصة: $_selectedPlatform.";
        break;
      default:
        promptInstruction = "اعمل لي خطة تسويقية احترافية واستراتيجية نمو متكاملة باللغة العربية لمشروع: $topic. تشمل القيمة التنافسية، تحليل العميل، أفكار المحتوى، الحملة الإعلانية، وجدول التنفيذ. المنصة: $_selectedPlatform، نبرة الصوت: $_selectedTone.";
    }

    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": promptInstruction}]}]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiResponseText = data['candidates'][0]['content']['parts'][0]['text'];

        setState(() {
          _aiResult = aiResponseText;
          _isLoading = false;
        });

        // الحفظ التلقائي في Hive
        _box.add({
          'topic': topic,
          'result': aiResponseText,
          'mode': _selectedMode,
          'platform': _selectedPlatform,
          'tone': _selectedTone,
          'date': DateTime.now().toString().substring(0, 16),
          'isFavorite': false,
        });
      } else {
        setState(() {
          _aiResult = "حدث خطأ في الاتصال بالخادم (كود: ${response.statusCode}). تأكد من صلاحية المفتاح.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _aiResult = "حدث خطأ غير متوقع: $e";
        _isLoading = false;
      });
    }
  }

  // تطوير الخطة وسؤال المستشار
  Future<void> _refinePlan() async {
    final question = _refineController.text.trim();
    if (question.isEmpty || _aiResult.startsWith("اكتب")) return;

    setState(() => _isRefining = true);

    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [{"text": "بناءً على الخطة التسويقية التالية:\n$_aiResult\n\nأجب عن طلب التطوير التالي باللغة العربية باحترافية:\n$question"}]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String addedText = data['candidates'][0]['content']['parts'][0]['text'];
        setState(() {
          _aiResult += "\n\n---\n💡 إجابة المستشار التسويقي:\nسؤالك: $question\n\n$addedText";
          _refineController.clear();
          _isRefining = false;
        });
      }
    } catch (_) {
      setState(() => _isRefining = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الخطة بنجاح! جاهزة للنشر ✨', textAlign: TextAlign.right),
        backgroundColor: Color(0xFF7C3AED),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGenerated = !_isLoading && !(_aiResult.startsWith("اكتب") || _aiResult.startsWith("حدث"));

    return Scaffold(
      appBar: AppBar(
        title: const Text('المستقبل الرقمي - Gemini AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // حقل كتابة الموضوع
            TextField(
              controller: _topicController,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'اكتب منتجك، خدمتك، أو فكرة مشروعك...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF181820),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
              ),
            ),
            const SizedBox(height: 8),

            // اقتراحات سريعة
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _popularPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  return ActionChip(
                    backgroundColor: const Color(0xFF1F1E2A),
                    label: Text(_popularPrompts[i], style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    onPressed: () {
                      _topicController.text = _popularPrompts[i];
                      _generateIdeaWithGemini(_popularPrompts[i]);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // نوع المخرج المطلوب (خطة، محتوى، إعلانات)
            Row(
              children: [
                _buildModeTab('full_plan', 'خطة شاملة'),
                const SizedBox(width: 6),
                _buildModeTab('content_ideas', 'أفكار محتوى'),
                const SizedBox(width: 6),
                _buildModeTab('ad_copies', 'نصوص إعلانات'),
              ],
            ),
            const SizedBox(height: 10),

            // زر التوليد
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _generateIdeaWithGemini(_topicController.text),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('ابتكر خطة تسويقية 💡', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // مساحة عرض النتيجة
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181820),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _aiResult,
                          style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.white70),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                    if (isGenerated) ...[
                      const Divider(color: Colors.white10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                            tooltip: 'تصدير PDF',
                            onPressed: () => exportSinglePlanPDF(_topicController.text, _aiResult),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Color(0xFFA855F7)),
                            tooltip: 'نسخ النص',
                            onPressed: () => _copyToClipboard(_aiResult),
                          ),
                        ],
                      ),
                      // شريط متابعة وتطوير الخطة
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _refineController,
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: 'اسأل المستشار: سكريبت فيديو، عروض...',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                                isDense: true,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: _isRefining
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.send_rounded, color: Color(0xFFA855F7), size: 20),
                            onPressed: _isRefining ? null : _refinePlan,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String modeKey, String label) {
    final isSelected = _selectedMode == modeKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = modeKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7C3AED).withOpacity(0.3) : const Color(0xFF14141C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.grey),
          ),
        ),
      ),
    );
  }
}

// ================= 2. شاشة المحفوظات مع شريط البحث وتصدير PDF =================
class SavedIdeasScreen extends StatefulWidget {
  const SavedIdeasScreen({Key? key}) : super(key: key);

  @override
  _SavedIdeasScreenState createState() => _SavedIdeasScreenState();
}

class _SavedIdeasScreenState extends State<SavedIdeasScreen> {
  late Box _box;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _box = Hive.box('marketing_ideas_box');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحفوظات والخطط', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: _box.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد أفكار محفوظة حتى الآن.\nابدأ بتوليد أول خطة تسويقية!',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }

          // تصفية العناصر بناءً على شريط البحث
          final items = [];
          for (int i = 0; i < box.length; i++) {
            final item = box.getAt(i);
            final topic = (item['topic'] ?? '').toString().toLowerCase();
            final result = (item['result'] ?? '').toString().toLowerCase();
            if (_searchQuery.isEmpty || topic.contains(_searchQuery) || result.contains(_searchQuery)) {
              items.add({'index': i, 'data': item});
            }
          }

          return Column(
            children: [
              // 🔍 شريط البحث الذكي
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المشروع أو الكلمات المفتاحية...',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFA855F7), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF181820),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),

              // قائمة الخطط
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('لا توجد نتائج مطابقة للبحث.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: items.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, idx) {
                          final originalIndex = items[idx]['index'];
                          final item = items[idx]['data'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF181820),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                      onPressed: () => box.deleteAt(originalIndex),
                                    ),
                                    Text(
                                      item['topic'] ?? '',
                                      style: const TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['result'] ?? '',
                                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        // زر تصدير PDF
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 18),
                                          onPressed: () => exportSinglePlanPDF(item['topic'], item['result']),
                                        ),
                                        // زر نسخ
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, color: Colors.grey, size: 18),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: item['result']));
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ!')));
                                          },
                                        ),
                                      ],
                                    ),
                                    Text(item['date'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ================= 3. دالة تصدير وطباعة الخطة كـ PDF =================
Future<void> exportSinglePlanPDF(String topic, String content) async {
  final pdf = pw.Document();

  final font = await PdfGoogleFonts.cairoRegular();
  final boldFont = await PdfGoogleFonts.cairoBold();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      build: (pw.Context context) => [
        pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('المستقبل الرقمي - Digital Future AI', style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.deepPurple)),
              pw.Text('خطة تسويقية احترافية', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.purple50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Text('المشروع: $topic', style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColors.deepPurple900)),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          content,
          style: pw.TextStyle(font: font, fontSize: 11, lineSpacing: 4),
          textAlign: pw.TextAlign.right,
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: 'Marketing_Plan_${topic.replaceAll(' ', '_')}.pdf',
  );
}
