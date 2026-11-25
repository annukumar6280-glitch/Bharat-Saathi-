import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ink=Color(0xFF14233B), _teal=Color(0xFF168C86), _gold=Color(0xFFF2A93B);

class UtilityModulesPage extends StatelessWidget {
  const UtilityModulesPage({super.key});
  static const modules=[
    ('QR Code Tools','QR बनाएँ और स्कैन करें',Icons.qr_code_2,'qr'),
    ('Poster Maker','ऑफर और त्योहार के पोस्टर',Icons.palette_outlined,'poster'),
    ('Reminders & Notes','काम और भुगतान की याद दिलाएँ',Icons.notifications_active_outlined,'reminders'),
    ('Smart Calculator','GST, छूट और मुनाफा',Icons.calculate_outlined,'calculator'),
    ('Payment Sound Box','पेमेंट सूचना सेटअप',Icons.volume_up_outlined,'soundbox'),
    ('AI Calling Assistant','कॉल असिस्टेंट सेटअप',Icons.support_agent,'calling'),
  ];
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('दुकानदार के स्मार्ट टूल')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Text('रोज़ के काम के लिए उपयोगी सुविधाएँ',style:TextStyle(color:_ink,fontSize:17,fontWeight:FontWeight.w800)),
      const SizedBox(height:12),
      GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:modules.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,mainAxisSpacing:12,crossAxisSpacing:12,childAspectRatio:1.12),itemBuilder:(context,i){
        final m=modules[i];
        return Material(color:Colors.white,borderRadius:BorderRadius.circular(18),child:InkWell(borderRadius:BorderRadius.circular(18),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>UtilityModulePage(kind:m.$4,title:m.$1))),child:Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFE1E7F0))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:48,height:48,decoration:BoxDecoration(color:const Color(0xFFEAF1FA),borderRadius:BorderRadius.circular(14)),child:Icon(m.$3,color:_ink,size:27)),const Spacer(),Text(m.$1,style:const TextStyle(color:_ink,fontWeight:FontWeight.w800,fontSize:14)),const SizedBox(height:4),Text(m.$2,style:const TextStyle(color:Colors.blueGrey,fontSize:11))]))));
      })
    ])
  );
}

class UtilityModulePage extends StatelessWidget {
  final String kind,title;
  const UtilityModulePage({super.key,required this.kind,required this.title});
  @override Widget build(BuildContext context){
    final Widget page=switch(kind){
      'qr'=>const _QrTool(),
      'poster'=>const _PosterTool(),
      'reminders'=>const _ReminderTool(),
      'calculator'=>const _BusinessCalculator(),
      'soundbox'=>const _SoundboxInfo(),
      _=>const _CallingInfo(),
    };
    return Scaffold(appBar:AppBar(title:Text(title)),body:page);
  }
}

class _QrTool extends StatefulWidget{const _QrTool();@override State<_QrTool> createState()=>_QrToolState();}
class _QrToolState extends State<_QrTool>{
 final input=TextEditingController();String mode='text';String? scanned;
 @override void dispose(){input.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
  SegmentedButton<String>(segments:const [ButtonSegment(value:'text',label:Text('Text / Link')),ButtonSegment(value:'upi',label:Text('UPI QR'))],selected:{mode},onSelectionChanged:(s)=>setState(()=>mode=s.first)),
  const SizedBox(height:14),
  TextField(controller:input,decoration:InputDecoration(labelText:mode=='upi'?'UPI ID (जैसे name@upi)':'Text या Website URL',hintText:mode=='upi'?'yourname@upi':'https://example.com')),
  const SizedBox(height:16),
  if(input.text.trim().isNotEmpty)Center(child:Container(color:Colors.white,padding:const EdgeInsets.all(14),child:QrImageView(data:mode=='upi'?'upi://pay?pa=${input.text.trim()}&pn=Bharat%20Saathi':input.text.trim(),size:220))),
  FilledButton(onPressed:()=>setState((){}),child:const Text('QR कोड बनाएँ')),
  OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>_QrScanner(onValue:(v){setState(()=>scanned=v);Navigator.pop(context);}))),icon:const Icon(Icons.qr_code_scanner),label:const Text('QR स्कैन करें')),
  if(scanned!=null)SelectableText('स्कैन परिणाम: $scanned'),
  if(input.text.trim().isNotEmpty)TextButton.icon(onPressed:()=>Share.share('QR content: ${mode=='upi'?'upi://pay?pa=${input.text.trim()}&pn=Bharat%20Saathi':input.text.trim()}'),icon:const Icon(Icons.share),label:const Text('कंटेंट शेयर करें')),
 ]);
}
class _QrScanner extends StatelessWidget{final ValueChanged<String> onValue;const _QrScanner({required this.onValue});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('QR स्कैन करें')),body:MobileScanner(onDetect:(capture){final value=capture.barcodes.firstOrNull?.rawValue;if(value!=null&&value.isNotEmpty)onValue(value);}));}

