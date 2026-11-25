import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ink=Color(0xFF25345B), _teal=Color(0xFF159B88), _gold=Color(0xFFF2B544);
const _vault=FlutterSecureStorage();
const _geminiModel='gemini-3.1-flash-lite-image';

class UtilityModulesPage extends StatelessWidget {
  const UtilityModulesPage({super.key});
  static const modules=[
    ('QR Code Tools','QR बनाएँ और स्कैन करें',Icons.qr_code_2,'qr'),
    ('Poster Maker','Gemini AI से पोस्टर बनाएँ',Icons.auto_awesome,'poster'),
    ('Reminders & Notes','काम और भुगतान की याद दिलाएँ',Icons.notifications_active_outlined,'reminders'),
    ('Smart Calculator','सामान्य कैलकुलेटर + GST',Icons.calculate_outlined,'calculator'),
    ('Payment Sound Box','पेमेंट API कनेक्शन',Icons.volume_up_outlined,'soundbox'),
    ('AI Calling Assistant','कॉल असिस्टेंट सेटअप',Icons.support_agent,'calling'),
  ];
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('दुकानदार के स्मार्ट टूल')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFDDE8FF),Color(0xFFEDE5FF),Color(0xFFDDF7EF)]),borderRadius:BorderRadius.circular(20)),child:const Row(children:[Icon(Icons.dashboard_customize_rounded,color:Color(0xFF536CC0),size:30),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Smart Tools',style:TextStyle(color:_ink,fontSize:20,fontWeight:FontWeight.w900)),Text('आपके कारोबार के लिए आसान डिजिटल टूल',style:TextStyle(color:Color(0xFF657295),fontSize:12))]))])),
      const SizedBox(height:16),
      Text('रोज़ के काम के लिए उपयोगी सुविधाएँ',style:TextStyle(color:_ink,fontSize:17,fontWeight:FontWeight.w800)),
      const SizedBox(height:12),
      GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:modules.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,mainAxisSpacing:12,crossAxisSpacing:12,childAspectRatio:1.12),itemBuilder:(context,i){
        final m=modules[i];
        final colors=[const Color(0xFFE7F0FF),const Color(0xFFFFE8F0),const Color(0xFFE6F8F1),const Color(0xFFFFF2D9),const Color(0xFFEDE9FF),const Color(0xFFE4F6FA)];
        return Material(color:Colors.white,elevation:3,shadowColor:const Color(0x20526FC4),borderRadius:BorderRadius.circular(20),child:InkWell(borderRadius:BorderRadius.circular(20),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>UtilityModulePage(kind:m.$4,title:m.$1))),child:Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Colors.white,Color.lerp(colors[i],Colors.white,.48)!]),borderRadius:BorderRadius.circular(20),border:Border.all(color:Color.lerp(colors[i],const Color(0xFF8498D8),.3)!)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:49,height:49,decoration:BoxDecoration(gradient:LinearGradient(colors:[colors[i],Color.lerp(colors[i],Colors.white,.2)!]),borderRadius:BorderRadius.circular(15)),child:Icon(m.$3,color:const Color(0xFF4E64AF),size:27)),const Spacer(),Text(m.$1,style:const TextStyle(color:_ink,fontWeight:FontWeight.w900,fontSize:14)),const SizedBox(height:4),Text(m.$2,style:const TextStyle(color:Color(0xFF78839C),fontSize:11))]))));
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
  TextField(controller:input,onChanged:(_)=>setState((){}),decoration:InputDecoration(labelText:mode=='upi'?'UPI ID (जैसे name@upi)':'Text या Website URL',hintText:mode=='upi'?'yourname@upi':'https://example.com')),
  const SizedBox(height:16),
  if(input.text.trim().isNotEmpty)Center(child:Container(color:Colors.white,padding:const EdgeInsets.all(14),child:QrImageView(data:mode=='upi'?'upi://pay?pa=${input.text.trim()}&pn=Bharat%20Saathi':input.text.trim(),size:220))),
  FilledButton(onPressed:()=>setState((){}),child:const Text('QR कोड बनाएँ')),
  OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>_QrScanner(onValue:(v){setState(()=>scanned=v);Navigator.pop(context);}))),icon:const Icon(Icons.qr_code_scanner),label:const Text('QR स्कैन करें')),
  if(scanned!=null)SelectableText('स्कैन परिणाम: $scanned'),
  if(input.text.trim().isNotEmpty)TextButton.icon(onPressed:()=>Share.share('QR content: ${mode=='upi'?'upi://pay?pa=${input.text.trim()}&pn=Bharat%20Saathi':input.text.trim()}'),icon:const Icon(Icons.share),label:const Text('कंटेंट शेयर करें')),
 ]);
}
class _QrScanner extends StatelessWidget{final ValueChanged<String> onValue;const _QrScanner({required this.onValue});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('QR स्कैन करें')),body:MobileScanner(onDetect:(capture){final value=(capture.barcodes.isNotEmpty?capture.barcodes.first.rawValue:null);if(value!=null&&value.isNotEmpty)onValue(value);}));}

