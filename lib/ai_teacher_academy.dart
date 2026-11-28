import 'dart:async';
import 'dart:math' as math;

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

class _AiTeacherAcademyPageState extends State<AiTeacherAcademyPage> with WidgetsBindingObserver {
  final _question = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final Stopwatch _voiceStopwatch = Stopwatch();
  Timer? _voiceTimer;
  bool _speechInitialized = false, _listening = false, _speaking = false;
  int _voiceUsedSeconds = 0;
  String? _voiceMessage;
  final Set<String> _completedQuizzes = {};
  bool _asking = false;
  String? _answer;
  String? _error;
  String _topic = 'English Skills';
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
    WidgetsBinding.instance.addObserver(this);
    _loadVoiceUsage();
    _loadProgress();
    _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() { if (mounted) setState(() => _speaking = false); });
    _tts.setErrorHandler((_) { if (mounted) setState(() => _speaking = false); });
  }

  String get _accountId {
    try { return Supabase.instance.client.auth.currentUser?.id ?? 'guest'; }
    catch (_) { return 'guest'; }
  }

  String get _voiceUsageKey {
    final userId = _accountId;
    final day = DateTime.now().toIso8601String().substring(0, 10);
    return 'bs_ai_teacher_voice_' + userId + '_' + day;
  }

  int get _voiceRemaining => (300 - _voiceUsedSeconds).clamp(0, 300);

  String get _progressKey {
    final userId = _accountId;
    return 'bs_ai_teacher_quiz_progress_' + userId;
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_progressKey) ?? <String>[];
    if (mounted) {
      setState(() {
        _completedQuizzes..clear()..addAll(saved);
      });
    }
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


  String get _quizSeenKey => 'bs_ai_teacher_seen_questions_${_accountId}_$_topic';

  Map<String, dynamic> _quizQuestion(String id, String question, String answer, List<String> distractors) {
    final options = <String>[];
    for (final candidate in [answer, ...distractors]) {
      if (options.length == 4) break;
      if (candidate.trim().isNotEmpty && !options.contains(candidate)) {
        options.add(candidate);
      }
    }
    var fillerIndex = 1;
    while (options.length < 4) {
      final filler = 'विकल्प $fillerIndex';
      if (!options.contains(filler)) options.add(filler);
      fillerIndex++;
    }
    return <String, dynamic>{'id': id, 'q': question, 'o': options, 'a': options.indexOf(answer)};
  }

  List<Map<String, dynamic>> _questionsForTopic() {
    final bank = <Map<String, dynamic>>[];
    if (_topic == 'Maths & General Knowledge') {
      // Large generated arithmetic bank: each operand pair has a stable unique ID.
      for (var a = 10; a <= 59; a++) {
        for (var b = 1; b <= 40; b++) {
          final sum = a + b;
          bank.add(_quizQuestion('addpractice_${a}_$b', '$a + $b कितना होगा?', '$sum',
              ['${sum + 1}', '${sum - 1}', '${a * b}']));
          if (a >= b) {
            final difference = a - b;
            bank.add(_quizQuestion('subpractice_${a}_$b', '$a − $b कितना होगा?', '$difference',
                ['${difference + 1}', '${difference + 2}', '${a + b}']));
          }
        }
      }
      for (var a = 2; a <= 30; a++) {
        for (var b = 2; b <= 12; b++) {
          bank.add(_quizQuestion('mul_${a}_$b', '$a × $b कितना होगा?', '${a * b}',
              ['${a * b + b}', '${a * b - a}', '${a + b}']));
          if (a >= b) {
            bank.add(_quizQuestion('sub_${a}_$b', '$a − $b कितना होगा?', '${a - b}',
                ['${a + b}', '${a - b + 2}', '${a * b}']));
          }
        }
      }
      for (var base = 50; base <= 1000; base += 25) {
        for (final percent in <int>[5, 10, 15, 20, 25, 30, 40, 50, 75]) {
          if ((base * percent) % 100 == 0) {
            final answer = base * percent ~/ 100;
            bank.add(_quizQuestion('pct_${base}_$percent', '$base का $percent% कितना है?', '$answer',
                ['$base', '${answer + 5}', '${answer * 2}']));
          }
        }
      }
      final facts = <List<String>>[
        ['भारत की राजधानी क्या है?', 'नई दिल्ली', 'मुंबई', 'जयपुर', 'लखनऊ'],
        ['भारत का राष्ट्रीय पशु कौन है?', 'बाघ', 'हाथी', 'शेर', 'हिरण'],
        ['भारत का राष्ट्रीय पक्षी कौन है?', 'मोर', 'तोता', 'कबूतर', 'हंस'],
        ['सौरमंडल का सबसे बड़ा ग्रह कौन है?', 'बृहस्पति', 'पृथ्वी', 'मंगल', 'शुक्र'],
        ['पानी का रासायनिक सूत्र क्या है?', 'H₂O', 'CO₂', 'O₂', 'NaCl'],
        ['एक सप्ताह में कितने दिन होते हैं?', '7', '5', '6', '8'],
        ['एक वर्ष में सामान्यतः कितने महीने होते हैं?', '12', '10', '11', '13'],
      ];
      for (var i = 0; i < facts.length; i++) {
        bank.add(_quizQuestion('gk_$i', facts[i][0], facts[i][1], facts[i].sublist(2)));
      }
    } else if (_topic == 'English Skills') {
      final facts = <List<String>>[
        ['I ___ happy.', 'am', 'is', 'are', 'be'],
        ['She ___ to school every day.', 'goes', 'go', 'going', 'gone'],
        ['They ___ playing cricket.', 'are', 'is', 'am', 'be'],
        ['He ___ a book yesterday.', 'read', 'reads', 'reading', 'will read'],
        ['We ___ friends.', 'are', 'is', 'am', 'be'],
        ['Choose the plural of “child”.', 'children', 'childs', 'childes', 'childrens'],
        ['Choose the opposite of “hot”.', 'cold', 'warm', 'boiling', 'heat'],
        ['What is the past tense of “go”?', 'went', 'goed', 'goes', 'going'],
        ['Which word is a noun?', 'teacher', 'quickly', 'beautiful', 'run'],
        ['Which sentence is a question?', 'Where are you?', 'I am fine.', 'She is here.', 'They play.'],
        ['“धन्यवाद” का English क्या है?', 'Thank you', 'Sorry', 'Welcome', 'Goodbye'],
        ['“कृपया” का English क्या है?', 'Please', 'Thanks', 'Never', 'Later'],
        ['सुबह मिलने पर क्या कहते हैं?', 'Good morning', 'Good night', 'Good evening', 'Goodbye'],
        ['“How are you?” का सही जवाब कौन सा है?', 'I am fine.', 'My name is.', 'Good night.', 'See you yesterday.'],
        ['“मेरा नाम रवि है” का English क्या है?', 'My name is Ravi.', 'I name Ravi.', 'Me Ravi name.', 'My Ravi am.'],
      ];
      for (var i = 0; i < facts.length; i++) {
        bank.add(_quizQuestion('eng_$i', facts[i][0], facts[i][1], facts[i].sublist(2)));
      }
      _addEnglishGeneratedQuestions(bank);
    } else if (_topic == 'Computer & Digital Skills') {
      final facts = <List<String>>[
        ['कंप्यूटर में टाइप करने के लिए क्या उपयोग होता है?', 'Keyboard', 'Monitor', 'Printer', 'Speaker'],
        ['स्क्रीन पर जानकारी किससे दिखाई देती है?', 'Monitor', 'Mouse', 'Keyboard', 'Scanner'],
        ['कागज़ पर प्रिंट निकालने वाला उपकरण कौन सा है?', 'Printer', 'Router', 'Webcam', 'Speaker'],
        ['OTP का पूरा अर्थ क्या है?', 'One Time Password', 'Open Transfer Pin', 'Online Text Pass', 'Only Two Passwords'],
        ['OTP किसे बताना चाहिए?', 'किसी को नहीं', 'बैंक कर्मचारी को', 'अनजान कॉलर को', 'सोशल मीडिया पर'],
        ['पैसा प्राप्त करने के लिए UPI PIN डालना जरूरी है?', 'नहीं', 'हाँ, हमेशा', 'केवल रात में', 'केवल दुकानदार के लिए'],
        ['मजबूत पासवर्ड कैसा होना चाहिए?', 'लंबा और अलग-अलग अक्षरों वाला', 'अपना नाम', '123456', 'मोबाइल नंबर'],
        ['अनजान लिंक मिलने पर क्या करें?', 'जाँच किए बिना न खोलें', 'तुरंत खोलें', 'सबको भेजें', 'पासवर्ड डालें'],
        ['फाइल सेव करने का क्या लाभ है?', 'बाद में फिर खोल सकते हैं', 'इंटरनेट बंद हो जाता है', 'स्क्रीन बड़ी होती है', 'बैटरी चार्ज होती है'],
        ['ईमेल में विषय (Subject) का काम क्या है?', 'संदेश का विषय बताना', 'पासवर्ड दिखाना', 'फोटो एडिट करना', 'कॉल करना'],
        ['Wi-Fi किस काम आता है?', 'वायरलेस नेटवर्क से जुड़ने में', 'कागज़ छापने में', 'फोन चार्ज करने में', 'स्क्रीन साफ करने में'],
        ['UPI भुगतान से पहले क्या जाँचना चाहिए?', 'प्राप्तकर्ता का नाम और राशि', 'केवल फोन का रंग', 'मौसम', 'बैटरी का ब्रांड'],
      ];
      for (var i = 0; i < facts.length; i++) {
        bank.add(_quizQuestion('digital_$i', facts[i][0], facts[i][1], facts[i].sublist(2)));
      }
      _addDigitalGeneratedQuestions(bank);
    } else {
      final facts = <List<String>>[
        ['मुनाफा कैसे निकालते हैं?', 'बिक्री मूल्य − कुल लागत', 'लागत + बिक्री', 'केवल बिक्री', 'बिक्री ÷ लागत'],
        ['नुकसान कब होता है?', 'जब बिक्री मूल्य लागत से कम हो', 'जब बिक्री लागत से अधिक हो', 'जब कोई ग्राहक आए', 'जब दुकान खुले'],
        ['दुकान का रोज़ का हिसाब क्यों रखना चाहिए?', 'आय और खर्च समझने के लिए', 'रंग चुनने के लिए', 'फोन तेज करने के लिए', 'समय बदलने के लिए'],
        ['ग्राहक की शिकायत पर पहला कदम क्या है?', 'ध्यान से सुनना', 'बात काटना', 'अनदेखा करना', 'बहस करना'],
        ['स्टॉक रिकॉर्ड किसलिए होता है?', 'सामान की उपलब्ध मात्रा जानने के लिए', 'मौसम देखने के लिए', 'कर्मचारी की उम्र जानने के लिए', 'मोबाइल चलाने के लिए'],
        ['बिक्री मूल्य का अर्थ क्या है?', 'जिस कीमत पर सामान बेचा जाए', 'सामान खरीदने की कीमत', 'दुकान का किराया', 'बिजली का बिल'],
        ['कुल लागत में क्या शामिल हो सकता है?', 'खरीद, किराया और पैकिंग', 'केवल मुनाफा', 'केवल ग्राहक का नाम', 'केवल तारीख'],
        ['ग्राहक को कीमत कैसे बतानी चाहिए?', 'स्पष्ट और सही तरीके से', 'छिपाकर', 'हर बार बदलकर', 'बिना पूछे'],
        ['बजट बनाने का लाभ क्या है?', 'खर्च पर नियंत्रण', 'खर्च बढ़ाना', 'रिकॉर्ड मिटाना', 'स्टॉक छिपाना'],
        ['उधार बिक्री का रिकॉर्ड क्यों जरूरी है?', 'बकाया राशि याद रखने के लिए', 'दुकान सजाने के लिए', 'फोन अपडेट के लिए', 'मौसम जानने के लिए'],
      ];
      for (var i = 0; i < facts.length; i++) {
        bank.add(_quizQuestion('business_$i', facts[i][0], facts[i][1], facts[i].sublist(2)));
      }
      _addBusinessGeneratedQuestions(bank);
    }
    return bank;
  }


  void _addEnglishGeneratedQuestions(List<Map<String, dynamic>> bank) {
    final subjects = <(String, bool)>[
      ('I', false), ('You', false), ('We', false), ('They', false),
      ('He', true), ('She', true), ('It', true),
    ];
    final adjectives = <String>[
      'happy','ready','careful','kind','honest','busy','strong','polite',
      'brave','calm','active','quiet','helpful','healthy','hungry','tired',
      'clever','friendly','patient','confident','safe','early','late','free',
      'young','old','clean','neat','smart','famous','useful','important',
      'beautiful','comfortable','excited','curious','creative','successful',
      'available','different','correct','wrong','gentle','serious','proud',
      'cheerful','responsible','talented','grateful',
    ];
    for (var s = 0; s < subjects.length; s++) {
      final subject = subjects[s].$1;
      final answer = subject == 'I' ? 'am' : subjects[s].$2 ? 'is' : 'are';
      for (var i = 0; i < adjectives.length; i++) {
        bank.add(_quizQuestion('eng_be_${s}_$i',
          'For "$subject", choose the correct verb: "$subject ___ ${adjectives[i]}."',
          answer, ['am','is','are','be']));
      }
    }
    String thirdPerson(String verb) {
      if (verb == 'have') return 'has';
      if (verb == 'do') return 'does';
      if (verb == 'go') return 'goes';
      if (verb.endsWith('y') && verb.length > 1 &&
          !'aeiou'.contains(verb[verb.length - 2])) {
        return '${verb.substring(0, verb.length - 1)}ies';
      }
      if (verb.endsWith('s') || verb.endsWith('x') || verb.endsWith('z') ||
          verb.endsWith('ch') || verb.endsWith('sh') || verb.endsWith('o')) {
        return '${verb}es';
      }
      return '${verb}s';
    }
    final verbs = <String>{
      'ask','answer','arrive','bake','believe','call','change','check',
      'clean','climb','close','collect','compare','cook','copy','dance',
      'decide','deliver','describe','design','discuss','divide','dress','dry',
      'enjoy','explain','finish','fix','follow','guess','help','hope',
      'improve','include','invite','join','jump','kick','kiss','laugh',
      'like','listen','live','look','love','manage','marry','measure',
      'miss','mix','move','need','notice','offer','open','organize',
      'paint','pass','play','practice','prefer','prepare','promise','push',
      'reach','remember','repair','repeat','reply','return','save','search',
      'share','show','smile','start','stay','study','talk','teach',
      'thank','touch','try','use','visit','wait','walk','want',
      'wash','watch','work','worry','carry','fly','cry','go',
      'do','have','read','write','speak','learn','sleep','run',
      'plan','travel',
    };
    var verbIndex = 0;
    for (final subject in subjects) {
      for (final verb in verbs) {
        final answer = subject.$2 ? thirdPerson(verb) : verb;
        bank.add(_quizQuestion('eng_present_${subject.$1}_$verbIndex',
          'For "${subject.$1}", choose the correct present-simple form of "$verb".',
          answer, [thirdPerson(verb), '${verb}ing', '${verb}ed']));
        verbIndex++;
      }
    }
    String regularPast(String verb) {
      if (verb == 'prefer') return 'preferred';
      if (verb.endsWith('e')) return '${verb}d';
      if (verb.endsWith('y') && verb.length > 1 &&
          !'aeiou'.contains(verb[verb.length - 2])) {
        return '${verb.substring(0, verb.length - 1)}ied';
      }
      return '${verb}ed';
    }
    final pastVerbs = <String>[
      'ask','answer','arrive','bake','call','change','check','clean','climb',
      'close','collect','compare','cook','copy','dance','decide','deliver',
      'describe','design','discuss','divide','dress','dry','enjoy','explain',
      'finish','fix','follow','guess','help','hope','improve','include',
      'invite','join','jump','kick','kiss','laugh','like','listen','live',
      'look','love','manage','marry','measure','miss','mix','move','need',
      'notice','offer','open','organize','paint','pass','play','practice',
      'prefer','prepare','promise','push','reach','remember','repair',
      'repeat','reply','return','save','search','share','show','smile',
      'start','stay','study','talk','thank','touch','try','use','visit',
      'wait','walk','want','wash','watch','work','worry','carry','cry',
    ];
    for (var i = 0; i < pastVerbs.length; i++) {
      final verb = pastVerbs[i];
      bank.add(_quizQuestion('eng_past_$i',
        'What is the regular simple-past form of "$verb"?',
        regularPast(verb), [verb, '${verb}ing', '${verb}s']));
    }
    final pluralPairs = <(String, String)>[
      ('book','books'),('car','cars'),('box','boxes'),('bus','buses'),
      ('baby','babies'),('city','cities'),('toy','toys'),('key','keys'),
      ('leaf','leaves'),('knife','knives'),('wife','wives'),('wolf','wolves'),
      ('child','children'),('man','men'),('woman','women'),('person','people'),
      ('tooth','teeth'),('foot','feet'),('mouse','mice'),('goose','geese'),
      ('tomato','tomatoes'),('potato','potatoes'),('photo','photos'),
      ('hero','heroes'),('church','churches'),('watch','watches'),
      ('dish','dishes'),('class','classes'),('glass','glasses'),
      ('day','days'),('boy','boys'),('girl','girls'),('house','houses'),
      ('tree','trees'),('river','rivers'),('school','schools'),
      ('teacher','teachers'),('student','students'),('friend','friends'),
      ('family','families'),('country','countries'),('story','stories'),
      ('party','parties'),('match','matches'),('brush','brushes'),
      ('dress','dresses'),('wish','wishes'),('orange','oranges'),
      ('table','tables'),('window','windows'),
    ];
    for (var i = 0; i < pluralPairs.length; i++) {
      final pair = pluralPairs[i];
      bank.add(_quizQuestion('eng_plural_$i',
        'What is the plural of "${pair.$1}"?', pair.$2,
        [pair.$1, '${pair.$1}es', '${pair.$1}s']));
    }
    final articleNouns = <(String, String)>[
      ('apple','an'),('orange','an'),('umbrella','an'),('elephant','an'),
      ('egg','an'),('owl','an'),('idea','an'),('animal','an'),
      ('engine','an'),('island','an'),('insect','an'),('onion','an'),
      ('office','an'),('artist','an'),('answer','an'),('author','an'),
      ('envelope','an'),('ant','an'),('airplane','an'),('ice cream','an'),
      ('book','a'),('car','a'),('dog','a'),('pen','a'),('table','a'),
      ('chair','a'),('house','a'),('mobile phone','a'),('school','a'),
      ('teacher','a'),('student','a'),('doctor','a'),('farmer','a'),
      ('computer','a'),('university','a'),('European city','a'),
      ('useful tool','a'),('one-way ticket','a'),('hotel','a'),
      ('river','a'),('garden','a'),('shop','a'),('window','a'),
      ('friend','a'),('small umbrella','a'),('yellow bus','a'),
      ('red apple','a'),('honest person','an'),('hour','an'),('uniform','a'),
    ];
    for (var i = 0; i < articleNouns.length; i++) {
      final pair = articleNouns[i];
      bank.add(_quizQuestion('eng_article_$i',
        'Choose the correct article before "${pair.$1}".', pair.$2,
        [pair.$2 == 'a' ? 'an' : 'a', 'the', 'no article']));
    }
  }

  void _addDigitalGeneratedQuestions(List<Map<String, dynamic>> bank) {
    for (var kib = 1; kib <= 1000; kib++) {
      final bytes = kib * 1024;
      bank.add(_quizQuestion('digital_kib_bytes_$kib',
        '$kib KiB (binary) में कितने bytes होते हैं?', '$bytes',
        ['${kib * 1000}', '${kib * 512}', '${bytes + 1}']));
    }
    for (var mib = 1; mib <= 1000; mib++) {
      final kib = mib * 1024;
      bank.add(_quizQuestion('digital_mib_kib_$mib',
        '$mib MiB (binary) में कितने KiB होते हैं?', '$kib',
        ['${mib * 1000}', '${mib * 512}', '${kib + 1}']));
    }
    for (var bytes = 1; bytes <= 1000; bytes++) {
      final bits = bytes * 8;
      bank.add(_quizQuestion('digital_bytes_bits_$bytes',
        '$bytes bytes में कितने bits होते हैं?', '$bits',
        ['${bytes * 4}', '${bytes * 10}', '${bytes * 16}']));
    }
  }

  void _addBusinessGeneratedQuestions(List<Map<String, dynamic>> bank) {
    final rates = <int>[5, 10, 15, 20, 25, 30, 40, 50];
    for (var cost = 100; cost <= 10000; cost += 100) {
      for (final rate in rates) {
        final profit = cost * rate ~/ 100;
        final selling = cost + profit;
        bank.add(_quizQuestion('business_profit_${cost}_$rate',
          '₹$cost की लागत पर $rate% मुनाफा चाहिए। बिक्री मूल्य कितना रखें?',
          '₹$selling', ['₹${cost - profit}', '₹$profit', '₹${selling + 10}']));
        final lossSelling = cost - profit;
        bank.add(_quizQuestion('business_loss_${cost}_$rate',
          '₹$cost की लागत पर $rate% नुकसान हुआ। बिक्री मूल्य कितना था?',
          '₹$lossSelling', ['₹${cost + profit}', '₹$profit', '₹${lossSelling - 10}']));
      }
    }
    for (var base = 100; base <= 5000; base += 100) {
      for (final rate in rates) {
        final discount = base * rate ~/ 100;
        bank.add(_quizQuestion('business_discount_${base}_$rate',
          '₹$base पर $rate% छूट की रकम कितनी होगी?', '₹$discount',
          ['₹${base - discount}', '₹${discount + 5}', '₹$base']));
      }
      for (final rate in <int>[5, 12, 18, 28]) {
        final gst = base * rate ~/ 100;
        bank.add(_quizQuestion('business_gst_${base}_$rate',
          '₹$base पर $rate% GST की रकम कितनी होगी?', '₹$gst',
          ['₹$base', '₹${gst + 5}', '₹${gst * 2}']));
      }
    }
  }

  Future<void> _runQuiz() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final bank = _questionsForTopic();
    final seen = (prefs.getStringList(_quizSeenKey) ?? <String>[]).toSet();
    var available = bank.where((q) => !seen.contains(q['id'])).toList();
    if (available.isEmpty) {
      seen.clear();
      available = List<Map<String, dynamic>>.from(bank);
    }
    available.shuffle(math.Random());
    final questions = available.take(math.min(10, available.length)).map((source) {
      final options = List<String>.from(source['o'] as List<String>);
      final answerText = options[source['a'] as int];
      options.shuffle(math.Random());
      return <String, dynamic>{...source, 'o': options, 'a': options.indexOf(answerText)};
    }).toList();
    var index = 0, selected = -1, score = 0;
    String? feedback;
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        final question = questions[index];
        final options = question['o'] as List<String>;
        return AlertDialog(
          title: Text('$_topic • अभ्यास टेस्ट'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('प्रश्न ${index + 1} / ${questions.length}  •  सही उत्तर $score', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: (index + 1) / questions.length, minHeight: 7)),
            const SizedBox(height: 16),
            Text(question['q'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            RadioGroup<int>(
              groupValue: selected,
              onChanged: (value) { if (feedback == null) setDialogState(() => selected = value ?? -1); },
              child: Column(children: List.generate(options.length, (i) => RadioListTile<int>(
                dense: true, contentPadding: EdgeInsets.zero, value: i, title: Text(options[i]),
              ))),
            ),
            if (feedback == 'wrong') Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('यह उत्तर सही नहीं है। सही उत्तर: ${options[question['a'] as int]}। फिर से प्रयास करें।',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
            if (feedback == 'correct') const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('बिल्कुल सही! अब अगला सवाल।', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('बंद करें')),
            FilledButton(
              onPressed: selected < 0 ? null : () {
                if (feedback == 'wrong') {
                  setDialogState(() { selected = -1; feedback = null; });
                } else if (feedback == 'correct') {
                  if (index == questions.length - 1) {
                    Navigator.pop(context, score);
                  } else {
                    setDialogState(() { index++; selected = -1; feedback = null; });
                  }
                } else if (selected == question['a']) {
                  score++;
                  seen.add(question['id'] as String);
                  setDialogState(() => feedback = 'correct');
                } else {
                  setDialogState(() => feedback = 'wrong');
                }
              },
              child: Text(feedback == 'wrong' ? 'फिर कोशिश करें' : feedback == 'correct'
                  ? (index == questions.length - 1 ? 'परिणाम देखें' : 'अगला सवाल')
                  : 'उत्तर जाँचें'),
            ),
          ],
        );
      }),
    );
    if (result == null) return;
    await prefs.setStringList(_quizSeenKey, seen.toList());
    _completedQuizzes.add(_topic);
    await prefs.setStringList(_progressKey, _completedQuizzes.toList());
    if (mounted) {
      setState(() {});
      showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: const Text('टेस्ट पूरा हुआ'),
        content: Text('आपका स्कोर: $result / ${questions.length}. ${result == questions.length ? 'बहुत अच्छा! सभी उत्तर सही हैं।' : 'अभ्यास जारी रखें—अगली बार नए सवाल मिलेंगे।'}'),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('ठीक है'))],
      ));
    }
  }

  String get _voicePendingKey {
    final userId = _accountId;
    return 'bs_ai_teacher_voice_pending_' + userId;
  }
  String get _voicePendingSessionKey => _voicePendingKey + '_session';

  Future<bool> _refreshVoiceUsageFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getInt(_voicePendingKey) ?? 0;
      if (pending > 0) {
        var sessionId = prefs.getString(_voicePendingSessionKey);
        sessionId ??= '${_accountId}_${DateTime.now().microsecondsSinceEpoch}';
        await prefs.setString(_voicePendingSessionKey, sessionId);
        await Supabase.instance.client.rpc(
          'consume_ai_teacher_voice_seconds',
          params: {'p_seconds': pending.clamp(1, 300), 'p_session_id': sessionId},
        );
        await prefs.remove(_voicePendingKey);
        await prefs.remove(_voicePendingSessionKey);
      }
      final result = await Supabase.instance.client.rpc('get_ai_teacher_voice_usage');
      if (result is! List || result.isEmpty || result.first is! Map) {
        throw Exception('Invalid voice quota response');
      }
      final row = result.first as Map;
      final used = (row['used_seconds'] as num?)?.toInt() ?? 0;
      await prefs.setInt(_voiceUsageKey, used.clamp(0, 300));
      if (mounted) setState(() => _voiceUsedSeconds = used.clamp(0, 300));
      return true;
    } catch (_) {
      if (mounted) setState(() => _voiceMessage = 'वॉइस सीमा जाँचने के लिए इंटरनेट कनेक्शन जरूरी है।');
      return false;
    }
  }

  Future<void> _loadVoiceUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_voiceUsageKey) ?? 0;
    if (mounted) setState(() => _voiceUsedSeconds = used.clamp(0, 300));
    await _refreshVoiceUsageFromServer();
  }

  Future<void> _finishVoiceSession() async {
    if (!_voiceStopwatch.isRunning) return;
    _voiceStopwatch.stop();
    final elapsed = _voiceStopwatch.elapsed.inSeconds;
    _voiceStopwatch.reset();
    var updated = (_voiceUsedSeconds + elapsed).clamp(0, 300).toInt();
    final prefs = await SharedPreferences.getInstance();
    if (elapsed > 0) {
      final pending = prefs.getInt(_voicePendingKey) ?? 0;
      final pendingSeconds = (pending + elapsed).clamp(1, 300).toInt();
      final sessionId = '${Supabase.instance.client.auth.currentUser?.id ?? 'user'}_${DateTime.now().microsecondsSinceEpoch}';
      await prefs.setInt(_voicePendingKey, pendingSeconds);
      await prefs.setString(_voicePendingSessionKey, sessionId);
      try {
        final result = await Supabase.instance.client.rpc(
          'consume_ai_teacher_voice_seconds',
          params: {'p_seconds': pendingSeconds, 'p_session_id': sessionId},
        );
        if (result is! List || result.isEmpty || result.first is! Map) {
          throw Exception('Invalid voice quota response');
        }
        final row = result.first as Map;
        updated = ((row['used_seconds'] as num?)?.toInt() ?? updated).clamp(0, 300).toInt();
        await prefs.setInt(_voiceUsageKey, updated);
        await prefs.remove(_voicePendingKey);
        await prefs.remove(_voicePendingSessionKey);
      } catch (_) {
        updated = 300;
        if (mounted) setState(() => _voiceMessage = 'वॉइस उपयोग सर्वर से सिंक नहीं हुआ। इंटरनेट जुड़ने पर दोबारा जाँचें।');
      }
    }
    if (mounted) setState(() { _voiceUsedSeconds = updated; _listening = false; });
  }

  Future<void> _startVoiceInput() async {
    if (_listening) { await _speech.stop(); await _finishVoiceSession(); return; }
    if (!await _refreshVoiceUsageFromServer()) return;
    if (!mounted) return;
    final remaining = _voiceRemaining;
    if (remaining <= 0) {
      setState(() => _voiceMessage = 'आज की 5 मिनट की वॉइस सीमा पूरी हो गई है।');
      return;
    }
    final microphone = await Permission.microphone.request();
    if (!mounted) return;
    if (!microphone.isGranted) {
      setState(() => _voiceMessage = 'बोलकर सवाल पूछने के लिए माइक्रोफोन की अनुमति दें।');
      return;
    }
    if (!_speechInitialized) {
      _speechInitialized = await _speech.initialize(
        onStatus: (status) { if (status == 'notListening') _finishVoiceSession(); },
        onError: (_) { _finishVoiceSession(); if (mounted) setState(() => _voiceMessage = 'आवाज़ पहचान नहीं हो पाई। दोबारा कोशिश करें।'); },
      );
      if (!mounted) return;
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
        listenOptions: SpeechListenOptions(
          localeId: widget.english ? 'en-IN' : 'hi-IN',
          listenFor: Duration(seconds: remaining),
          pauseFor: const Duration(seconds: 5),
        ),
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
      final allowedSeconds = _voiceRemaining;
      await _tts.setLanguage(widget.english ? 'en-IN' : 'hi-IN');
      if (!mounted) return;
      await _tts.setSpeechRate(0.45);
      if (!mounted) return;
      setState(() => _speaking = true);
      _voiceStopwatch.start();
      _voiceTimer?.cancel();
      _voiceTimer = Timer(Duration(seconds: allowedSeconds), _stopSpeech);
      await _tts.speak(answer);
      _voiceTimer?.cancel();
      _voiceTimer = null;
      await _finishVoiceSession();
    } catch (_) {
      await _finishVoiceSession();
      if (mounted) setState(() { _speaking = false; _voiceMessage = 'इस फोन में चुनी गई भाषा की आवाज़ उपलब्ध नहीं है।'; });
    }
  }

  Future<void> _stopSpeech() async {
    _voiceTimer?.cancel();
    _voiceTimer = null;
    await _tts.stop();
    await _finishVoiceSession();
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _voiceStopwatch.isRunning) {
      if (_listening) _speech.stop();
      if (_speaking) _tts.stop();
      _voiceTimer?.cancel();
      _voiceTimer = null;
      _finishVoiceSession();
      if (mounted) setState(() { _listening = false; _speaking = false; });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceTimer?.cancel();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Teacher Academy'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.school_rounded, color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
      body: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3D4CE0), Color(0xFF8B45D6), Color(0xFFEC4899)]),
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
        ..._courses.map((course) {
          final active = _topic == course.title;
          final accent = Theme.of(context).colorScheme.primary;
          return Card(
            margin: const EdgeInsets.only(bottom: 9),
            elevation: active ? 2 : 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: active ? accent.withValues(alpha: .55) : Theme.of(context).dividerColor.withValues(alpha: .45), width: active ? 1.4 : .8),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              leading: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [course.color, Color.lerp(course.color, Colors.white, .48)!]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(course.icon, color: accent, size: 27),
              ),
              title: Text(course.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 3), child: Text(course.subtitle)),
              trailing: Icon(active ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded, size: active ? 22 : 16, color: active ? accent : Colors.blueGrey),
              onTap: () => setState(() { _topic = course.title; _lesson = course.lessons.first; _answer = null; _error = null; }),
            ),
          );
        }),
        const SizedBox(height: 10),
        Text('आज का पाठ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: DropdownButtonFormField<String>(
            initialValue: _lesson,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'पाठ चुनें',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.menu_book_outlined),
            ),
            items: selected.lessons.map((lesson) => DropdownMenuItem(value: lesson, child: Text(lesson, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (value) => setState(() { if (value != null) { _lesson = value; _answer = null; } }),
          ),
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                Theme.of(context).colorScheme.secondary.withValues(alpha: .06),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: .14)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.auto_awesome, color: Color(0xFF6252B8)), SizedBox(width: 8), Text('AI Teacher से पूछें', style: TextStyle(color: Color(0xFF25345B), fontSize: 16, fontWeight: FontWeight.w900))]),
            const SizedBox(height: 10),
            TextField(controller: _question, minLines: 2, maxLines: 4, decoration: const InputDecoration(hintText: 'अपना सवाल यहाँ लिखें…', border: OutlineInputBorder())),
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
        ),
      ),
    );
  }
}