class _PosterTool extends StatefulWidget{const _PosterTool();@override State<_PosterTool> createState()=>_PosterToolState();}
class _PosterToolState extends State<_PosterTool>{
 final shop=TextEditingController(),headline=TextEditingController(text:'आज की खास ऑफर'),offer=TextEditingController(text:'खरीदारी पर विशेष छूट'),phone=TextEditingController();
 @override void dispose(){shop.dispose();headline.dispose();offer.dispose();phone.dispose();super.dispose();}
 Future<void> export()async{final doc=pw.Document();doc.addPage(pw.Page(build:(_)=>pw.Container(color:const PdfColor.fromInt(0xFF14233B),padding:const pw.EdgeInsets.all(28),child:pw.Center(child:pw.Column(mainAxisAlignment:pw.MainAxisAlignment.center,children:[pw.Text(shop.text.isEmpty?'आपकी दुकान':shop.text,style:pw.TextStyle(color:const PdfColor.fromInt(0xFFFFD58A),fontSize:25,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:32),pw.Text(headline.text,style:pw.TextStyle(color:PdfColors.white,fontSize:32,fontWeight:pw.FontWeight.bold),textAlign:pw.TextAlign.center),pw.SizedBox(height:20),pw.Text(offer.text,style:const pw.TextStyle(color:PdfColors.white,fontSize:20),textAlign:pw.TextAlign.center),pw.SizedBox(height:35),pw.Text(phone.text,style:const pw.TextStyle(color:PdfColors.white,fontSize:16))]))));await Printing.sharePdf(bytes:await doc.save(),filename:'bharat_saathi_poster.pdf');}
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
  TextField(controller:shop,decoration:const InputDecoration(labelText:'दुकान का नाम')),
  const SizedBox(height:10),TextField(controller:headline,decoration:const InputDecoration(labelText:'पोस्टर हेडलाइन')),
  const SizedBox(height:10),TextField(controller:offer,maxLines:3,decoration:const InputDecoration(labelText:'ऑफर / संदेश')),
  const SizedBox(height:10),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'मोबाइल नंबर (वैकल्पिक)')),
  const SizedBox(height:16),
  Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:_ink,borderRadius:BorderRadius.circular(18)),child:Column(children:[Text(shop.text.isEmpty?'आपकी दुकान':shop.text,style:const TextStyle(color:_gold,fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:24),Text(headline.text,style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900),textAlign:TextAlign.center),const SizedBox(height:12),Text(offer.text,style:const TextStyle(color:Colors.white,fontSize:17),textAlign:TextAlign.center),const SizedBox(height:18),Text(phone.text,style:const TextStyle(color:Colors.white70))])),
  const SizedBox(height:14),OutlinedButton(onPressed:()=>setState((){}),child:const Text('Preview अपडेट करें')),FilledButton.icon(onPressed:export,icon:const Icon(Icons.picture_as_pdf),label:const Text('PDF पोस्टर शेयर करें'))
 ]);
}

class _ReminderTool extends StatefulWidget{const _ReminderTool();@override State<_ReminderTool> createState()=>_ReminderToolState();}
class _ReminderToolState extends State<_ReminderTool>{
 final title=TextEditingController();List<Map<String,dynamic>> items=[];DateTime due=DateTime.now().add(const Duration(days:1));bool loading=true;
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{final p=await SharedPreferences.getInstance();final raw=p.getString('bs_reminders_v1');if(raw!=null){try{items=List<Map<String,dynamic>>.from(jsonDecode(raw));}catch(_){}}if(mounted)setState(()=>loading=false);}
 Future<void> _save()async{final p=await SharedPreferences.getInstance();await p.setString('bs_reminders_v1',jsonEncode(items));}
 Future<void> _add()async{if(title.text.trim().isEmpty)return;items.insert(0,{'title':title.text.trim(),'due':due.toIso8601String(),'done':false});title.clear();await _save();if(mounted)setState((){});}
 @override Widget build(BuildContext context)=>loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
  TextField(controller:title,decoration:const InputDecoration(labelText:'काम / भुगतान की याद')),
  const SizedBox(height:8),OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:context,initialDate:due,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:3650)));if(d!=null)setState(()=>due=d);},icon:const Icon(Icons.calendar_month),label:Text('तारीख: ${due.day}-${due.month}-${due.year}')),
  FilledButton(onPressed:_add,child:const Text('याद सेव करें')),
  const Divider(height:28),
  if(items.isEmpty)const Text('अभी कोई रिमाइंडर नहीं है।'),
  ...items.asMap().entries.map((e)=>Card(child:CheckboxListTile(value:e.value['done'] as bool, onChanged:(v)async{items[e.key]['done']=v??false;await _save();setState((){});},title:Text(e.value['title'].toString()),subtitle:Text(DateTime.parse(e.value['due'].toString()).toLocal().toString().split(' ').first),secondary:IconButton(onPressed:()async{items.removeAt(e.key);await _save();setState((){});},icon:const Icon(Icons.delete_outline))))),
 ]);
}