class _PosterTool extends StatefulWidget{const _PosterTool();@override State<_PosterTool> createState()=>_PosterToolState();}
class _PosterToolState extends State<_PosterTool>{
 final shop=TextEditingController(),phone=TextEditingController(),brief=TextEditingController(text:'दुकान के लिए आकर्षक ऑफर पोस्टर');
 final keyInput=TextEditingController();
 final posterKey=GlobalKey();
 Uint8List? background;
 bool generating=false;
 String? error;
 @override void initState(){super.initState();_loadKey();}
 Future<void> _loadKey()async{keyInput.text=await _vault.read(key:'gemini_api_key')??'';if(mounted)setState((){});}
 @override void dispose(){shop.dispose();phone.dispose();brief.dispose();keyInput.dispose();super.dispose();}
 Future<void> _saveKey()async{
  final value=keyInput.text.trim();
  if(value.isEmpty){await _vault.delete(key:'gemini_api_key');}
  else{await _vault.write(key:'gemini_api_key',value:value);}
  if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Gemini API Key सुरक्षित रूप से सेव हो गई।')));
 }
 Future<void> _configureKey()async{
  await showDialog<void>(context:context,builder:(context)=>AlertDialog(
   title:const Text('Gemini API Key'),
   content:TextField(controller:keyInput,obscureText:true,decoration:const InputDecoration(labelText:'Google AI Studio API Key',hintText:'AIza...')),
   actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('रद्द करें')),FilledButton(onPressed:()async{await _saveKey();if(context.mounted)Navigator.pop(context);},child:const Text('सेव करें'))],
  ));
 }
 Future<void> _generate()async{
  final apiKey=await _vault.read(key:'gemini_api_key');
  if(apiKey==null||apiKey.isEmpty){await _configureKey();return;}
  if(shop.text.trim().isEmpty||phone.text.trim().isEmpty||brief.text.trim().isEmpty){
   setState(()=>error='दुकान का नाम, मोबाइल नंबर और पोस्टर का विषय भरें।');return;
  }
  setState((){generating=true;error=null;});
  try{
   final prompt='Create one beautiful, premium, colorful vertical 4:5 Indian small-business promotional poster BACKGROUND image. Do not draw any words, letters, numbers, logos, watermarks, QR codes or phone numbers. Leave a clean, high-contrast central area for text overlay. Theme based on this brief: ${brief.text.trim()}. Use professional Indian retail advertising art direction, rich gradients, attractive product/celebration motifs, crisp composition.';
   final uri=Uri.https('generativelanguage.googleapis.com','/v1beta/models/$_geminiModel:generateContent');
   final response=await http.post(uri,headers:{'Content-Type':'application/json','x-goog-api-key':apiKey},body:jsonEncode({
    'contents':[{'parts':[{'text':prompt}]}],
    'generationConfig':{'responseModalities':['IMAGE','TEXT'],'imageConfig':{'aspectRatio':'4:5','imageSize':'1K'}}
   })).timeout(const Duration(seconds:90));
   if(response.statusCode<200||response.statusCode>=300){
    final data=jsonDecode(response.body);
    final message=(data is Map&&data['error'] is Map)?data['error']['message']?.toString():'Gemini API request failed';
    throw Exception(message);
   }
   final data=jsonDecode(response.body) as Map<String,dynamic>;
   final candidates=data['candidates'] as List? ?? [];
   if(candidates.isEmpty)throw Exception('Gemini ने कोई इमेज नहीं लौटाई।');
   final parts=((candidates.first as Map)['content'] as Map)['parts'] as List? ?? [];
   String? encoded;
   for(final part in parts){
    if(part is Map&&part['inlineData'] is Map){encoded=(part['inlineData'] as Map)['data']?.toString();if(encoded!=null)break;}
   }
   if(encoded==null)throw Exception('Gemini response में image data नहीं मिला।');
   final bytes=base64Decode(encoded);
   if(!mounted)return;
   setState(()=>background=bytes);
  }catch(e){if(mounted)setState(()=>error='पोस्टर नहीं बन पाया: ${e.toString().replaceFirst('Exception: ','')}');}
  finally{if(mounted)setState(()=>generating=false);}
 }
 Future<void> _download()async{
  try{
   final boundary=posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
   if(boundary==null)throw Exception('पोस्टर प्रीव्यू तैयार नहीं है।');
   final ui.Image image=await boundary.toImage(pixelRatio:3);
   final data=await image.toByteData(format:ui.ImageByteFormat.png);
   if(data==null)throw Exception('इमेज सेव नहीं हो पाई।');
   final bytes=data.buffer.asUint8List();
   await Share.shareXFiles([XFile.fromData(bytes,mimeType:'image/png',name:'bharat-saathi-ai-poster.png')],text:'Bharat Saathi AI Poster');
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
 }
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
  Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF5938A8),Color(0xFFDB4B8C),Color(0xFFFF9B54)]),borderRadius:BorderRadius.circular(20)),child:const Row(children:[Icon(Icons.auto_awesome,color:Colors.white,size:30),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('AI Poster Studio',style:TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900)),Text('Gemini से अपना पोस्टर बनवाएँ',style:TextStyle(color:Colors.white70,fontSize:12))]))])),
  const SizedBox(height:14),
  TextField(controller:shop,decoration:const InputDecoration(labelText:'आपका नाम / दुकान का नाम',prefixIcon:Icon(Icons.storefront))),
  const SizedBox(height:10),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'मोबाइल नंबर',prefixIcon:Icon(Icons.phone_android))),
  const SizedBox(height:10),TextField(controller:brief,maxLines:3,decoration:const InputDecoration(labelText:'किस तरह का पोस्टर चाहिए?',hintText:'जैसे दिवाली ऑफर, किराना दुकान, सेल, नई शुरुआत')),
  const SizedBox(height:10),OutlinedButton.icon(onPressed:_configureKey,icon:const Icon(Icons.key),label:const Text('Gemini API Key सेट करें')),
  const SizedBox(height:12),FilledButton.icon(onPressed:generating?null:_generate,icon:generating?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.auto_awesome),label:Text(generating?'AI पोस्टर बना रहा है...':'AI से पोस्टर बनाएँ')),
  if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:const TextStyle(color:Colors.red))),
  if(background!=null)...[
   const SizedBox(height:18),const Text('आपका पोस्टर',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
   const SizedBox(height:10),
   RepaintBoundary(key:posterKey,child:AspectRatio(aspectRatio:4/5,child:ClipRRect(borderRadius:BorderRadius.circular(18),child:Stack(fit:StackFit.expand,children:[
    Image.memory(background!,fit:BoxFit.cover),
    DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black.withValues(alpha:.15),Colors.black.withValues(alpha:.70)]))),
    Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
     Text(shop.text,style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900,shadows:[Shadow(color:Colors.black54,blurRadius:8)]),textAlign:TextAlign.center),
     Text(brief.text,style:const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900,shadows:[Shadow(color:Colors.black54,blurRadius:8)]),textAlign:TextAlign.center),
     Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(30)),child:Text(phone.text,style:const TextStyle(color:_ink,fontSize:18,fontWeight:FontWeight.w900)))
    ]))
   ])))),
   const SizedBox(height:12),FilledButton.icon(onPressed:_download,icon:const Icon(Icons.download_rounded),label:const Text('पोस्टर डाउनलोड / शेयर करें'))
  ],
  const SizedBox(height:10),Text('नोट: Gemini API इस्तेमाल करने के लिए आपकी अपनी Google AI Studio API Key और इंटरनेट कनेक्शन जरूरी है। इमेज जनरेशन पर Google की दरों के अनुसार शुल्क लग सकता है।',style:TextStyle(color:Colors.blueGrey,fontSize:11))
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
  ...items.asMap().entries.map((e)=>Card(child:CheckboxListTile(value:e.value['done'] as bool,onChanged:(v)async{items[e.key]['done']=v??false;await _save();setState((){});},title:Text(e.value['title'].toString()),subtitle:Text(DateTime.parse(e.value['due'].toString()).toLocal().toString().split(' ').first),secondary:IconButton(onPressed:()async{items.removeAt(e.key);await _save();setState((){});},icon:const Icon(Icons.delete_outline))))),
 ]);
}

