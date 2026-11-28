import 'dart:convert';
import 'ai_teacher_curriculum.dart';
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
  String _part = 'Level 1 • English Foundations';
  String _lesson = 'Alphabet and pronunciation';
  String _provider = '';

  static const _courses = <({String title, String subtitle, IconData icon, Color color, List<String> lessons})>[
    (title: 'English Skills', subtitle: 'बोलना, पढ़ना और लिखना', icon: Icons.translate_rounded, color: Color(0xFFE8EEFF), lessons: ['Daily conversation', 'Grammar basics', 'Writing practice']),
    (title: 'Computer & Digital Skills', subtitle: 'कंप्यूटर और डिजिटल जानकारी', icon: Icons.computer_rounded, color: Color(0xFFE1F5F0), lessons: ['Computer basics', 'Internet safety', 'Digital payments']),
    (title: 'Maths & General Knowledge', subtitle: 'गणित और सामान्य ज्ञान', icon: Icons.calculate_rounded, color: Color(0xFFFFF1D9), lessons: ['Basic mathematics', 'Percentages', 'General knowledge']),
    (title: 'Business Skills', subtitle: 'छोटा कारोबार और हिसाब', icon: Icons.storefront_rounded, color: Color(0xFFF0E8FF), lessons: ['Business basics', 'Customer handling', 'Profit and loss']),
  ];

  // Course -> Part -> Lesson curriculum. Keep each level selectable so learners
  // can study only the skill they need instead of being forced through one long list.
  static const _courseParts = AiTeacherCurriculum.courseParts;

  List<({String title, List<String> lessons})> get _selectedParts =>
      _courseParts[_topic] ?? const [];

  ({String title, List<String> lessons}) get _selectedPart =>
      _selectedParts.firstWhere((part) => part.title == _part,
          orElse: () => _selectedParts.first);

  static const _lessonContent = <String, String>{
    'Self introduction': 'अपना परिचय देने का क्रम सीखें: अभिवादन, नाम, शहर, काम या पढ़ाई और धन्यवाद। उदाहरण: “Hello, my name is Ravi. I live in Lucknow. I am a student.”',
    'Asking questions': 'What, Where, When, Who और How से सवाल बनाना सीखें। उदाहरण: “Where do you live?” और “What do you do?” सवाल के अंत में question mark (?) लगाएँ।',
    'Tenses': 'Present में अभी या रोज़ होने वाला काम, Past में बीता हुआ काम और Future में आगे होने वाला काम बताते हैं। उदाहरण: I work, I worked, I will work.',
    'Daily vocabulary': 'रोज़मर्रा के शब्द विषय के अनुसार सीखें: घर, भोजन, यात्रा, समय और खरीदारी। हर नए शब्द से एक छोटा वाक्य बनाएँ और उसे बोलकर दोहराएँ।',
    'Reading practice': 'छोटे अंग्रेज़ी पैराग्राफ धीरे पढ़ें। पहले मुख्य विचार समझें, फिर नए शब्दों का अर्थ देखें और अंत में दो वाक्यों में सार बताएं।',
    'Sentence writing': 'वाक्य में कर्ता, क्रिया और बाकी जानकारी का सही क्रम रखें। उदाहरण: “I read a book.” वाक्य का पहला अक्षर बड़ा और अंत में उचित विराम चिह्न रखें।',
    'Messages & emails': 'संदेश में अभिवादन, मुख्य बात और विनम्र समापन रखें। ईमेल में विषय (Subject) लिखें और भेजने से पहले नाम, तारीख तथा spelling जाँचें।',
    'Parts of a computer': 'CPU कंप्यूटर के निर्देशों को प्रोसेस करता है, Monitor जानकारी दिखाता है, Keyboard इनपुट देता है और Printer कागज़ पर आउटपुट देता है।',
    'Keyboard and mouse': 'Keyboard से अक्षर और अंक टाइप करें। Enter नई पंक्ति/कमांड, Backspace पिछला अक्षर हटाता है और mouse से क्लिक, डबल-क्लिक तथा drag किया जाता है।',
    'Files and folders': 'File में दस्तावेज़ या फोटो जैसी जानकारी रहती है। Folder फाइलों को व्यवस्थित रखता है। अर्थपूर्ण नाम दें, सही जगह सेव करें और जरूरी फाइल का backup रखें।',
    'Word processing': 'Word processor में दस्तावेज़ टाइप, edit और format करें। Heading, font size, alignment और Save का उपयोग करें; Print से कागज़ पर प्रति निकाल सकते हैं।',
    'Spreadsheets': 'Spreadsheet में data rows और columns में रखें। Cell में संख्या या text लिखें। SUM जैसे formula से जोड़ करें और तालिका को साफ headings दें।',
    'Internet basics': 'Internet कई नेटवर्कों को जोड़ता है। Browser से वेबसाइट खोलें और search engine से जानकारी खोजें। सही जानकारी के लिए भरोसेमंद स्रोत और तारीख जाँचें।',
    'Money calculations': 'दुकान या घर के हिसाब में कुल कीमत, बाकी पैसे और छूट निकालें। उदाहरण: ₹100 की वस्तु पर ₹20 छूट हो तो भुगतान ₹80 होगा।',
    'Addition and subtraction': 'जोड़ से कुल मात्रा निकालें और घटाव से अंतर या बाकी राशि। उदाहरण: 25 + 15 = 40 और 50 − 20 = 30।',
    'Multiplication and division': 'गुणा बराबर समूहों का तेज जोड़ है। भाग से वस्तुओं को बराबर बाँटते हैं। उदाहरण: 6 × 4 = 24 और 24 ÷ 6 = 4।',
    'Fractions and decimals': 'भिन्न किसी पूरी वस्तु के हिस्से को दिखाती है। 1/2 आधा और 1/4 चौथाई है। दशमलव 0.5 भी आधे के बराबर है।',
    'Ratio and proportion': 'अनुपात दो मात्राओं की तुलना करता है। 2:1 का अर्थ पहली मात्रा दूसरी से दोगुनी है। समान अनुपात को गुणा या भाग से बढ़ा/घटा सकते हैं।',
    'Science and geography': 'विज्ञान में पदार्थ, ऊर्जा और जीवों का अध्ययन होता है। भूगोल में पृथ्वी, महाद्वीप, महासागर, मौसम और स्थानों का अध्ययन करते हैं।',
    'Business planning': 'व्यवसाय शुरू करने से पहले ग्राहक, जरूरत, लागत, बिक्री मूल्य और शुरुआती पूँजी तय करें। छोटा बजट और सरल योजना लिखें।',
    'Products and pricing': 'उत्पाद की कीमत तय करते समय खरीद लागत, पैकिंग, किराया और अन्य खर्च जोड़ें। फिर उचित मुनाफा रखें और ग्राहक को कीमत साफ बताएँ।',
    'Sales skills': 'ग्राहक की जरूरत पूछें, उत्पाद का सही लाभ बताएँ, कीमत स्पष्ट रखें और बिना दबाव निर्णय लेने दें। बिक्री के बाद रसीद दें।',
    'Customer service': 'ग्राहक की शिकायत ध्यान से सुनें, समस्या दोहराकर पुष्टि करें और समय पर समाधान दें। वादा वही करें जिसे पूरा कर सकें।',
    'Bookkeeping': 'हर लेन-देन की तारीख, विवरण, आय और खर्च लिखें। रसीद संभालें और रोज़ का कुल मिलान करें ताकि हिसाब सही रहे।',
    'Budget and savings': 'आय और जरूरी खर्च लिखकर बजट बनाएँ। पहले आवश्यक खर्च रखें, फिर नियमित बचत अलग करें और अनावश्यक खर्च पहचानें।',
  };

  static const _lessonQuizRows = <String, List<List<String>>>{
    'Self introduction': [
      ['परिचय की शुरुआत किससे करना अच्छा है?', 'अभिवादन से', 'शिकायत से', 'कीमत से', 'विदाई से'],
      ['“My name is Ravi” में क्या बताया गया है?', 'नाम', 'उम्र', 'पता', 'पेशा'],
      ['“I live in Lucknow” का अर्थ क्या है?', 'मैं लखनऊ में रहता हूँ', 'मैं दिल्ली जा रहा हूँ', 'मेरा नाम लखनऊ है', 'मैं पढ़ाता हूँ'],
    ],
    'Asking questions': [
      ['स्थान पूछने के लिए कौन-सा शब्द उपयोग होता है?', 'Where', 'When', 'Who', 'Why'],
      ['“What is your name?” किस बारे में पूछता है?', 'नाम', 'उम्र', 'स्थान', 'समय'],
      ['सवाल के अंत में क्या लगाते हैं?', 'Question mark (?)', 'Full stop (.)', 'Comma (,)', 'Colon (:)'],
    ],
    'Tenses': [
      ['Past tense किस समय को बताता है?', 'बीता हुआ समय', 'वर्तमान', 'भविष्य', 'स्थान'],
      ['“I will work” कौन-सा समय है?', 'Future', 'Past', 'Present', 'कोई नहीं'],
      ['“I worked” कौन-सा समय है?', 'Past', 'Future', 'Present', 'Plural'],
    ],
    'Daily vocabulary': [
      ['Vocabulary का अर्थ क्या है?', 'शब्द-भंडार', 'गणित', 'नक्शा', 'समय-सारणी'],
      ['नया शब्द सीखने के बाद क्या करना उपयोगी है?', 'उससे वाक्य बनाना', 'उसे भूल जाना', 'केवल लिखावट देखना', 'फोन बंद करना'],
      ['शब्दों को किस तरह सीखना आसान होता है?', 'विषय के अनुसार', 'बिना अर्थ', 'केवल उल्टा पढ़कर', 'सिर्फ संख्या से'],
    ],
    'Reading practice': [
      ['पैराग्राफ पढ़ते समय पहले क्या समझें?', 'मुख्य विचार', 'पन्ने का रंग', 'फॉन्ट का नाम', 'कागज़ का आकार'],
      ['नए शब्द का अर्थ समझने के लिए क्या करें?', 'शब्द का अर्थ देखें', 'वाक्य छोड़ दें', 'पढ़ना बंद करें', 'अक्षर मिटाएँ'],
      ['पढ़ने के बाद सार कैसे बताएं?', 'अपने शब्दों में', 'बिना पढ़े', 'केवल शीर्षक दोहराकर', 'असंबंधित बात से'],
    ],
    'Sentence writing': [
      ['एक साधारण अंग्रेज़ी वाक्य का सही उदाहरण कौन-सा है?', 'I read a book.', 'Book I a read.', 'Read book I a.', 'A I book read.'],
      ['वाक्य की शुरुआत किससे होती है?', 'बड़े अक्षर से', 'छोटे अक्षर से', 'कॉमा से', 'अंक से'],
      ['साधारण कथन के अंत में क्या लगता है?', 'Full stop', 'Question mark', 'Comma', 'Colon'],
    ],
    'Messages & emails': [
      ['ईमेल में Subject का काम क्या है?', 'विषय बताना', 'पासवर्ड दिखाना', 'फोटो एडिट करना', 'फोन चार्ज करना'],
      ['संदेश का अच्छा क्रम क्या है?', 'अभिवादन, मुख्य बात, समापन', 'केवल नाम', 'केवल कीमत', 'बिना संदर्भ'],
      ['ईमेल भेजने से पहले क्या जाँचना चाहिए?', 'प्राप्तकर्ता और spelling', 'फोन का रंग', 'बैटरी का ब्रांड', 'वॉलपेपर'],
    ],
    'Parts of a computer': [
      ['कंप्यूटर का कौन-सा भाग निर्देश प्रोसेस करता है?', 'CPU', 'Monitor', 'Printer', 'Speaker'],
      ['जानकारी स्क्रीन पर कौन दिखाता है?', 'Monitor', 'Keyboard', 'Mouse', 'Printer'],
      ['कागज़ पर आउटपुट कौन देता है?', 'Printer', 'CPU', 'Mouse', 'Router'],
    ],
    'Keyboard and mouse': [
      ['टाइप करने के लिए क्या उपयोग होता है?', 'Keyboard', 'Monitor', 'Printer', 'Speaker'],
      ['Backspace का उपयोग किसलिए होता है?', 'पिछला अक्षर हटाने के लिए', 'प्रिंट करने के लिए', 'फाइल सेव करने के लिए', 'आवाज़ बढ़ाने के लिए'],
      ['किससे किसी वस्तु को क्लिक करके चुनते हैं?', 'Mouse', 'Printer', 'Monitor', 'CPU'],
    ],
    'Files and folders': [
      ['Folder का मुख्य काम क्या है?', 'फाइलों को व्यवस्थित रखना', 'स्क्रीन दिखाना', 'टाइप करना', 'आवाज़ रिकॉर्ड करना'],
      ['फाइल का नाम कैसा रखना अच्छा है?', 'अर्थपूर्ण', 'हमेशा खाली', 'केवल चिन्ह', 'हर बार एक जैसा'],
      ['Backup क्यों रखते हैं?', 'फाइल खोने पर वापस पाने के लिए', 'स्क्रीन चमकाने के लिए', 'इंटरनेट तेज करने के लिए', 'बैटरी बचाने के लिए'],
    ],
    'Word processing': [
      ['Word processor का उपयोग किसलिए होता है?', 'दस्तावेज़ बनाने और संपादित करने के लिए', 'मौसम देखने के लिए', 'कॉल करने के लिए', 'फोटो खींचने के लिए'],
      ['Heading से क्या लाभ होता है?', 'दस्तावेज़ व्यवस्थित दिखता है', 'फाइल मिट जाती है', 'कंप्यूटर बंद होता है', 'नेटवर्क बदलता है'],
      ['काम सुरक्षित रखने के लिए क्या करें?', 'Save करें', 'बिना सेव बंद करें', 'केवल स्क्रीन देखें', 'कीबोर्ड हटाएँ'],
    ],
    'Spreadsheets': [
      ['Spreadsheet में data किसमें रखा जाता है?', 'Rows और columns', 'केवल slides', 'केवल paragraphs', 'केवल photos'],
      ['SUM formula किसलिए है?', 'जोड़ने के लिए', 'घटाने के लिए', 'प्रिंट करने के लिए', 'फाइल बंद करने के लिए'],
      ['Row और column के मिलने की जगह क्या कहलाती है?', 'Cell', 'Folder', 'Browser', 'Page'],
    ],
    'Internet basics': [
      ['वेबसाइट खोलने के लिए सामान्यतः क्या उपयोग करते हैं?', 'Browser', 'Calculator', 'Camera', 'Torch'],
      ['Search engine का उपयोग किसलिए होता है?', 'जानकारी खोजने के लिए', 'फोन चार्ज करने के लिए', 'फाइल प्रिंट करने के लिए', 'पासवर्ड बनाने के लिए'],
      ['ऑनलाइन जानकारी की विश्वसनीयता कैसे जाँचें?', 'स्रोत और तारीख देखकर', 'केवल रंग देखकर', 'बिना पढ़े', 'पहले लिंक को सच मानकर'],
    ],
    'Money calculations': [
      ['₹100 पर ₹20 छूट के बाद कीमत कितनी होगी?', '₹80', '₹90', '₹120', '₹20'],
      ['कुल कीमत निकालने के लिए क्या करते हैं?', 'सभी वस्तुओं की कीमत जोड़ते हैं', 'कीमत मिटाते हैं', 'रंग गिनते हैं', 'तारीख घटाते हैं'],
      ['खरीदारी में बाकी पैसे कैसे निकालते हैं?', 'दिए पैसे में से कीमत घटाकर', 'कीमत में रंग जोड़कर', 'तारीख से गुणा करके', 'नाम जोड़कर'],
    ],
    'Addition and subtraction': [
      ['25 + 15 कितना है?', '40', '30', '45', '50'],
      ['50 − 20 कितना है?', '30', '20', '40', '70'],
      ['घटाव से क्या पता चलता है?', 'अंतर या बाकी', 'गुणनफल', 'क्षेत्रफल हमेशा', 'समय क्षेत्र'],
    ],
    'Multiplication and division': [
      ['6 × 4 कितना है?', '24', '20', '18', '28'],
      ['24 ÷ 6 कितना है?', '4', '3', '5', '6'],
      ['गुणा किसका तेज तरीका है?', 'बराबर समूहों का जोड़', 'घटाव', 'तारीख लिखना', 'मापना'],
    ],
    'Fractions and decimals': [
      ['1/2 का अर्थ क्या है?', 'आधा', 'चौथाई', 'तीन चौथाई', 'दोगुना'],
      ['1/4 को क्या कहते हैं?', 'चौथाई', 'आधा', 'पूरा', 'दोगुना'],
      ['0.5 किस भिन्न के बराबर है?', '1/2', '1/4', '1/3', '1/5'],
    ],
    'Ratio and proportion': [
      ['2:1 अनुपात का अर्थ क्या है?', 'पहली मात्रा दूसरी से दोगुनी', 'दोनों शून्य', 'पहली आधी', 'दोनों बराबर हमेशा'],
      ['अनुपात किसकी तुलना करता है?', 'दो मात्राओं की', 'दो रंगों की', 'दो तारीखों की', 'दो नामों की'],
      ['समान अनुपात बनाने के लिए दोनों पदों को क्या कर सकते हैं?', 'एक ही संख्या से गुणा', 'अलग-अलग जोड़', 'एक को मिटा दें', 'रंग बदलें'],
    ],
    'Science and geography': [
      ['भूगोल में किसका अध्ययन होता है?', 'पृथ्वी और स्थानों का', 'केवल व्याकरण', 'केवल व्यापार', 'केवल संगीत'],
      ['सौरमंडल का सबसे बड़ा ग्रह कौन है?', 'बृहस्पति', 'पृथ्वी', 'मंगल', 'शुक्र'],
      ['विज्ञान किसका व्यवस्थित अध्ययन है?', 'प्रकृति और घटनाओं का', 'केवल नक्शों का', 'केवल भाषा का', 'केवल हिसाब का'],
    ],
    'Business planning': [
      ['व्यवसाय योजना में क्या तय करना चाहिए?', 'ग्राहक, लागत और बिक्री', 'केवल दुकान का रंग', 'केवल मोबाइल मॉडल', 'केवल छुट्टी'],
      ['शुरू करने से पहले लागत का अनुमान क्यों?', 'पूँजी की जरूरत समझने के लिए', 'नाम बदलने के लिए', 'ग्राहक छिपाने के लिए', 'दुकान बंद करने के लिए'],
      ['व्यवसाय किसकी जरूरत समझकर शुरू करना चाहिए?', 'ग्राहक की', 'केवल मालिक के जूते की', 'मौसम के रंग की', 'फोन की बैटरी की'],
    ],
    'Products and pricing': [
      ['कीमत तय करते समय किसे जोड़ना चाहिए?', 'खरीद और अन्य खर्च', 'केवल रंग', 'केवल तारीख', 'ग्राहक का फोन मॉडल'],
      ['बिक्री मूल्य में लागत से अधिक हिस्सा क्या कहलाता है?', 'मुनाफा', 'नुकसान', 'उधार', 'स्टॉक'],
      ['ग्राहक को कीमत कैसे बतानी चाहिए?', 'स्पष्ट रूप से', 'छिपाकर', 'हर बार बदलकर', 'बिना पूछे'],
    ],
    'Sales skills': [
      ['बिक्री से पहले ग्राहक से क्या समझें?', 'उसकी जरूरत', 'उसका पासवर्ड', 'उसका OTP', 'उसका फोन मॉडल'],
      ['उत्पाद के बारे में क्या बताना चाहिए?', 'सही लाभ और कीमत', 'गलत वादा', 'छिपी हुई लागत', 'अनजान जानकारी'],
      ['बिक्री के बाद ग्राहक को क्या देना चाहिए?', 'रसीद', 'OTP', 'पासवर्ड', 'PIN'],
    ],
    'Customer service': [
      ['शिकायत मिलने पर पहला कदम क्या है?', 'ध्यान से सुनना', 'अनदेखा करना', 'बहस करना', 'फोन काटना'],
      ['समस्या समझने के बाद क्या करें?', 'समाधान और समय स्पष्ट बताएं', 'वादा छिपाएँ', 'दोष दें', 'बात बदलें'],
      ['ग्राहक से कैसा वादा करना चाहिए?', 'जिसे पूरा कर सकें', 'कोई भी वादा', 'झूठा वादा', 'बिना समय बताए'],
    ],
    'Bookkeeping': [
      ['हिसाब में कौन-सी जानकारी लिखनी चाहिए?', 'तारीख, विवरण, आय और खर्च', 'केवल रंग', 'केवल मौसम', 'केवल फोन मॉडल'],
      ['रसीद क्यों संभालनी चाहिए?', 'लेन-देन का प्रमाण', 'फोन तेज करने के लिए', 'स्क्रीन साफ करने के लिए', 'नेटवर्क बदलने के लिए'],
      ['रोज़ का हिसाब मिलाने से क्या लाभ?', 'रिकॉर्ड सही रहता है', 'खर्च छिपता है', 'ग्राहक मिटता है', 'दुकान बंद होती है'],
    ],
    'Budget and savings': [
      ['बजट बनाने के लिए पहले क्या लिखें?', 'आय और खर्च', 'केवल पसंदीदा रंग', 'केवल छुट्टियाँ', 'केवल फोन नंबर'],
      ['बचत कब अलग रखना अच्छा है?', 'नियमित रूप से', 'केवल साल के अंत में', 'कभी नहीं', 'सिर्फ उधार लेकर'],
      ['अनावश्यक खर्च पहचानने से क्या मदद मिलती है?', 'बचत बढ़ाने में', 'कर्ज बढ़ाने में', 'रिकॉर्ड मिटाने में', 'कीमत छिपाने में'],
    ],
  };

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
    // Progress is tracked per lesson, not merely per course. Ignore legacy
    // course-only entries so the displayed 12-lesson total stays accurate.
    final completedLessons = saved.where((value) => value.split('::').length == 3).toSet();
    if (mounted) {
      setState(() {
        _completedQuizzes..clear()..addAll(completedLessons);
      });
    }
  }

  String _lessonSummary() {
    final lessonContent = _lessonContent[_lesson];
    if (lessonContent != null) return lessonContent;
    if (_topic == 'English Skills') {
      if (_lesson == 'Daily conversation') {
        return 'अभ्यास: इन पाँच बातचीतों को बोलकर दोहराएँ। टेस्ट में इन्हीं वाक्यों के जवाब पूछे जाएँगे।\\n'
            '1. Hello, how are you? — I am fine, thank you. (आप कैसे हैं? — मैं ठीक हूँ, धन्यवाद।)\\n'
            '2. What is your name? — My name is Ravi. (आपका नाम क्या है? — मेरा नाम रवि है।)\\n'
            '3. Where are you from? — I am from India. (आप कहाँ से हैं? — मैं भारत से हूँ।)\\n'
            '4. What do you do? — I am a student. (आप क्या करते हैं? — मैं विद्यार्थी हूँ।)\\n'
            '5. Nice to meet you. — Nice to meet you too. (आपसे मिलकर अच्छा लगा। — मुझे भी।)';
      }
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
      if (_lesson == 'General knowledge') return 'आज के पाँच तथ्य याद करें: भारत की राजधानी नई दिल्ली है; राष्ट्रीय पशु बाघ है; राष्ट्रीय पक्षी मोर है; सौरमंडल का सबसे बड़ा ग्रह बृहस्पति है; पानी का रासायनिक सूत्र H₂O है। टेस्ट में इन्हीं तथ्यों से सवाल होंगे।';
      return 'गणित में सवाल को छोटे चरणों में बाँटें। जोड़, घटाव, गुणा और भाग के बाद उत्तर का अनुमान लगाकर जाँच करें।';
    }
    if (_lesson == 'Customer handling') return 'ग्राहक की बात ध्यान से सुनें, जरूरत दोहराकर पुष्टि करें, कीमत और समय साफ बताएँ और शिकायत का सम्मानपूर्वक समाधान करें।';
    if (_lesson == 'Profit and loss') return 'मुनाफा = बिक्री मूल्य − कुल लागत। यदि बिक्री मूल्य लागत से कम है तो नुकसान होता है। किराया, पैकिंग और डिलीवरी जैसी लागत भी जोड़ें।';
    return 'व्यवसाय में बिक्री, लागत, बचत और ग्राहक संतुष्टि का रिकॉर्ड रखें। रोज़ का हिसाब लिखने से सही निर्णय लेने में मदद मिलती है।';
  }


  String get _quizSeenKey => 'bs_ai_teacher_seen_questions_' + _accountId + '_' + _topic + '_' + _part + '_' + _lesson;

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

  // Every quiz is built from the selected lesson's own teaching material.
  // Each lesson has five focused questions; completing all five completes that lesson.
  List<Map<String, dynamic>> _questionsForLesson() {
    final rows = <List<String>>[];
    if (_lessonQuizRows.containsKey(_lesson)) {
      rows.addAll(_lessonQuizRows[_lesson]!);
    } else if (_topic == 'English Skills' && _lesson == 'Daily conversation') {
      rows.addAll([
        ['“Hello, how are you?” का सही जवाब क्या है?', 'I am fine, thank you.', 'My name is Ravi.', 'I am from India.', 'Nice to meet you.'],
        ['“What is your name?” का सही जवाब क्या है?', 'My name is Ravi.', 'I am fine, thank you.', 'I am a student.', 'Good morning.'],
        ['“Where are you from?” का सही जवाब क्या है?', 'I am from India.', 'My name is Ravi.', 'I am fine, thank you.', 'See you tomorrow.'],
        ['“What do you do?” का सही जवाब क्या है?', 'I am a student.', 'I am from India.', 'My name is Ravi.', 'Nice to meet you too.'],
        ['“Nice to meet you.” के जवाब में क्या कहेंगे?', 'Nice to meet you too.', 'I am fine, thank you.', 'Where are you from?', 'Good night.'],
      ]);
    } else if (_topic == 'English Skills' && _lesson == 'Grammar basics') {
      rows.addAll([
        ['I ___ ready.', 'am', 'is', 'are', 'be'],
        ['She ___ happy.', 'is', 'am', 'are', 'be'],
        ['They ___ here.', 'are', 'am', 'is', 'be'],
        ['He ___ a teacher.', 'is', 'are', 'am', 'be'],
        ['We ___ friends.', 'are', 'is', 'am', 'be'],
      ]);
    } else if (_topic == 'English Skills') {
      rows.addAll([
        ['वाक्य की शुरुआत कैसे लिखनी चाहिए?', 'बड़े अक्षर से', 'छोटे अक्षर से', 'अंक से', 'कॉमा से'],
        ['साधारण कथन के अंत में क्या लगाते हैं?', 'Full stop (.)', 'Comma (,)', 'Colon (:)', 'Exclamation mark (!)'],
        ['सवाल के अंत में कौन-सा चिन्ह लगता है?', 'Question mark (?)', 'Full stop (.)', 'Comma (,)', 'Hyphen (-)'],
        ['लिखने के बाद क्या जाँचना चाहिए?', 'Spelling और विराम चिह्न', 'केवल पन्ने का रंग', 'फोन की बैटरी', 'इंटरनेट की गति'],
        ['“I am fine.” किस प्रकार का वाक्य है?', 'साधारण कथन', 'प्रश्न', 'आदेश', 'विस्मयादिबोधक'],
      ]);
    } else if (_topic == 'Computer & Digital Skills' && _lesson == 'Computer basics') {
      rows.addAll([
        ['कंप्यूटर में टाइप करने के लिए क्या उपयोग होता है?', 'Keyboard', 'Monitor', 'Printer', 'Speaker'],
        ['स्क्रीन पर जानकारी कौन दिखाता है?', 'Monitor', 'Mouse', 'Keyboard', 'Printer'],
        ['कागज़ पर प्रिंट कौन निकालता है?', 'Printer', 'Router', 'Webcam', 'Speaker'],
        ['स्क्रीन पर किसी चीज़ को चुनने में क्या मदद करता है?', 'Mouse', 'Printer', 'Speaker', 'Microphone'],
        ['फाइल सेव करने का लाभ क्या है?', 'बाद में फिर खोल सकते हैं', 'बैटरी चार्ज होती है', 'इंटरनेट तेज होता है', 'स्क्रीन बड़ी होती है'],
      ]);
    } else if (_topic == 'Computer & Digital Skills' && _lesson == 'Internet safety') {
      rows.addAll([
        ['OTP किसे बताना चाहिए?', 'किसी को नहीं', 'अनजान कॉलर को', 'सोशल मीडिया पर', 'दुकानदार को'],
        ['अनजान लिंक मिलने पर क्या करें?', 'जाँच किए बिना न खोलें', 'तुरंत खोलें', 'सबको भेजें', 'पासवर्ड डालें'],
        ['मजबूत पासवर्ड कैसा होना चाहिए?', 'लंबा और अलग-अलग अक्षरों वाला', '123456', 'अपना नाम', 'मोबाइल नंबर'],
        ['स्क्रीन शेयर करने से पहले क्या करें?', 'व्यक्ति और कारण की पुष्टि करें', 'OTP दिखाएँ', 'बैंक PIN बताएँ', 'अनजान ऐप इंस्टॉल करें'],
        ['बैंक कर्मचारी बनकर कोई PIN माँगे तो?', 'PIN न बताएँ', 'तुरंत बता दें', 'मैसेज में भेजें', 'सोशल मीडिया पर लिखें'],
      ]);
    } else if (_topic == 'Computer & Digital Skills') {
      rows.addAll([
        ['UPI भुगतान से पहले क्या जाँचना चाहिए?', 'प्राप्तकर्ता का नाम और राशि', 'फोन का रंग', 'मौसम', 'बैटरी का ब्रांड'],
        ['पैसा प्राप्त करने के लिए UPI PIN डालना जरूरी है?', 'नहीं', 'हाँ, हमेशा', 'केवल रात में', 'केवल दुकानदार के लिए'],
        ['UPI PIN डालने का सामान्य अर्थ क्या है?', 'भुगतान की अनुमति देना', 'पैसा अपने-आप मिलना', 'मोबाइल रिचार्ज होना', 'बैंक खाता बंद होना'],
        ['गलत व्यक्ति को भुगतान दिखे तो क्या करें?', 'भुगतान विवरण जाँचकर बैंक/ऐप सहायता लें', 'OTP सबको बताएँ', 'फोन बंद कर दें', 'दोबारा बिना जाँच भुगतान करें'],
        ['QR कोड स्कैन करने के बाद क्या जाँचें?', 'नाम और भुगतान राशि', 'केवल स्क्रीन की चमक', 'फोन मॉडल', 'नेटवर्क का नाम'],
      ]);
    } else if (_topic == 'Maths & General Knowledge' && _lesson == 'Basic mathematics') {
      rows.addAll([
        ['25 + 15 कितना होगा?', '40', '35', '45', '50'],
        ['50 − 20 कितना होगा?', '30', '20', '40', '70'],
        ['6 × 4 कितना होगा?', '24', '20', '18', '28'],
        ['36 ÷ 6 कितना होगा?', '6', '5', '7', '8'],
        ['एक दर्जन में कितनी वस्तुएँ होती हैं?', '12', '10', '6', '20'],
      ]);
    } else if (_topic == 'Maths & General Knowledge' && _lesson == 'Percentages') {
      rows.addAll([
        ['प्रतिशत का अर्थ क्या है?', 'प्रति 100', 'प्रति 10', 'प्रति 1000', 'प्रति 5'],
        ['200 का 25% कितना है?', '50', '25', '40', '75'],
        ['100 का 10% कितना है?', '10', '5', '20', '100'],
        ['400 का 50% कितना है?', '200', '100', '150', '250'],
        ['छूट की गणना में किसका उपयोग होता है?', 'प्रतिशत', 'केवल जोड़', 'केवल भाग', 'तापमान'],
      ]);
    } else if (_topic == 'Maths & General Knowledge') {
      rows.addAll([
        ['भारत की राजधानी क्या है?', 'नई दिल्ली', 'मुंबई', 'जयपुर', 'लखनऊ'],
        ['भारत का राष्ट्रीय पशु कौन है?', 'बाघ', 'हाथी', 'शेर', 'हिरण'],
        ['भारत का राष्ट्रीय पक्षी कौन है?', 'मोर', 'तोता', 'कबूतर', 'हंस'],
        ['सौरमंडल का सबसे बड़ा ग्रह कौन है?', 'बृहस्पति', 'पृथ्वी', 'मंगल', 'शुक्र'],
        ['पानी का रासायनिक सूत्र क्या है?', 'H₂O', 'CO₂', 'O₂', 'NaCl'],
      ]);
    } else if (_topic == 'Business Skills' && _lesson == 'Business basics') {
      rows.addAll([
        ['व्यवसाय में बिक्री का अर्थ क्या है?', 'सामान या सेवा बेचना', 'सामान छिपाना', 'खर्च मिटाना', 'दुकान बंद करना'],
        ['रोज़ का हिसाब क्यों रखना चाहिए?', 'आय और खर्च समझने के लिए', 'रंग चुनने के लिए', 'फोन तेज करने के लिए', 'समय बदलने के लिए'],
        ['स्टॉक रिकॉर्ड किसलिए होता है?', 'सामान की उपलब्ध मात्रा जानने के लिए', 'मौसम देखने के लिए', 'ग्राहक की उम्र जानने के लिए', 'मोबाइल चलाने के लिए'],
        ['बजट बनाने का लाभ क्या है?', 'खर्च पर नियंत्रण', 'खर्च बढ़ाना', 'रिकॉर्ड मिटाना', 'स्टॉक छिपाना'],
        ['कुल लागत में क्या शामिल हो सकता है?', 'खरीद, किराया और पैकिंग', 'केवल मुनाफा', 'केवल ग्राहक का नाम', 'केवल तारीख'],
      ]);
    } else if (_topic == 'Business Skills' && _lesson == 'Customer handling') {
      rows.addAll([
        ['ग्राहक की बात पर पहला कदम क्या है?', 'ध्यान से सुनना', 'बात काटना', 'अनदेखा करना', 'बहस करना'],
        ['जरूरत समझने के बाद क्या करना चाहिए?', 'दोहराकर पुष्टि करना', 'बिना पूछे सामान देना', 'कीमत छिपाना', 'शिकायत मिटाना'],
        ['कीमत और समय कैसे बताना चाहिए?', 'स्पष्ट और सही तरीके से', 'छिपाकर', 'हर बार बदलकर', 'बिना पूछे'],
        ['शिकायत मिलने पर कैसा व्यवहार करें?', 'सम्मानपूर्वक समाधान करें', 'गुस्सा करें', 'अनदेखा करें', 'दोष दें'],
        ['ग्राहक से बात करते समय क्या जरूरी है?', 'धैर्य और स्पष्टता', 'जल्दबाजी और बहस', 'गलत जानकारी', 'अनदेखी'],
      ]);
    } else {
      rows.addAll([
        ['मुनाफा कैसे निकालते हैं?', 'बिक्री मूल्य − कुल लागत', 'लागत + बिक्री', 'केवल बिक्री', 'बिक्री ÷ लागत'],
        ['नुकसान कब होता है?', 'जब बिक्री मूल्य लागत से कम हो', 'जब बिक्री लागत से अधिक हो', 'जब ग्राहक आए', 'जब दुकान खुले'],
        ['यदि लागत ₹100 और बिक्री ₹130 है, मुनाफा कितना है?', '₹30', '₹20', '₹40', '₹10'],
        ['यदि लागत ₹200 और बिक्री ₹180 है, नुकसान कितना है?', '₹20', '₹10', '₹30', '₹40'],
        ['मुनाफा निकालते समय किसे घटाते हैं?', 'बिक्री मूल्य में से कुल लागत', 'लागत में से ग्राहक', 'समय में से बिक्री', 'स्टॉक में से किराया'],
      ]);
    }
    final lessonId = (_topic + '_' + _lesson).replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase();
    return List<Map<String, dynamic>>.generate(rows.length, (index) =>
      _quizQuestion(lessonId + '_' + (index + 1).toString(), rows[index][0], rows[index][1], rows[index].sublist(2)));
  }

  Future<List<Map<String, dynamic>>> _generateQuizForLesson() async {
    if (!widget.supabaseAvailable || Supabase.instance.client.auth.currentUser == null) {
      throw Exception('लॉगिन करके दोबारा प्रयास करें।');
    }
    final response = await Supabase.instance.client.functions.invoke(
      'ai-teacher-assistant',
      body: {
        'question': 'Create exactly 8 multiple-choice questions only about the selected lesson. Cover its actual concepts, from easy to challenging. Return ONLY valid JSON (no markdown) as an array of objects with keys question, options, answer. Each options array must contain exactly 4 distinct strings and answer must exactly match one option. Questions and options must be in the requested language. Do not include unrelated questions.',
        'course': _topic,
        'part': _part,
        'lesson': _lesson,
        'language': widget.english ? 'English' : 'Hindi',
      },
    );
    final data = response.data;
    if (data is! Map || data['answer'] is! String) {
      throw Exception('AI ने सही टेस्ट डेटा नहीं लौटाया।');
    }
    var raw = (data['answer'] as String).trim();
    raw = raw.replaceFirst(RegExp(r'^\s*\`\`\`(?:json)?\s*'), '');
    raw = raw.replaceFirst(RegExp(r'\s*\`\`\`\s*
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    List<Map<String, dynamic>> bank;
    if (_lessonQuizRows.containsKey(_lesson)) {
      bank = _questionsForLesson();
    } else {
      try {
        bank = await _generateQuizForLesson();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('इस लेसन का टेस्ट अभी तैयार नहीं हो पाया: $error')),
          );
        }
        return;
      }
    }
    if (!mounted || bank.isEmpty) return;
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
          title: Text('$_topic • $_part • $_lesson'),
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
    _completedQuizzes.add(_topic + '::' + _part + '::' + _lesson);
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

  Future<void> _teachFullLesson() async {
    _question.text = 'मुझे इस चुने हुए लेसन को बिल्कुल शुरुआत से विस्तार से पढ़ाइए। पहले सीखने के लक्ष्य बताइए, फिर सरल परिभाषाएँ और जरूरी शब्द समझाइए, हर अवधारणा को क्रमवार उदाहरणों के साथ सिखाइए, जहाँ लागू हो वहाँ हल किए हुए सवाल या व्यावहारिक चरण दिखाइए, आम गलतियाँ और उनसे बचने के तरीके बताइए, फिर आसान से कठिन अभ्यास दीजिए। अंत में 5 जाँच प्रश्न और एक छोटा गृहकार्य दीजिए। उत्तर इतना पूरा हो कि विद्यार्थी बिना दूसरी वेबसाइट खोले इस लेसन का अध्ययन कर सके।';
    await _askTeacher();
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
          'part': _part,
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
    final selectedPart = _selectedPart;
    final totalLessons = _courseParts.values.fold<int>(0, (total, parts) => total + parts.fold<int>(0, (count, part) => count + part.lessons.length));
    final currentLessonStatus = _completedQuizzes.contains(_topic + '::' + _part + '::' + _lesson)
        ? 'यह पाठ पूरा है' : 'यह पाठ बाकी है';
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
              onTap: () => setState(() { _topic = course.title; _part = _courseParts[course.title]!.first.title; _lesson = _courseParts[course.title]!.first.lessons.first; _answer = null; _error = null; }),
            ),
          );
        }),
        const SizedBox(height: 10),
        Text('अपना पार्ट चुनें', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _part,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'कोर्स का पार्ट',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: _selectedParts.map((part) => DropdownMenuItem(value: part.title, child: Text(part.title, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (value) => setState(() {
            if (value != null) {
              _part = value;
              _lesson = _selectedParts.firstWhere((part) => part.title == value).lessons.first;
              _answer = null; _error = null;
            }
          }),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _lesson,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'इस पार्ट का लेसन चुनें',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.menu_book_outlined),
          ),
          items: selectedPart.lessons.map((lesson) => DropdownMenuItem(value: lesson, child: Text(lesson, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (value) => setState(() { if (value != null) { _lesson = value; _answer = null; _error = null; } }),
        ),
        const SizedBox(height: 10),
        Card(child: ExpansionTile(
          leading: const Icon(Icons.menu_book_rounded),
          title: const Text('पाठ सामग्री', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('चुने हुए पार्ट और लेसन की सामग्री'),
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Text(_lessonSummary(), style: const TextStyle(height: 1.5))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _asking ? null : _teachFullLesson,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('AI Teacher से पूरा लेसन सीखें'),
                ),
              ),
            ),
          ],
        )),
        Card(child: ListTile(
          leading: const Icon(Icons.quiz_outlined),
          title: const Text('अभ्यास टेस्ट', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('प्रगति: ${_completedQuizzes.length} / $totalLessons लेसन पूरे • $currentLessonStatus'),
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
), '');
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.length < 5) {
      throw Exception('टेस्ट में पर्याप्त सवाल नहीं मिले।');
    }
    final lessonId = (_topic + '_' + _part + '_' + _lesson)
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase();
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < decoded.length && i < 10; i++) {
      final item = decoded[i];
      if (item is! Map || item['question'] is! String ||
          item['options'] is! List || item['answer'] is! String) {
        throw Exception('टेस्ट का प्रारूप सही नहीं है।');
      }
      final options = (item['options'] as List).whereType<String>().toList();
      final answer = item['answer'] as String;
      if (options.length != 4 || options.toSet().length != 4 || !options.contains(answer)) {
        throw Exception('किसी सवाल के विकल्प या सही उत्तर में गलती है।');
      }
      result.add({
        'id': lessonId + '_ai_' + (i + 1).toString(),
        'q': item['question'] as String,
        'o': options,
        'a': options.indexOf(answer),
      });
    }
    return result;
  }

  Future<void> _runQuiz() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    List<Map<String, dynamic>> bank;
    if (_lessonQuizRows.containsKey(_lesson)) {
      bank = _questionsForLesson();
    } else {
      try {
        bank = await _generateQuizForLesson();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('इस लेसन का टेस्ट अभी तैयार नहीं हो पाया: $error')),
          );
        }
        return;
      }
    }
    if (!mounted || bank.isEmpty) return;
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
          title: Text('$_topic • $_part • $_lesson'),
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
    _completedQuizzes.add(_topic + '::' + _part + '::' + _lesson);
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

  Future<void> _teachFullLesson() async {
    _question.text = 'मुझे इस चुने हुए लेसन को बिल्कुल शुरुआत से विस्तार से पढ़ाइए। पहले सीखने के लक्ष्य बताइए, फिर सरल परिभाषाएँ और जरूरी शब्द समझाइए, हर अवधारणा को क्रमवार उदाहरणों के साथ सिखाइए, जहाँ लागू हो वहाँ हल किए हुए सवाल या व्यावहारिक चरण दिखाइए, आम गलतियाँ और उनसे बचने के तरीके बताइए, फिर आसान से कठिन अभ्यास दीजिए। अंत में 5 जाँच प्रश्न और एक छोटा गृहकार्य दीजिए। उत्तर इतना पूरा हो कि विद्यार्थी बिना दूसरी वेबसाइट खोले इस लेसन का अध्ययन कर सके।';
    await _askTeacher();
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
          'part': _part,
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
    final selectedPart = _selectedPart;
    final totalLessons = _courseParts.values.fold<int>(0, (total, parts) => total + parts.fold<int>(0, (count, part) => count + part.lessons.length));
    final currentLessonStatus = _completedQuizzes.contains(_topic + '::' + _part + '::' + _lesson)
        ? 'यह पाठ पूरा है' : 'यह पाठ बाकी है';
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
              onTap: () => setState(() { _topic = course.title; _part = _courseParts[course.title]!.first.title; _lesson = _courseParts[course.title]!.first.lessons.first; _answer = null; _error = null; }),
            ),
          );
        }),
        const SizedBox(height: 10),
        Text('अपना पार्ट चुनें', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _part,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'कोर्स का पार्ट',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: _selectedParts.map((part) => DropdownMenuItem(value: part.title, child: Text(part.title, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (value) => setState(() {
            if (value != null) {
              _part = value;
              _lesson = _selectedParts.firstWhere((part) => part.title == value).lessons.first;
              _answer = null; _error = null;
            }
          }),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _lesson,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'इस पार्ट का लेसन चुनें',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.menu_book_outlined),
          ),
          items: selectedPart.lessons.map((lesson) => DropdownMenuItem(value: lesson, child: Text(lesson, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (value) => setState(() { if (value != null) { _lesson = value; _answer = null; _error = null; } }),
        ),
        const SizedBox(height: 10),
        Card(child: ExpansionTile(
          leading: const Icon(Icons.menu_book_rounded),
          title: const Text('पाठ सामग्री', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('चुने हुए पार्ट और लेसन की सामग्री'),
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Text(_lessonSummary(), style: const TextStyle(height: 1.5))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _asking ? null : _teachFullLesson,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('AI Teacher से पूरा लेसन सीखें'),
                ),
              ),
            ),
          ],
        )),
        Card(child: ListTile(
          leading: const Icon(Icons.quiz_outlined),
          title: const Text('अभ्यास टेस्ट', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('प्रगति: ${_completedQuizzes.length} / $totalLessons लेसन पूरे • $currentLessonStatus'),
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
