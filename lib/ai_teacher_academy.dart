import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AiTeacherAcademyPage extends StatefulWidget {
  final bool supabaseAvailable;
  final bool english;
  const AiTeacherAcademyPage({super.key, required this.supabaseAvailable, required this.english});

  @override
  State<AiTeacherAcademyPage> createState() => _AiTeacherAcademyPageState();
}

class _AiTeacherAcademyPageState extends State<AiTeacherAcademyPage> {
  final _question = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final Stopwatch _voiceStopwatch = Stopwatch();
  bool _speechInitialized = false, _listening = false, _speaking = false;
  int _voiceUsedSeconds = 0;
  String? _voiceMessage;
  final Set<String> _completedQuizzes = {};
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
  void initState() {
    super.initState();
    _loadVoiceUsage();
    _loadProgress();
    _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() { if (mounted) setState(() => _speaking = false); });
    _tts.setErrorHandler((_) { if (mounted) setState(() => _speaking = false); });
  }

  String get _voiceUsageKey {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    final day = DateTime.now().toIso8601String().substring(0, 10);
    return 'bs_ai_teacher_voice_${userId}_${day}';
  }

  int get _voiceRemaining => (300 - _voiceUsedSeconds).clamp(0, 300);

  String get _progressKey {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    return 'bs_ai_teacher_quiz_progress_${userId}';
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_progressKey) ?? <String>[];
    if (mounted) setState(() { _completedQuizzes
      ..clear()
      ..addAll(saved); });
  }

  String _lessonSummary() {
    if (_topic == 'English Skills') {
      if (_lesson == 'Daily conversation') return 'अभ्यास: अभिवादन, अपना परिचय और छोटे सवाल। उदाहरण: “Hello, how are you?” — “I am fine, thank you.” रोज़ 5 वाक्य बोलकर अभ्यास करें।';
      if (_lesson == 'Grammar basics') return 'I के साथ am, he/she/it के साथ is और you/we/they के साथ are आता है। उदाहरण: “I am ready.”, “She is happy.”, “They are here.”';
      return 'छोटे और साफ वाक्य लिखें। वाक्य का पहला अक्षर बड़ा रखें और अंत में full stop या question mark लगाएँ। लिखने के बाद spelling जाँचें।';
    }
    if (_topic == 'Computer & Digital Skills') {
      if (_lesson == 'Computer basics') return 'Keyboard से लिखते हैं, mouse से चुनते हैं, monitor पर परिणाम देखते हैं और printer कागज़ पर छापता है। फाइल को सही नाम और folder में सेव करें।';
      if (_lesson == 'Internet safety') return 'OTP, UPI PIN और password किसी को न बताएँ। अनजान लिंक न खोलें। बैंक या सरकारी सहायता के नाम पर स्क्रीन शेयर न करें।';
      return 'UPI भुगतान से पहले स्क्रीन पर प्राप्तकर्ता का नाम जाँचें। पैसा पाने के लिए UPI PIN नहीं डालना पड़ता। PIN डालने का अर्थ आम तौर पर पैसा भेजने की अनुमति देना है।';
    }
    if (_topic == 'Maths & General Knowledge') {
      if (_lesson == 'Percentages') return 'प्रतिशत का अर्थ प्रति 100 है। 200 का 25% = 200 × 25 ÷ 100 = 50। छूट और GST में प्रतिशत का उपयोग होता है।';
      if (_lesson == 'General knowledge') return 'सामान्य ज्ञान पढ़ते समय तारीख और स्रोत देखें। बदलने वाली जानकारी—जैसे पदाधिकारी, योजनाएँ और नियम—को आधिकारिक स्रोत से जाँचें।';
      return 'गणित में सवाल को छोटे चरणों में बाँटें। जोड़, घटाव, गुणा और भाग के बाद उत्तर का अनुमान लगाकर जाँच करें।';
    }
    if (_lesson == 'Customer handling') return 'ग्राहक की बात ध्यान से सुनें, जरूरत दोहराकर पुष्टि करें, कीमत और समय साफ बताएँ और शिकायत का सम्मानपूर्वक समाधान करें।';
    if (_lesson == 'Profit and loss') return 'मुनाफा = बिक्री मूल्य − कुल लागत। यदि बिक्री मूल्य लागत से कम है तो नुकसान होता है। किराया, पैकिंग और डिलीवरी जैसी लागत भी जोड़ें।';
    return 'व्यवसाय में बिक्री, लागत, बचत और ग्राहक संतुष्टि का रिकॉर्ड रखें। रोज़ का हिसाब लिखने से सही निर्णय लेने में मदद मिलती है।';
  }

  List<Map<String, dynamic>> _questionsForTopic() {
    if (_topic == 'English Skills') return [
      {'q':'सुबह मिलने पर सही अभिवादन क्या है?','o':['Good morning','Good night','Goodbye'],'a':0},
      {'q':'“I ___ a student.” में क्या आएगा?','o':['am','is','are'],'a':0},
      {'q':'“Thank you” का सामान्य जवाब क्या है?','o':['You are welcome','Good night','Excuse me'],'a':0},
    ];
    if (_topic == 'Computer & Digital Skills') return [
      {'q':'टाइप करने के लिए किसका उपयोग होता है?','o':['Keyboard','Monitor','Printer'],'a':0},
      {'q':'OTP किसके साथ साझा करना चाहिए?','o':['किसी के साथ नहीं','अनजान कॉलर से','सोशल मीडिया पर'],'a':0},
      {'q':'UPI PIN कब डालना चाहिए?','o':['जब आप भुगतान भेज रहे हों और विवरण जाँच लिया हो','पैसा प्राप्त करने के लिए','किसी को बताने के लिए'],'a':0},
    ];
    if (_topic == 'Maths & General Knowledge') return [
      {'q':'200 का 25% कितना है?','o':['50','25','100'],'a':0},
      {'q':'12 × 8 कितना है?','o':['96','88','108'],'a':0},
      {'q':'आधा किस दशमलव के बराबर है?','o':['0.5','0.2','1.5'],'a':0},
    ];
    return [
      {'q':'मुनाफा कैसे निकालते हैं?','o':['बिक्री मूल्य − लागत','लागत + बिक्री','केवल बिक्री'],'a':0},
      {'q':'ग्राहक की शिकायत पर क्या करना चाहिए?','o':['ध्यान से सुनकर समाधान देना','बात काटना','अनदेखा करना'],'a':0},
      {'q':'व्यवसाय में किसका रिकॉर्ड रखना चाहिए?','o':['बिक्री और लागत','केवल नाम','कुछ नहीं'],'a':0},
    ];
  }

  Future<void> _runQuiz() async {
    final questions = _questionsForTopic();
    var index = 0, selected = -1, score = 0;
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        final question = questions[index];
        final options = question['o'] as List<String>;
        return AlertDialog(
          title: Text('$_topic • अभ्यास टेस्ट'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('प्रश्न ${index + 1} / ${questions.length}', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
            const SizedBox(height: 8),
            Text(question['q'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...List.generate(options.length, (i) => RadioListTile<int>(
              dense: true, contentPadding: EdgeInsets.zero, value: i, groupValue: selected,
              title: Text(options[i]), onChanged: (v) => setDialogState(() => selected = v ?? -1),
            )),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('बंद करें')),
            FilledButton(
              onPressed: selected < 0 ? null : () {
                if (selected == question['a']) score++;
                if (index == questions.length - 1) {
                  Navigator.pop(context, score);
                } else {
                  setDialogState(() { index++; selected = -1; });
                }
              },
              child: Text(index == questions.length - 1 ? 'परिणाम देखें' : 'अगला'),
            ),
          ],
        );
      }),
    );
    if (result == null) return;
    _completedQuizzes.add(_topic);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_progressKey, _completedQuizzes.toList());
    if (mounted) {
      setState(() {});
      showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: const Text('टेस्ट पूरा हुआ'),
        content: Text('आपका स्कोर: $result / ${questions.length}. ${result == questions.length ? 'बहुत अच्छा! आपने सभी उत्तर सही दिए।' : 'पाठ दोबारा पढ़ें और फिर अभ्यास करें।'}'),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('ठीक है'))],
      ));
    }
  }

  Future<void> _loadVoiceUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_voiceUsageKey) ?? 0;
    if (mounted) setState(() => _voiceUsedSeconds = used.clamp(0, 300));
  }

  Future<void> _finishVoiceSession() async {
    if (!_voiceStopwatch.isRunning) return;
    _voiceStopwatch.stop();
    final elapsed = _voiceStopwatch.elapsed.inSeconds;
    _voiceStopwatch.reset();
    final updated = (_voiceUsedSeconds + elapsed).clamp(0, 300);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_voiceUsageKey, updated);
    if (mounted) setState(() { _voiceUsedSeconds = updated; _listening = false; });
  }

  Future<void> _startVoiceInput() async {
    if (_listening) { await _speech.stop(); await _finishVoiceSession(); return; }
    final remaining = _voiceRemaining;
    if (remaining <= 0) {
      setState(() => _voiceMessage = 'आज की 5 मिनट की वॉइस सीमा पूरी हो गई है।');
      return;
    }
    final microphone = await Permission.microphone.request();
    if (!microphone.isGranted) {
      setState(() => _voiceMessage = 'बोलकर सवाल पूछने के लिए माइक्रोफोन की अनुमति दें।');
      return;
    }
    if (!_speechInitialized) {
      _speechInitialized = await _speech.initialize(
        onStatus: (status) { if (status == 'notListening') _finishVoiceSession(); },
        onError: (_) { _finishVoiceSession(); if (mounted) setState(() => _voiceMessage = 'आवाज़ पहचान नहीं हो पाई। दोबारा कोशिश करें।'); },
      );
    }
    if (!_speechInitialized) {
      setState(() => _voiceMessage = 'इस फोन में Speech Recognition उपलब्ध नहीं है।');
      return;
    }
    setState(() { _voiceMessage = null; _listening = true; });
    _voiceStopwatch.start();
    try {
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty && mounted) {
            setState(() => _question.text = result.recognizedWords);
          }
          if (result.finalResult) { _speech.stop(); _finishVoiceSession(); }
        },
        localeId: widget.english ? 'en-IN' : 'hi-IN',
        listenFor: Duration(seconds: remaining),
        pauseFor: const Duration(seconds: 5),
      );
    } catch (_) {
      await _finishVoiceSession();
      if (mounted) setState(() => _voiceMessage = 'माइक्रोफोन शुरू नहीं हो पाया।');
    }
  }

  Future<void> _speakAnswer() async {
    final answer = _answer;
    if (answer == null || answer.isEmpty) return;
    try {
      if (_voiceRemaining <= 0) {
        if (mounted) setState(() => _voiceMessage = 'आज की 5 मिनट की वॉइस सीमा पूरी हो गई है।');
        return;
      }
      await _tts.setLanguage(widget.english ? 'en-IN' : 'hi-IN');
      await _tts.setSpeechRate(0.45);
      if (mounted) setState(() => _speaking = true);
      _voiceStopwatch.start();
      await _tts.speak(answer);
      await _finishVoiceSession();
    } catch (_) {
      if (mounted) setState(() { _speaking = false; _voiceMessage = 'इस फोन में चुनी गई भाषा की आवाज़ उपलब्ध नहीं है।'; });
    }
  }

  Future<void> _stopSpeech() async {
    await _tts.stop();
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
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
        const SizedBox(height: 10),
        Card(child: ExpansionTile(
          leading: const Icon(Icons.menu_book_rounded),
          title: const Text('पाठ सामग्री', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('चुने हुए पाठ का छोटा अभ्यास'),
          children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text(_lessonSummary(), style: const TextStyle(height: 1.5)))],
        )),
        Card(child: ListTile(
          leading: const Icon(Icons.quiz_outlined),
          title: const Text('अभ्यास टेस्ट', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('प्रगति: ${_completedQuizzes.length} / ${_courses.length} कोर्स के टेस्ट पूरे'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: _runQuiz,
        )),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF1F3FF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFDDE3FA))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.auto_awesome, color: Color(0xFF6252B8)), SizedBox(width: 8), Text('AI Teacher से पूछें', style: TextStyle(color: Color(0xFF25345B), fontSize: 16, fontWeight: FontWeight.w900))]),
            const SizedBox(height: 10),
            TextField(controller: _question, minLines: 2, maxLines: 4, decoration: const InputDecoration(filled: true, fillColor: Colors.white, hintText: 'अपना सवाल यहाँ लिखें…', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: _asking ? null : _askTeacher,
                icon: _asking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                label: Text(_asking ? 'जवाब तैयार हो रहा है…' : 'सवाल पूछें'),
              )),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: _listening ? 'सुनना बंद करें' : 'बोलकर सवाल पूछें',
                onPressed: _asking ? null : _startVoiceInput,
                icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded),
              ),
            ]),
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('आज की वॉइस सीमा: ${(_voiceRemaining ~/ 60)} मिनट ${(_voiceRemaining % 60)} सेकंड बाकी', style: const TextStyle(color: Colors.blueGrey, fontSize: 11))),
            if (_voiceMessage != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_voiceMessage!, style: const TextStyle(color: Colors.deepOrange, fontSize: 11))),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
          ]),
        ),
        if (_answer != null) ...[
          const SizedBox(height: 14),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AI Teacher का जवाब', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            SelectableText(_answer!, style: const TextStyle(fontSize: 14, height: 1.55)),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: _speaking ? _stopSpeech : _speakAnswer,
              icon: Icon(_speaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded),
              label: Text(_speaking ? 'आवाज़ रोकें' : 'जवाब सुनें'),
            )),
            if (_provider.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_provider, style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 10))),
          ]))),
        ],
        const SizedBox(height: 10),
        const Text('AI टीचर जवाबों को आसान भाषा में समझाने के लिए बनाया गया है। महत्वपूर्ण जानकारी को अपनी किताब या शिक्षक से भी जाँचें।', style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
      ],
    );
  }
}