class _BusinessCalculator extends StatefulWidget{const _BusinessCalculator();@override State<_BusinessCalculator> createState()=>_BusinessCalculatorState();}
class _BusinessCalculatorState extends State<_BusinessCalculator>{
 final a=TextEditingController(),b=TextEditingController(),gst=TextEditingController(text:'18'),discount=TextEditingController(text:'0');String result='0.00';
 double n(TextEditingController c)=>double.tryParse(c.text.trim())??0;
 void calc(String type){final x=n(a),y=n(b),g=n(gst),d=n(discount);double v=0;switch(type){case 'add':v=x+y;break;case 'sub':v=x-y;break;case 'mul':v=x*y;break;case 'div':v=y==0?double.nan:x/y;break;case 'gst':v=x+(x*g/100);break;case 'discount':v=x-(x*d/100);break;case 'profit':v=y==0?double.nan:((x-y)/y)*100;break;}setState(()=>result=v.isFinite?v.toStringAsFixed(2):'मान्य संख्या दर्ज करें');}
 @override void dispose(){a.dispose();b.dispose();gst.dispose();discount.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
  Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:_ink,borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('RESULT',style:TextStyle(color:Colors.white70)),const SizedBox(height:8),Text(result,style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w900))])),
  const SizedBox(height:14),TextField(controller:a,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'पहली राशि / बिक्री मूल्य')),const SizedBox(height:8),TextField(controller:b,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'दूसरी राशि / खरीद मूल्य')),
  const SizedBox(height:8),TextField(controller:gst,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'GST %')),const SizedBox(height:8),TextField(controller:discount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'छूट %')),
  const SizedBox(height:14),Wrap(spacing:8,runSpacing:8,children:[('जोड़ें','add'),('घटाएँ','sub'),('गुणा','mul'),('भाग','div'),('GST सहित','gst'),('छूट के बाद','discount'),('मुनाफा %','profit')].map((e)=>OutlinedButton(onPressed:()=>calc(e.$2),child:Text(e.$1))).toList())
 ]);
}

class _SoundboxInfo extends StatefulWidget{const _SoundboxInfo();@override State<_SoundboxInfo> createState()=>_SoundboxInfoState();}
class _SoundboxInfoState extends State<_SoundboxInfo>{
 bool permission=false;
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
  const Icon(Icons.volume_up_rounded,size:64,color:_teal),const SizedBox(height:12),
  const Text('भुगतान की सही पुष्टि ज़रूरी है',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:_ink)),
  const SizedBox(height:8),const Text('यह ऐप अभी किसी UPI ऐप या बैंक से verified payment feed से जुड़ा नहीं है। इसलिए यह नकली “पेमेंट प्राप्त हुआ” आवाज़ नहीं चलाएगा। SMS या स्क्रीन नोटिफिकेशन अकेले बैंक-स्तर की पुष्टि नहीं होते।'),
  const SizedBox(height:14),const ListTile(leading:Icon(Icons.verified_user_outlined),title:Text('Verified bank / payment partner integration'),subtitle:Text('सर्वर से सत्यापित भुगतान मिलने के बाद ही रकम की घोषणा सक्षम होगी।')),
  const ListTile(leading:Icon(Icons.notifications_active_outlined),title:Text('Notification access'),subtitle:Text('भविष्य में supported notification reading जोड़ी जा सकती है, लेकिन उसे verified payment नहीं माना जाएगा।')),
  const Chip(label:Text('LIVE PAYMENT ANNOUNCEMENTS: NOT CONNECTED'))
 ]);
}
class _CallingInfo extends StatelessWidget{const _CallingInfo();@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
 const Icon(Icons.support_agent,size:64,color:_teal),const SizedBox(height:12),
 const Text('AI Calling Assistant',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:_ink)),
 const Text('इस सुविधा को बाकी मॉड्यूल के बाद सक्रिय किया जाएगा। इसके लिए Android Default Dialer role, conditional call forwarding, सुरक्षित telephony provider और AI voice backend की ज़रूरत होगी।'),
 const SizedBox(height:12),const ListTile(leading:Icon(Icons.phone_android),title:Text('SIM और कॉल अनुमति'),subtitle:Text('किसी कॉल को अपने आप forward या answer नहीं किया जाएगा।')),
 const ListTile(leading:Icon(Icons.privacy_tip_outlined),title:Text('Privacy first'),subtitle:Text('कॉलर को AI assistant से बात होने की जानकारी और रिकॉर्डिंग/डेटा नीति स्पष्ट होनी चाहिए।')),
 const Chip(label:Text('IMPLEMENTATION LAST — NOT ACTIVE'))
]);}