class _BusinessCalculator extends StatefulWidget{const _BusinessCalculator();@override State<_BusinessCalculator> createState()=>_BusinessCalculatorState();}
class _BusinessCalculatorState extends State<_BusinessCalculator>{
 String display='0',expression='';double? first;String? operator;bool fresh=true;
 void _digit(String value){setState((){if(fresh||display=='0'){display=value=='.'?'0.':value;fresh=false;}else if(value=='.'&&display.contains('.'))return;else{display+=value;}});}
 void _clear(){setState((){display='0';expression='';first=null;operator=null;fresh=true;});}
 void _choose(String op){final value=double.tryParse(display);if(value==null)return;setState((){first=value;operator=op;expression='$display $op';fresh=true;});}
 void _equals(){final second=double.tryParse(display);if(first==null||operator==null||second==null)return;double result;switch(operator){case '+':result=first!+second;break;case '−':result=first!-second;break;case '×':result=first!*second;break;case '÷':result=second==0?double.nan:first!/second;break;default:return;}setState((){expression='$expression $display =';display=result.isFinite?_fmt(result):'Error';first=null;operator=null;fresh=true;});}
 String _fmt(double v)=>v==v.roundToDouble()?v.toInt().toString():v.toStringAsFixed(8).replaceFirst(RegExp(r'0+$'),'').replaceFirst(RegExp(r'\.$'),'');
 void _delete(){setState((){if(display.length<=1){display='0';}else{display=display.substring(0,display.length-1);}});}
 void _percent(){final v=double.tryParse(display);if(v!=null)setState(()=>display=_fmt(v/100));}
 Future<void> _gst()async{
  final rate=await showModalBottomSheet<double>(context:context,showDragHandle:true,builder:(context)=>SafeArea(child:Padding(padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
   const Text('GST कैलकुलेशन',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),const SizedBox(height:12),
   Wrap(spacing:8,runSpacing:8,children:[for(final r in [5,12,18,28])OutlinedButton(onPressed:()=>Navigator.pop(context,r.toDouble()),child:Text('$r%'))]),
   const SizedBox(height:8),const Text('राशि पर GST जोड़ने के लिए दर चुनें। GST हटाने का विकल्प अगली स्क्रीन पर मिलेगा।',style:TextStyle(color:Colors.blueGrey,fontSize:12))
  ]))));
  if(rate==null)return;
  if(!mounted)return;
  final remove=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:Text('GST $rate%'),content:const Text('GST जोड़ना है या पहले से शामिल GST हटाना है?'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('GST जोड़ें')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('GST हटाएँ'))]));
  if(remove==null)return;
  final amount=double.tryParse(display);if(amount==null)return;
  final result=remove?amount/(1+rate/100):amount*(1+rate/100);
  setState((){expression=remove?'GST $rate% हटाया':'GST $rate% जोड़ा';display=_fmt(result);fresh=true;first=null;operator=null;});
 }
 Widget _key(String label,{Color? color,Color? textColor,VoidCallback? onTap,bool wide=false}){
  return Expanded(flex:wide?2:1,child:Padding(padding:const EdgeInsets.all(5),child:Material(color:color??const Color(0xFF202B45),borderRadius:BorderRadius.circular(18),child:InkWell(borderRadius:BorderRadius.circular(18),onTap:onTap,child:Container(height:64,alignment:Alignment.center,child:Text(label,style:TextStyle(color:textColor??Colors.white,fontSize:label.length>3?17:23,fontWeight:FontWeight.w800)))))));
 }
 @override Widget build(BuildContext context){
  final rows=<Widget>[
   Row(children:[_key('AC',color:const Color(0xFFFFD6DE),textColor:const Color(0xFF9C2945),onTap:_clear),_key('DEL',color:const Color(0xFFFFE6CC),textColor:const Color(0xFF9A5014),onTap:_delete),_key('%',color:const Color(0xFFE8E2FF),textColor:const Color(0xFF5938A8),onTap:_percent),_key('÷',color:const Color(0xFF7657D6),onTap:()=>_choose('÷'))]),
   Row(children:[_key('7',onTap:()=>_digit('7')),_key('8',onTap:()=>_digit('8')),_key('9',onTap:()=>_digit('9')),_key('×',color:const Color(0xFF7657D6),onTap:()=>_choose('×'))]),
   Row(children:[_key('4',onTap:()=>_digit('4')),_key('5',onTap:()=>_digit('5')),_key('6',onTap:()=>_digit('6')),_key('−',color:const Color(0xFF7657D6),onTap:()=>_choose('−'))]),
   Row(children:[_key('1',onTap:()=>_digit('1')),_key('2',onTap:()=>_digit('2')),_key('3',onTap:()=>_digit('3')),_key('+',color:const Color(0xFF7657D6),onTap:()=>_choose('+'))]),
   Row(children:[_key('GST',color:const Color(0xFFFFD166),textColor:const Color(0xFF5B3B00),onTap:_gst),_key('0',onTap:()=>_digit('0')),_key('.',onTap:()=>_digit('.')),_key('=',color:const Color(0xFF12A89A),onTap:_equals)]),
  ];
  return Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF101A32),Color(0xFF253B66),Color(0xFF4B397E)])),child:SafeArea(child:Column(children:[
   Padding(padding:const EdgeInsets.fromLTRB(18,22,18,14),child:Row(children:[const Icon(Icons.calculate_rounded,color:Color(0xFFFFD166),size:26),const SizedBox(width:9),const Text('कैलकुलेटर',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),const Spacer(),Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.12),borderRadius:BorderRadius.circular(20)),child:const Text('GST Ready',style:TextStyle(color:Color(0xFFFFD166),fontWeight:FontWeight.w800,fontSize:11)))])),
   Expanded(child:Container(width:double.infinity,margin:const EdgeInsets.fromLTRB(14,6,14,14),padding:const EdgeInsets.fromLTRB(20,18,20,20),decoration:BoxDecoration(color:const Color(0xFF0B1327).withValues(alpha:.82),borderRadius:BorderRadius.circular(26),border:Border.all(color:Colors.white.withValues(alpha:.12))),child:Column(mainAxisAlignment:MainAxisAlignment.end,crossAxisAlignment:CrossAxisAlignment.end,children:[Text(expression,style:const TextStyle(color:Colors.white54,fontSize:16),maxLines:1),const SizedBox(height:12),FittedBox(fit:BoxFit.scaleDown,child:Text(display,style:const TextStyle(color:Colors.white,fontSize:48,fontWeight:FontWeight.w900)))]))),
   Padding(padding:const EdgeInsets.fromLTRB(10,0,10,14),child:Column(children:rows))
  ])));
 }
}

