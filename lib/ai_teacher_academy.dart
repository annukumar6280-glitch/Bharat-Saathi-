import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiTeacherAcademyPage extends StatefulWidget {
  final bool supabaseAvailable;
  final bool english;
  const AiTeacherAcademyPage({super.key, required this.supabaseAvailable, required this.english});

  @override
  State<AiTeacherAcademyPage> createState() => _AiTeacherAcademyPageState();
}

class _AiTeacherAcademyPageState extends State<AiTeacherAcademyPage> {
  final _question = TextEditingController();
  bool _asking = false;
  String? _answer;
  String? _error;
  String _topic = 'English';
  String _lesson = 'Daily conversation';
  String _provider = '';

  static const _courses = <({String title, String subtitle, IconData icon, Color color, List<String> lessons})>[
    (title: 'English Skills', subtitle: 'बोलना, पढ़ना और लिखना', icon: Icons.translate_rounded, color: Color(0xFFE8EEFF), lessons: ['Daily conversation', 'Grammar basics', 'Writing practice']),
    (title: 'Computer & Digital Skills', subtitle: 'कंप्यूटर और डिजिटल जानकारी', icon: Icons.computer_rounded, color: Color(0xFFE1F5F0), lessons: ['Computer basics', 'Internet safety', 'Digital payments']),
    (title: 'Maths & General Knowledge', subtitle: 'गणित और सामान्य ज्ञान', icon: Icons.calculate_rounded, color: Color(0xFFFFF1D9), lessons: ['Basic mathematics', 'Percentages', 'General knowledge']),
    (title: 'Business Skills', subtitle: 'छोटा कारोबार और हिसाब', icon: Icons.storefront_rounded, color: Color(0xFFF0E8FF), lessons: ['Business basics', 'Customer handling', 'Profit and loss']),
  ];

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _askTeacher() async {
    final question = _question.text.trim();
    if (question.isEmpty) {
      setState(() => _error = 'पहले अपना सवाल लिखें।');
      return;
    }
    if (!widget.supabaseAvailable || Supabase.instance.client.auth.currentUser == null) {
      setState(() => _error = 'AI टीचर से सवाल पूछने के लिए पहले Bharat Saathi में लॉगिन करें।');
      return;
    }
    setState(() { _asking = true; _error = null; _answer = null; _provider = ''; });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'ai-teacher-assistant',
        body: {
          'question': question,
          'course': _topic,
          'lesson': _lesson,
          'language': widget.english ? 'English' : 'Hindi',
        },
      );
      final data = response.data;
      if (data is! Map || data['answer'] is! String) {
        throw Exception('AI टीचर से सही जवाब नहीं मिला।');
      }
      if (!mounted) return;
      setState(() {
        _answer = data['answer'] as String;
        _provider = '${data['provider'] ?? 'AI'} • ${data['model'] ?? ''}';
        _question.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'जवाब नहीं मिल पाया: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _courses.firstWhere((c) => c.title == _topic, orElse: () => _courses.first);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF243A76), Color(0xFF6552B8), Color(0xFF9C6ACB)]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Row(children: [
            CircleAvatar(radius: 28, backgroundColor: Color(0x33FFFFFF), child: Icon(Icons.school_rounded, color: Colors.white, size: 30)),
            SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI Teacher Academy', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('सीखें • अभ्यास करें • सवाल पूछें', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 18),
        Text('अपना कोर्स चुनें', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 10),
        ..._courses.map((course) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: course.color, borderRadius: BorderRadius.circular(14)), child: Icon(course.icon, color: const Color(0xFF394D91))),
            title: Text(course.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(course.subtitle),
            trailing: Icon(_topic == course.title ? Icons.check_circle : Icons.chevron_right, color: _topic == course.title ? Colors.green : null),
            onTap: () => setState(() { _topic = course.title; _lesson = course.lessons.first; _answer = null; _error = null; }),
          ),
        )),
        const SizedBox(height: 10),
        Text('आज का पाठ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _lesson,
          decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.menu_book_outlined)),
          items: selected.lessons.map((lesson) => DropdownMenuItem(value: lesson, child: Text(lesson))).toList(),
          onChanged: (value) => setState(() { if (value != null) { _lesson = value; _answer = null; } }),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF1F3FF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFDDE3FA))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.auto_awesome, color: Color(0xFF6252B8)), SizedBox(width: 8), Text('AI Teacher से पूछें', style: TextStyle(color: Color(0xFF25345B), fontSize: 16, fontWeight: FontWeight.w900))]),
            const SizedBox(height: 10),
            TextField(controller: _question, minLines: 2, maxLines: 4, decoration: const InputDecoration(filled: true, fillColor: Colors.white, hintText: 'अपना सवाल यहाँ लिखें…', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _asking ? null : _askTeacher,
              icon: _asking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
              label: Text(_asking ? 'टीचर जवाब तैयार कर रहे हैं…' : 'सवाल पूछें'),
            )),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
          ]),
        ),
        if (_answer != null) ...[
          const SizedBox(height: 14),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AI Teacher का जवाब', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            SelectableText(_answer!, style: const TextStyle(fontSize: 14, height: 1.55)),
            if (_provider.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_provider, style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 10))),
          ]))),
        ],
        const SizedBox(height: 10),
        const Text('AI टीचर जवाबों को आसान भाषा में समझाने के लिए बनाया गया है। महत्वपूर्ण जानकारी को अपनी किताब या शिक्षक से भी जाँचें।', style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
      ],
    );
  }
}