class _SoundboxInfo extends StatefulWidget{const _SoundboxInfo();@override State<_SoundboxInfo> createState()=>_SoundboxInfoState();}
class _SoundboxInfoState extends State<_SoundboxInfo>{
 final endpoint=TextEditingController(),token=TextEditingController();
 bool loading=true,testing=false,connected=false,obscure=true;
 String status='API अभी कनेक्ट नहीं है।';
 @override void initState(){super.initState();_load();}
 @override void dispose(){endpoint.dispose();token.dispose();super.dispose();}
 Future<void> _load()async{endpoint.text=await _vault.read(key:'soundbox_api_url')??'';token.text=await _vault.read(key:'soundbox_api_token')??'';if(mounted)setState(()=>loading=false);}
 Future<void> _save()async{await _vault.write(key:'soundbox_api_url',value:endpoint.text.trim());await _vault.write(key:'soundbox_api_token',value:token.text.trim());if(mounted)setState(()=>status='API सेटिंग सेव हो गई। अब कनेक्शन टेस्ट करें।');}
 Future<void> _disconnect()async{await _vault.delete(key:'soundbox_api_url');await _vault.delete(key:'soundbox_api_token');endpoint.clear();token.clear();if(mounted)setState((){connected=false;status='API डिस्कनेक्ट कर दी गई है।';});}
 Future<void> _test()async{
  final uri=Uri.tryParse(endpoint.text.trim());
  if(uri==null||!uri.hasScheme||!uri.hasAuthority){setState(()=>status='सही HTTPS API URL दर्ज करें।');return;}
  setState((){testing=true;status='API कनेक्शन जाँचा जा रहा है...';});
  try{
   final headers=<String,String>{'Accept':'application/json'};
   if(token.text.trim().isNotEmpty)headers['Authorization']='Bearer ${token.text.trim()}';
   final response=await http.get(uri,headers:headers).timeout(const Duration(seconds:20));
   if(response.statusCode>=200&&response.statusCode<300){connected=true;status='API endpoint से सफल response मिला (HTTP ${response.statusCode})। Payment feed की पुष्टि अलग से करनी होगी.';}
   else{connected=false;status='API ने HTTP ${response.statusCode} लौटाया। URL, token या provider का सही endpoint जाँचें.';}
  }catch(e){connected=false;status='कनेक्शन नहीं हुआ: $e';}
  if(mounted)setState(()=>testing=false);
 }
 @override Widget build(BuildContext context)=>loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(18),children:[
  Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF0F766E),Color(0xFF2457A6)]),borderRadius:BorderRadius.circular(20)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.volume_up_rounded,color:Colors.white,size:34),SizedBox(height:10),Text('Payment Sound Box',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),Text('अपने payment provider का API endpoint जोड़ें',style:TextStyle(color:Colors.white70,fontSize:12))])),
  const SizedBox(height:16),TextField(controller:endpoint,keyboardType:TextInputType.url,decoration:const InputDecoration(labelText:'API Endpoint URL',hintText:'https://api.example.com/payments')),
  const SizedBox(height:10),TextField(controller:token,obscureText:obscure,decoration:InputDecoration(labelText:'API Token / Secret (वैकल्पिक)',suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility:Icons.visibility_off)))),
  const SizedBox(height:14),OutlinedButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('API सेटिंग सेव करें')),
  const SizedBox(height:8),FilledButton.icon(onPressed:testing?null:_test,icon:testing?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.link),label:Text(testing?'कनेक्शन जाँच रहे हैं...':'API Connect / Test Connection')),
  TextButton.icon(onPressed:_disconnect,icon:const Icon(Icons.link_off),label:const Text('Disconnect / API हटाएँ')),
  const SizedBox(height:14),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:connected?const Color(0xFFE5F7EF):const Color(0xFFFFF4DF),borderRadius:BorderRadius.circular(14)),child:Row(children:[Icon(connected?Icons.check_circle:Icons.info_outline,color:connected?Colors.green:Colors.orange),const SizedBox(width:10),Expanded(child:Text(status,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)))])),
  const SizedBox(height:12),const Text('ध्यान दें: यह endpoint और token को सेव करके API की पहुँच जाँचता है। असली पेमेंट की आवाज़ तभी चलेगी जब आपके payment provider का webhook/event format और verified payment callback जोड़ा जाएगा। केवल HTTP response को भुगतान की पुष्टि नहीं माना जाएगा।',style:TextStyle(color:Colors.blueGrey,fontSize:11))
 ]);
}
class _CallingInfo extends StatelessWidget{const _CallingInfo();@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:const [
 Icon(Icons.support_agent,size:64,color:_teal),SizedBox(height:12),
 Text('AI Calling Assistant',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:_ink)),
 Text('इस सुविधा को बाकी मॉड्यूल के बाद सक्रिय किया जाएगा। इसके लिए Android Default Dialer role, conditional call forwarding, सुरक्षित telephony provider और AI voice backend की ज़रूरत होगी।'),
 SizedBox(height:12),ListTile(leading:Icon(Icons.phone_android),title:Text('SIM और कॉल अनुमति'),subtitle:Text('किसी कॉल को अपने आप forward या answer नहीं किया जाएगा।')),
 ListTile(leading:Icon(Icons.privacy_tip_outlined),title:Text('Privacy first'),subtitle:Text('कॉलर को AI assistant से बात होने की जानकारी और रिकॉर्डिंग/डेटा नीति स्पष्ट होनी चाहिए.')),
 Chip(label:Text('IMPLEMENTATION LAST — NOT ACTIVE'))
]);}
