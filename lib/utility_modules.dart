import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ink=Color(0xFF25345B), _teal=Color(0xFF159B88);
const _vault=FlutterSecureStorage();

class UtilityModulesPage extends StatelessWidget {
  const UtilityModulesPage({super.key});
  static const modules=[
    ('QR Code Tools','QR बनाएँ और स्कैन करें',Icons.qr_code_2,'qr'),
    ('Poster Maker','FLUX AI से फोटो और पोस्टर बनाएँ',Icons.auto_awesome,'poster'),
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
 final shop=TextEditingController(),phone=TextEditingController(),brief=TextEditingController();
 final posterKey=GlobalKey();
 final picker=ImagePicker();
 Uint8List? referenceImage,generatedImage,generatedVideo;
 VideoPlayerController? videoController;
 String imageMime='image/jpeg',creativeMode='creative',generationType='image';
 bool generating=false;
 String? error,usageMessage;
 @override void dispose(){shop.dispose();phone.dispose();brief.dispose();videoController?.dispose();super.dispose();}
 Future<void> _pickImage()async{
  final file=await picker.pickImage(source:ImageSource.gallery,imageQuality:88,maxWidth:1800,maxHeight:1800);
  if(file==null)return;
  final bytes=await file.readAsBytes();
  if(!mounted)return;
  setState((){referenceImage=bytes;imageMime=file.mimeType??'image/jpeg';error=null;});
 }
 Future<void> _generate()async{
  if(brief.text.trim().isEmpty){setState(()=>error=generationType=='video'?'बताएँ कि किस तरह का वीडियो बनाना है।':'बताएँ कि किस तरह की इमेज बनानी है।');return;}
  if(generationType=='video'){
   final confirm=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
    title:const Text('AI वीडियो जनरेशन'),
    content:const Text('सफल वीडियो जनरेशन पर 50 Bharat Saathi कॉइन खर्च होंगे। fal.ai API की अलग provider billing भी लागू हो सकती है। क्या आप आगे बढ़ना चाहते हैं?'),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('रद्द करें')),
     FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('50 कॉइन के साथ बनाएँ')),
    ],
   ));
   if(confirm!=true||!mounted)return;
  }
  setState((){generating=true;error=null;generatedImage=null;generatedVideo=null;usageMessage=null;});
  await videoController?.dispose();
  videoController=null;
  try{
   final prompt=generationType=='video'
    ? 'Create a polished short vertical 9:16 video with natural synchronized audio. Scene and motion brief: ${brief.text.trim()}. Use cinematic camera movement, coherent motion, professional lighting and a clean composition. If a reference image is supplied, use it as the visual starting reference. Do not add watermarks, fake text, prices or contact details.'
    : creativeMode=='shop'
     ? 'Create a premium, polished Indian business advertising design. Business/shop name: ${shop.text.trim()}. Contact number: ${phone.text.trim()}. Design brief: ${brief.text.trim()}. Make it suitable for a shop, service, product promotion or offer. Compose a visually striking vertical 4:5 poster. Render any short requested text legibly; do not invent phone numbers or prices.'
     : 'Create an original high-quality creative image based on this brief: ${brief.text.trim()}. This is general-purpose creative work, not necessarily a shop advertisement. It may be a personal portrait concept, birthday or wedding design, festival greeting, social media creative, wallpaper, illustration, artwork or any other safe creative idea. Use a polished professional composition and vertical 4:5 format.';
   final response=await Supabase.instance.client.functions.invoke(
    'ai-creative-studio',
    body:{
     'generationType':generationType,
     'mode':creativeMode,
     'prompt':prompt,
     'imageBase64':referenceImage==null?null:base64Encode(referenceImage!),
     'imageMimeType':referenceImage==null?null:imageMime,
    },
   );
   final data=response.data;
   if(data is! Map)throw Exception('AI सर्वर से सही response नहीं मिला।');
   if(data['error']!=null)throw Exception(data['error'].toString());
   if(generationType=='video'){
    final encoded=data['videoBase64']?.toString();
    if(encoded==null||encoded.isEmpty)throw Exception('AI ने वीडियो डेटा नहीं लौटाया।');
    final bytes=base64Decode(encoded);
    final directory=await getTemporaryDirectory();
    final file=File('${directory.path}/bharat-saathi-ai-video.mp4');
    await file.writeAsBytes(bytes,flush:true);
    final controller=VideoPlayerController.file(file);
    await controller.initialize();
    await controller.setLooping(true);
    if(!mounted){await controller.dispose();return;}
    setState(()=>videoController=controller);
    await controller.play();
   }else{
    final encoded=data['imageBase64']?.toString();
    if(encoded==null||encoded.isEmpty)throw Exception('AI ने इमेज डेटा नहीं लौटाया।');
    if(!mounted)return;
    setState(()=>generatedImage=base64Decode(encoded));
   }
   if(mounted){
    final remaining=data['freeRemaining'];
    final coinCost=data['coinCost'];
    final coinBalance=data['coinBalance'];
    final usage=coinCost is num && coinCost>0
      ? 'इस जनरेशन में ${coinCost.toInt()} कॉइन इस्तेमाल हुए। बाकी कॉइन: ${coinBalance is num?coinBalance.toInt():0}.'
      : 'इस महीने के फ्री जनरेशन बाकी: ${remaining is num?remaining.toInt():0}';
    setState(()=>usageMessage=usage);
   }
  }catch(e){
   if(mounted)setState(()=>error='जनरेशन नहीं हो पाया: ${e.toString().replaceFirst('Exception: ','')}');
  }finally{if(mounted)setState(()=>generating=false);}
 }
 Future<void> _download()async{
  try{
   if(generatedVideo!=null){
    await Share.shareXFiles([XFile.fromData(generatedVideo!,mimeType:'video/mp4',name:'bharat-saathi-ai-video.mp4')],text:'Bharat Saathi AI Video');
    return;
   }
   final boundary=posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
   if(boundary==null)throw Exception('प्रीव्यू तैयार नहीं है।');
   final image=await boundary.toImage(pixelRatio:3);
   final data=await image.toByteData(format:ui.ImageByteFormat.png);
   if(data==null)throw Exception('इमेज सेव नहीं हो पाई।');
   await Share.shareXFiles([XFile.fromData(data.buffer.asUint8List(),mimeType:'image/png',name:'bharat-saathi-ai-creative.png')],text:'Bharat Saathi AI Creative Studio');
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
 }
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
  Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF4338CA),Color(0xFF9333EA),Color(0xFFEC4899)]),borderRadius:BorderRadius.circular(22)),child:const Row(children:[Icon(Icons.auto_awesome,color:Colors.white,size:32),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('AI Creative Studio',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),Text('AI से फोटो और पोस्टर बनाएँ',style:TextStyle(color:Colors.white70,fontSize:12))]))])),
  const SizedBox(height:16),
  SegmentedButton<String>(segments:const [ButtonSegment(value:'creative',label:Text('अपनी पसंद का')),ButtonSegment(value:'shop',label:Text('दुकान / बिजनेस'))],selected:{creativeMode},onSelectionChanged:(v)=>setState(()=>creativeMode=v.first)),
  const SizedBox(height:12),
  if(creativeMode=='shop')...[
   const SizedBox(height:10),TextField(controller:shop,decoration:const InputDecoration(labelText:'दुकान / बिजनेस का नाम (वैकल्पिक)',prefixIcon:Icon(Icons.storefront))),
   const SizedBox(height:10),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'पोस्टर पर मोबाइल नंबर (वैकल्पिक)',prefixIcon:Icon(Icons.phone))),
  ],
  const SizedBox(height:10),
  TextField(controller:brief,maxLines:4,decoration:InputDecoration(labelText:generationType=='video'?'किस तरह का वीडियो चाहिए?':'किस तरह की फोटो / डिजाइन चाहिए?',hintText:creativeMode=='shop'?'जैसे दिवाली ऑफर, प्रोडक्ट विज्ञापन, दुकान का बैनर...':'जैसे जन्मदिन, शादी, त्योहार, फोटो एडिट, वॉलपेपर, सोशल मीडिया आर्ट...')),
  const SizedBox(height:10),
  OutlinedButton.icon(onPressed:generating?null:_pickImage,icon:const Icon(Icons.add_photo_alternate_outlined),label:Text(referenceImage==null?'अपनी फोटो जोड़ें (वैकल्पिक)':'फोटो चुनी गई — बदलने के लिए टैप करें')),
  if(referenceImage!=null)Padding(padding:const EdgeInsets.only(top:8),child:ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.memory(referenceImage!,height:130,fit:BoxFit.contain))),
  const SizedBox(height:12),
  FilledButton.icon(onPressed:generating?null:_generate,icon:generating?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.auto_awesome),label:Text(generating?'AI तैयार कर रहा है...':generationType=='video'?'AI वीडियो बनाएँ':'AI फोटो / पोस्टर बनाएँ')),
  if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:const TextStyle(color:Colors.red,fontSize:12))),
  if(usageMessage!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(usageMessage!,style:const TextStyle(color:Color(0xFF0F8A69),fontWeight:FontWeight.w700))),
  if(videoController!=null&&videoController!.value.isInitialized)...[
   const SizedBox(height:18),const Text('आपका AI वीडियो',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
   const SizedBox(height:10),
   ClipRRect(borderRadius:BorderRadius.circular(18),child:AspectRatio(aspectRatio:videoController!.value.aspectRatio,child:VideoPlayer(videoController!))),
   Row(mainAxisAlignment:MainAxisAlignment.center,children:[IconButton(onPressed:()=>setState(()=>videoController!.value.isPlaying?videoController!.pause():videoController!.play()),icon:Icon(videoController!.value.isPlaying?Icons.pause_circle:Icons.play_circle,size:34)),const SizedBox(width:8),const Text('वीडियो चलाएँ / रोकें')]),
   FilledButton.icon(onPressed:_download,icon:const Icon(Icons.download_rounded),label:const Text('वीडियो डाउनलोड / शेयर करें')),
  ],
  if(generatedImage!=null)...[
   const SizedBox(height:18),const Text('आपका AI क्रिएशन',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
   const SizedBox(height:10),
   RepaintBoundary(key:posterKey,child:ClipRRect(borderRadius:BorderRadius.circular(18),child:Image.memory(generatedImage!,fit:BoxFit.contain))),
   const SizedBox(height:12),FilledButton.icon(onPressed:_download,icon:const Icon(Icons.download_rounded),label:const Text('डाउनलोड / शेयर करें')),
  ],
  const SizedBox(height:12),
  const Text('आप अपनी फोटो से नया डिजाइन या एडिट बनवा सकते हैं। सामान्य क्रिएटिव डिजाइन के लिए दुकान का नाम या मोबाइल नंबर देना जरूरी नहीं है। AI सेवा की API Key ऐप में नहीं दिखाई जाएगी।',style:TextStyle(color:Colors.blueGrey,fontSize:11)),
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
 String display='0',expression='';double? first;String? operator;bool fresh=true;final List<String> history=[];
 void _digit(String value){
  setState((){
   if(fresh||display=='0'){
    display=value=='.'?'0.':value;
    fresh=false;
   }else if(value=='.'&&display.contains('.')){
    return;
   }else{
    display+=value;
   }
  });
 }
 void _clear(){setState((){display='0';expression='';first=null;operator=null;fresh=true;history.clear();});}
 double _calculate(double left,double right,String op){
  switch(op){
   case '+':return left+right;
   case '−':return left-right;
   case '×':return left*right;
   case '÷':return right==0?double.nan:left/right;
   default:return double.nan;
  }
 }
 void _choose(String op){
  final value=double.tryParse(display);
  if(value==null||!value.isFinite)return;
  setState((){
   var next=value;
   // Complete the pending operation before accepting another operator.
   // This supports unlimited chains such as 5 + 5 + 5 + 5.
   if(first!=null&&operator!=null&&!fresh){
    next=_calculate(first!,value,operator!);
    if(!next.isFinite){display='Error';first=null;operator=null;expression='';fresh=true;return;}
    history.add('$expression ${_fmt(value)} = ${_fmt(next)}');
    display=_fmt(next);
   }
   first=next;
   operator=op;
   expression='${_fmt(next)} $op';
   fresh=true;
  });
 }
 void _equals(){
  final second=double.tryParse(display);
  if(first==null||operator==null||second==null)return;
  final result=_calculate(first!,second,operator!);
  setState((){
   final completed='$expression $display = ${result.isFinite?_fmt(result):'Error'}';
   history.add(completed);
   expression='$expression $display =';
   display=result.isFinite?_fmt(result):'Error';
   first=null;
   operator=null;
   fresh=true;
  });
 }
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
  return Expanded(flex:wide?2:1,child:Padding(padding:const EdgeInsets.all(5),child:Material(color:color??Colors.white,elevation:2,shadowColor:const Color(0x1D5369B5),borderRadius:BorderRadius.circular(18),child:InkWell(borderRadius:BorderRadius.circular(18),onTap:onTap,child:Container(height:64,alignment:Alignment.center,decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFE0E6F5))),child:Text(label,style:TextStyle(color:textColor??_ink,fontSize:label.length>3?17:23,fontWeight:FontWeight.w800)))))));
 }
 @override Widget build(BuildContext context){
  final rows=<Widget>[
   Row(children:[_key('AC',color:const Color(0xFFFFE3EA),textColor:const Color(0xFF9C2945),onTap:_clear),_key('DEL',color:const Color(0xFFFFEBD7),textColor:const Color(0xFF9A5014),onTap:_delete),_key('%',color:const Color(0xFFECE7FF),textColor:const Color(0xFF5938A8),onTap:_percent),_key('÷',color:const Color(0xFFDCD5FF),textColor:const Color(0xFF5944A8),onTap:()=>_choose('÷'))]),
   Row(children:[_key('7',onTap:()=>_digit('7')),_key('8',onTap:()=>_digit('8')),_key('9',onTap:()=>_digit('9')),_key('×',color:const Color(0xFFDCD5FF),textColor:const Color(0xFF5944A8),onTap:()=>_choose('×'))]),
   Row(children:[_key('4',onTap:()=>_digit('4')),_key('5',onTap:()=>_digit('5')),_key('6',onTap:()=>_digit('6')),_key('−',color:const Color(0xFFDCD5FF),textColor:const Color(0xFF5944A8),onTap:()=>_choose('−'))]),
   Row(children:[_key('1',onTap:()=>_digit('1')),_key('2',onTap:()=>_digit('2')),_key('3',onTap:()=>_digit('3')),_key('+',color:const Color(0xFFDCD5FF),textColor:const Color(0xFF5944A8),onTap:()=>_choose('+'))]),
   Row(children:[_key('GST',color:const Color(0xFFFFE4A6),textColor:const Color(0xFF78520A),onTap:_gst),_key('0',onTap:()=>_digit('0')),_key('.',onTap:()=>_digit('.')),_key('=',color:const Color(0xFFBFEFE5),textColor:const Color(0xFF087A6A),onTap:_equals)]),
  ];
  return Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFF1F4FF),Color(0xFFE8E7FF),Color(0xFFE1F6F1)])),child:SafeArea(child:Column(children:[
   Padding(padding:const EdgeInsets.fromLTRB(18,22,18,14),child:Row(children:[const Icon(Icons.calculate_rounded,color:Color(0xFF5D6FC6),size:26),const SizedBox(width:9),const Text('कैलकुलेटर',style:TextStyle(color:_ink,fontSize:20,fontWeight:FontWeight.w900)),const Spacer(),Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:const Text('GST Ready',style:TextStyle(color:Color(0xFF9A6A12),fontWeight:FontWeight.w800,fontSize:11)))])),
   Expanded(child:Container(width:double.infinity,margin:const EdgeInsets.fromLTRB(14,6,14,14),padding:const EdgeInsets.fromLTRB(20,18,20,20),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(26),border:Border.all(color:const Color(0xFFDDE4F5)),boxShadow:const [BoxShadow(color:Color(0x18536FC4),blurRadius:18,offset:Offset(0,7))]),child:Column(mainAxisAlignment:MainAxisAlignment.end,crossAxisAlignment:CrossAxisAlignment.end,children:[if(history.isNotEmpty)SizedBox(height:118,width:double.infinity,child:ListView.builder(reverse:true,itemCount:history.length,itemBuilder:(context,index){final line=history[history.length-1-index];return Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Text(line,textAlign:TextAlign.right,style:const TextStyle(color:Color(0xFF66728D),fontSize:13,fontWeight:FontWeight.w600),maxLines:1,overflow:TextOverflow.ellipsis));})),Text(expression,style:const TextStyle(color:Color(0xFF8993AC),fontSize:16),maxLines:1),const SizedBox(height:12),FittedBox(fit:BoxFit.scaleDown,child:Text(display,style:const TextStyle(color:_ink,fontSize:48,fontWeight:FontWeight.w900)))]))),
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
  Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFDDF7EF),Color(0xFFDDE8FF)]),borderRadius:BorderRadius.circular(20)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.volume_up_rounded,color:Color(0xFF218C83),size:34),SizedBox(height:10),Text('Payment Sound Box',style:TextStyle(color:_ink,fontSize:21,fontWeight:FontWeight.w900)),Text('अपने payment provider का API endpoint जोड़ें',style:TextStyle(color:Color(0xFF647393),fontSize:12))])),
  const SizedBox(height:16),TextField(controller:endpoint,keyboardType:TextInputType.url,decoration:const InputDecoration(labelText:'API Endpoint URL',hintText:'https://api.example.com/payments')),
  const SizedBox(height:10),TextField(controller:token,obscureText:obscure,decoration:InputDecoration(labelText:'API Token / Secret (वैकल्पिक)',suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility:Icons.visibility_off)))),
  const SizedBox(height:14),OutlinedButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('API सेटिंग सेव करें')),
  const SizedBox(height:8),FilledButton.icon(onPressed:testing?null:_test,icon:testing?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.link),label:Text(testing?'कनेक्शन जाँच रहे हैं...':'API Connect / Test Connection')),
  TextButton.icon(onPressed:_disconnect,icon:const Icon(Icons.link_off),label:const Text('Disconnect / API हटाएँ')),
  const SizedBox(height:14),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:connected?const Color(0xFFE5F7EF):const Color(0xFFFFF4DF),borderRadius:BorderRadius.circular(14)),child:Row(children:[Icon(connected?Icons.check_circle:Icons.info_outline,color:connected?Colors.green:Colors.orange),const SizedBox(width:10),Expanded(child:Text(status,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)))])),
  const SizedBox(height:12),const Text('ध्यान दें: यह endpoint और token को सेव करके API की पहुँच जाँचता है। असली पेमेंट की आवाज़ तभी चलेगी जब आपके payment provider का webhook/event format और verified payment callback जोड़ा जाएगा। केवल HTTP response को भुगतान की पुष्टि नहीं माना जाएगा।',style:TextStyle(color:Colors.blueGrey,fontSize:11))
 ]);
}
class _CallingInfo extends StatefulWidget {
  const _CallingInfo();

  @override
  State<_CallingInfo> createState() => _CallingInfoState();
}

class _CallingInfoState extends State<_CallingInfo> {
  final _phone = TextEditingController();
  final _transfer = TextEditingController();
  final _instructions = TextEditingController();
  final _otp = TextEditingController();
  int _simSlot = 1;
  String _forwardingMode = 'no_answer';
  bool _disclosureAccepted = false;
  bool _transcriptEnabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _otpSent = false;
  bool _phoneVerified = false;
  String? _pendingPhone;
  String? _verifiedPhone;
  bool _signedIn = false;
  String? _status;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _transfer.dispose();
    _instructions.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final db = Supabase.instance.client;
      final user = db.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() { _loading = false; _signedIn = false; });
        return;
      }
      final results = await Future.wait<dynamic>([
        db.from('ai_call_assistant_settings').select().eq('user_id', user.id).maybeSingle(),
        db.from('ai_call_logs')
            .select('id,caller_number,caller_name,call_reason,summary,status,created_at,duration_seconds')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(10),
      ]);
      final settings = results[0] as Map<String, dynamic>?;
      final logs = (results[1] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final authPhone = user.phone ?? '';
      final storedPhone = settings?['phone_number']?.toString() ?? '';
      final isPhoneVerified = authPhone.isNotEmpty && authPhone == _normalisePhone(storedPhone);
      if (!mounted) return;
      setState(() {
        _signedIn = true;
        _phoneVerified = isPhoneVerified;
        _verifiedPhone = isPhoneVerified ? authPhone : null;
        _loading = false;
        _logs = logs;
        if (settings != null) {
          _phone.text = settings['phone_number']?.toString() ?? '';
          _transfer.text = settings['transfer_number']?.toString() ?? '';
          _instructions.text = settings['assistant_instructions']?.toString() ?? '';
          _simSlot = (settings['sim_slot'] as num?)?.toInt() ?? 1;
          _forwardingMode = settings['forwarding_mode']?.toString() ?? 'no_answer';
          _disclosureAccepted = settings['disclosure_accepted_at'] != null;
          _transcriptEnabled = settings['transcript_enabled'] == true;
        }
      });
    } catch (error) {
      if (mounted) setState(() { _loading = false; _status = 'सेटिंग लोड नहीं हुई: $error'; });
    }
  }

  String _normalisePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\\D'), '');
    if (digits.length == 10 && RegExp(r'^[6-9]\\d{9}
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) {
      setState(() => _status = 'सेटिंग सेव करने के लिए पहले लॉगिन करें।');
      return;
    }
    final phone = _normalisePhone(_phone.text);
    if (phone.isEmpty) {
      setState(() => _status = 'अपना मोबाइल नंबर दर्ज करें।');
      return;
    }
    if (!_phoneVerified || _verifiedPhone != phone) {
      setState(() => _status = 'सेटिंग सेव करने से पहले मोबाइल नंबर का OTP वेरिफिकेशन पूरा करें।');
      return;
    }
    if (!_disclosureAccepted) {
      setState(() => _status = 'AI पहचान और कॉलर को सूचना देने की सहमति चुनें।');
      return;
    }
    setState(() { _saving = true; _status = null; });
    try {
      await db.from('ai_call_assistant_settings').upsert({
        'user_id': user.id,
        'sim_slot': _simSlot,
        'phone_number': phone,
        'transfer_number': _normalisePhone(_transfer.text),
        'assistant_instructions': _instructions.text.trim(),
        'enabled': false,
        'forwarding_mode': _forwardingMode,
        'disclosure_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'transcript_enabled': _transcriptEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) setState(() => _status = 'आपकी Calling Assistant सेटिंग सुरक्षित रूप से सेव हो गई है।');
    } catch (error) {
      if (mounted) setState(() => _status = 'सेटिंग सेव नहीं हुई: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _statusLabel(String? value) {
    switch (value) {
      case 'completed': return 'पूरी हुई';
      case 'transferred': return 'आपको ट्रांसफर हुई';
      case 'missed': return 'मिस्ड कॉल';
      case 'failed': return 'कनेक्शन विफल';
      case 'answered': return 'AI ने जवाब दिया';
      default: return 'कॉल प्राप्त हुई';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_signedIn) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('AI Calling Assistant सेट करने के लिए Bharat Saathi में लॉगिन करें।'),
      ));
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE0F4F5), Color(0xFFE6EAFE)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.support_agent_rounded, size: 38, color: _teal),
              SizedBox(height: 10),
              Text('आपका AI फोन असिस्टेंट', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _ink)),
              SizedBox(height: 5),
              Text('AI आपकी ओर से आने वाली कॉल संभालेगा, ज़रूरी जानकारी लेगा और ज़रूरत पड़ने पर कॉल आपको ट्रांसफर करेगा।', style: TextStyle(color: Color(0xFF52627D), height: 1.4)),
              SizedBox(height: 10),
              Row(children: [
                Icon(Icons.radio_button_checked, size: 13, color: Colors.orange),
                SizedBox(width: 6),
                Text('टेलीफोनी कनेक्शन सेटअप बाकी है', style: TextStyle(color: Color(0xFF8B5B13), fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('1. अपना नंबर और SIM चुनें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _simSlot,
          decoration: const InputDecoration(labelText: 'किस SIM पर कॉल आती हैं?'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('SIM 1')),
            DropdownMenuItem(value: 2, child: Text('SIM 2')),
          ],
          onChanged: (value) { if (value != null) setState(() => _simSlot = value); },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          enabled: !_otpSent,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          onChanged: (_) {
            final current = _normalisePhone(_phone.text);
            if (_phoneVerified && current != _verifiedPhone) setState(() { _phoneVerified = false; _verifiedPhone = null; });
          },
          decoration: InputDecoration(
            labelText: 'आपका मोबाइल नंबर',
            hintText: '9876543210',
            prefixText: '+91 ',
            suffixIcon: _phoneVerified ? const Icon(Icons.verified, color: Colors.green) : null,
          ),
        ),
        const SizedBox(height: 8),
        if (!_phoneVerified && !_otpSent)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sendingOtp ? null : _sendPhoneOtp,
              icon: _sendingOtp ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.sms_outlined),
              label: Text(_sendingOtp ? 'OTP भेजा जा रहा है...' : 'नंबर कनेक्ट करें और OTP भेजें'),
            ),
          ),
        if (_otpSent) ...[
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            decoration: const InputDecoration(labelText: 'SMS में आया 6 अंकों का OTP'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FilledButton(
              onPressed: _verifyingOtp ? null : _verifyPhoneOtp,
              child: Text(_verifyingOtp ? 'वेरिफाई हो रहा है...' : 'OTP वेरिफाई करें'),
            )),
            const SizedBox(width: 8),
            TextButton(onPressed: _sendingOtp ? null : _resendPhoneOtp, child: const Text('दोबारा भेजें')),
          ]),
        ],
        if (_phoneVerified)
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: Row(children: [
              Icon(Icons.verified, color: Colors.green, size: 18),
              SizedBox(width: 6),
              Text('मोबाइल नंबर वेरिफाई है', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _transfer,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'कॉल ट्रांसफर नंबर', hintText: 'खाली छोड़ें तो ऊपर वाला नंबर इस्तेमाल होगा'),
        ),
        const SizedBox(height: 18),
        const Text('2. कॉल फॉरवर्डिंग का तरीका', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _forwardingMode,
          decoration: const InputDecoration(labelText: 'कब AI को कॉल भेजनी है?'),
          items: const [
            DropdownMenuItem(value: 'no_answer', child: Text('जब आप कॉल न उठाएँ')),
            DropdownMenuItem(value: 'busy', child: Text('जब आपका नंबर व्यस्त हो')),
            DropdownMenuItem(value: 'unreachable', child: Text('जब फोन बंद या नेटवर्क से बाहर हो')),
          ],
          onChanged: (value) { if (value != null) setState(() => _forwardingMode = value); },
        ),
        const SizedBox(height: 8),
        const Text('कॉल फॉरवर्डिंग आपके मोबाइल ऑपरेटर के जरिए चालू होगी। अभी ऐप आपके SIM पर कोई कोड अपने-आप नहीं चलाता। सही ऑपरेटर सेटअप मिलने पर ऐप में चरण-दर-चरण निर्देश दिए जाएँगे।', style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.4)),
        const SizedBox(height: 18),
        const Text('3. AI को क्या करना है?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        TextField(
          controller: _instructions,
          minLines: 4,
          maxLines: 7,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'अपने असिस्टेंट को निर्देश दें',
            hintText: 'जैसे: कॉल करने वाले का नाम, पता और कॉल का कारण पूछें। जरूरी काम हो तो मुझे कॉल ट्रांसफर करें।',
            alignLabelWithHint: true,
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _disclosureAccepted,
          onChanged: (value) => setState(() => _disclosureAccepted = value == true),
          title: const Text('AI हर कॉल की शुरुआत में अपनी पहचान बताएगा और कॉलर को जानकारी देगा।', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _transcriptEnabled,
          onChanged: (value) => setState(() => _transcriptEnabled = value == true),
          title: const Text('कॉलर को सूचना/सहमति देने के बाद बातचीत का टेक्स्ट और सारांश सेव करें।', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'सेव हो रहा है...' : 'सेटिंग सेव करें'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.call),
          label: const Text('AI को कॉल करें — टेलीफोनी सेटअप के बाद'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 10),
          Text(_status!, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
        ],
        const SizedBox(height: 22),
        const Text('हाल की कॉल', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        if (_logs.isEmpty)
          const Text('अभी कोई AI कॉल रिकॉर्ड उपलब्ध नहीं है।', style: TextStyle(color: Colors.blueGrey, fontSize: 12))
        else
          ..._logs.map((log) {
            final name = (log['caller_name']?.toString().trim().isNotEmpty ?? false)
                ? log['caller_name'].toString()
                : (log['caller_number']?.toString().isNotEmpty ?? false)
                    ? log['caller_number'].toString()
                    : 'अनजान कॉलर';
            final summary = log['summary']?.toString().trim() ?? '';
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.call_received)),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(summary.isNotEmpty ? summary : (log['call_reason']?.toString() ?? 'कॉल विवरण उपलब्ध नहीं')),
                trailing: Text(_statusLabel(log['status']?.toString()), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                isThreeLine: true,
                dense: true,
              ),
            );
          }),
        const SizedBox(height: 12),
        const Text('सुरक्षा: AI कभी भी OTP, UPI PIN, बैंक पासवर्ड या कार्ड PIN नहीं माँगेगा। कॉल संभालना तभी शुरू होगा जब टेलीफोनी प्रोवाइडर, OpenAI SIP webhook और कॉल-फॉरवर्डिंग का परीक्षण पूरा होगा।', style: TextStyle(color: Colors.blueGrey, fontSize: 11, height: 1.4)),
      ],
    );
  }
}
).hasMatch(digits)) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91') && RegExp(r'^[6-9]\\d{9}
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) {
      setState(() => _status = 'सेटिंग सेव करने के लिए पहले लॉगिन करें।');
      return;
    }
    final phone = _normalisePhone(_phone.text);
    if (phone.isEmpty) {
      setState(() => _status = 'अपना मोबाइल नंबर दर्ज करें।');
      return;
    }
    if (!_disclosureAccepted) {
      setState(() => _status = 'AI पहचान और कॉलर को सूचना देने की सहमति चुनें।');
      return;
    }
    setState(() { _saving = true; _status = null; });
    try {
      await db.from('ai_call_assistant_settings').upsert({
        'user_id': user.id,
        'sim_slot': _simSlot,
        'phone_number': phone,
        'transfer_number': _normalisePhone(_transfer.text),
        'assistant_instructions': _instructions.text.trim(),
        'enabled': false,
        'forwarding_mode': _forwardingMode,
        'disclosure_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'transcript_enabled': _transcriptEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) setState(() => _status = 'आपकी Calling Assistant सेटिंग सुरक्षित रूप से सेव हो गई है।');
    } catch (error) {
      if (mounted) setState(() => _status = 'सेटिंग सेव नहीं हुई: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _statusLabel(String? value) {
    switch (value) {
      case 'completed': return 'पूरी हुई';
      case 'transferred': return 'आपको ट्रांसफर हुई';
      case 'missed': return 'मिस्ड कॉल';
      case 'failed': return 'कनेक्शन विफल';
      case 'answered': return 'AI ने जवाब दिया';
      default: return 'कॉल प्राप्त हुई';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_signedIn) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('AI Calling Assistant सेट करने के लिए Bharat Saathi में लॉगिन करें।'),
      ));
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE0F4F5), Color(0xFFE6EAFE)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.support_agent_rounded, size: 38, color: _teal),
              SizedBox(height: 10),
              Text('आपका AI फोन असिस्टेंट', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _ink)),
              SizedBox(height: 5),
              Text('AI आपकी ओर से आने वाली कॉल संभालेगा, ज़रूरी जानकारी लेगा और ज़रूरत पड़ने पर कॉल आपको ट्रांसफर करेगा।', style: TextStyle(color: Color(0xFF52627D), height: 1.4)),
              SizedBox(height: 10),
              Row(children: [
                Icon(Icons.radio_button_checked, size: 13, color: Colors.orange),
                SizedBox(width: 6),
                Text('टेलीफोनी कनेक्शन सेटअप बाकी है', style: TextStyle(color: Color(0xFF8B5B13), fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('1. अपना नंबर और SIM चुनें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _simSlot,
          decoration: const InputDecoration(labelText: 'किस SIM पर कॉल आती हैं?'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('SIM 1')),
            DropdownMenuItem(value: 2, child: Text('SIM 2')),
          ],
          onChanged: (value) { if (value != null) setState(() => _simSlot = value); },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'आपका मोबाइल नंबर', hintText: '+91XXXXXXXXXX'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _transfer,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'कॉल ट्रांसफर नंबर', hintText: 'खाली छोड़ें तो ऊपर वाला नंबर इस्तेमाल होगा'),
        ),
        const SizedBox(height: 18),
        const Text('2. कॉल फॉरवर्डिंग का तरीका', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _forwardingMode,
          decoration: const InputDecoration(labelText: 'कब AI को कॉल भेजनी है?'),
          items: const [
            DropdownMenuItem(value: 'no_answer', child: Text('जब आप कॉल न उठाएँ')),
            DropdownMenuItem(value: 'busy', child: Text('जब आपका नंबर व्यस्त हो')),
            DropdownMenuItem(value: 'unreachable', child: Text('जब फोन बंद या नेटवर्क से बाहर हो')),
          ],
          onChanged: (value) { if (value != null) setState(() => _forwardingMode = value); },
        ),
        const SizedBox(height: 8),
        const Text('कॉल फॉरवर्डिंग आपके मोबाइल ऑपरेटर के जरिए चालू होगी। अभी ऐप आपके SIM पर कोई कोड अपने-आप नहीं चलाता। सही ऑपरेटर सेटअप मिलने पर ऐप में चरण-दर-चरण निर्देश दिए जाएँगे।', style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.4)),
        const SizedBox(height: 18),
        const Text('3. AI को क्या करना है?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        TextField(
          controller: _instructions,
          minLines: 4,
          maxLines: 7,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'अपने असिस्टेंट को निर्देश दें',
            hintText: 'जैसे: कॉल करने वाले का नाम, पता और कॉल का कारण पूछें। जरूरी काम हो तो मुझे कॉल ट्रांसफर करें।',
            alignLabelWithHint: true,
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _disclosureAccepted,
          onChanged: (value) => setState(() => _disclosureAccepted = value == true),
          title: const Text('AI हर कॉल की शुरुआत में अपनी पहचान बताएगा और कॉलर को जानकारी देगा।', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _transcriptEnabled,
          onChanged: (value) => setState(() => _transcriptEnabled = value == true),
          title: const Text('कॉलर को सूचना/सहमति देने के बाद बातचीत का टेक्स्ट और सारांश सेव करें।', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'सेव हो रहा है...' : 'सेटिंग सेव करें'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.call),
          label: const Text('AI को कॉल करें — टेलीफोनी सेटअप के बाद'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 10),
          Text(_status!, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
        ],
        const SizedBox(height: 22),
        const Text('हाल की कॉल', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        if (_logs.isEmpty)
          const Text('अभी कोई AI कॉल रिकॉर्ड उपलब्ध नहीं है।', style: TextStyle(color: Colors.blueGrey, fontSize: 12))
        else
          ..._logs.map((log) {
            final name = (log['caller_name']?.toString().trim().isNotEmpty ?? false)
                ? log['caller_name'].toString()
                : (log['caller_number']?.toString().isNotEmpty ?? false)
                    ? log['caller_number'].toString()
                    : 'अनजान कॉलर';
            final summary = log['summary']?.toString().trim() ?? '';
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.call_received)),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(summary.isNotEmpty ? summary : (log['call_reason']?.toString() ?? 'कॉल विवरण उपलब्ध नहीं')),
                trailing: Text(_statusLabel(log['status']?.toString()), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                isThreeLine: true,
                dense: true,
              ),
            );
          }),
        const SizedBox(height: 12),
        const Text('सुरक्षा: AI कभी भी OTP, UPI PIN, बैंक पासवर्ड या कार्ड PIN नहीं माँगेगा। कॉल संभालना तभी शुरू होगा जब टेलीफोनी प्रोवाइडर, OpenAI SIP webhook और कॉल-फॉरवर्डिंग का परीक्षण पूरा होगा।', style: TextStyle(color: Colors.blueGrey, fontSize: 11, height: 1.4)),
      ],
    );
  }
}
).hasMatch(digits.substring(2))) return '+$digits';
    if (digits.length == 11 && digits.startsWith('0') && RegExp(r'^[6-9]\\d{9}
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) {
      setState(() => _status = 'सेटिंग सेव करने के लिए पहले लॉगिन करें।');
      return;
    }
    final phone = _normalisePhone(_phone.text);
    if (phone.isEmpty) {
      setState(() => _status = 'अपना मोबाइल नंबर दर्ज करें।');
      return;
    }
    if (!_disclosureAccepted) {
      setState(() => _status = 'AI पहचान और कॉलर को सूचना देने की सहमति चुनें।');
      return;
    }
    setState(() { _saving = true; _status = null; });
    try {
      await db.from('ai_call_assistant_settings').upsert({
        'user_id': user.id,
        'sim_slot': _simSlot,
        'phone_number': phone,
        'transfer_number': _normalisePhone(_transfer.text),
        'assistant_instructions': _instructions.text.trim(),
        'enabled': false,
        'forwarding_mode': _forwardingMode,
        'disclosure_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'transcript_enabled': _transcriptEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) setState(() => _status = 'आपकी Calling Assistant सेटिंग सुरक्षित रूप से सेव हो गई है।');
    } catch (error) {
      if (mounted) setState(() => _status = 'सेटिंग सेव नहीं हुई: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _statusLabel(String? value) {
    switch (value) {
      case 'completed': return 'पूरी हुई';
      case 'transferred': return 'आपको ट्रांसफर हुई';
      case 'missed': return 'मिस्ड कॉल';
      case 'failed': return 'कनेक्शन विफल';
      case 'answered': return 'AI ने जवाब दिया';
      default: return 'कॉल प्राप्त हुई';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_signedIn) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('AI Calling Assistant सेट करने के लिए Bharat Saathi में लॉगिन करें।'),
      ));
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE0F4F5), Color(0xFFE6EAFE)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.support_agent_rounded, size: 38, color: _teal),
              SizedBox(height: 10),
              Text('आपका AI फोन असिस्टेंट', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _ink)),
              SizedBox(height: 5),
              Text('AI आपकी ओर से आने वाली कॉल संभालेगा, ज़रूरी जानकारी लेगा और ज़रूरत पड़ने पर कॉल आपको ट्रांसफर करेगा।', style: TextStyle(color: Color(0xFF52627D), height: 1.4)),
              SizedBox(height: 10),
              Row(children: [
                Icon(Icons.radio_button_checked, size: 13, color: Colors.orange),
                SizedBox(width: 6),
                Text('टेलीफोनी कनेक्शन सेटअप बाकी है', style: TextStyle(color: Color(0xFF8B5B13), fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('1. अपना नंबर और SIM चुनें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _simSlot,
          decoration: const InputDecoration(labelText: 'किस SIM पर कॉल आती हैं?'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('SIM 1')),
            DropdownMenuItem(value: 2, child: Text('SIM 2')),
          ],
          onChanged: (value) { if (value != null) setState(() => _simSlot = value); },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'आपका मोबाइल नंबर', hintText: '+91XXXXXXXXXX'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _transfer,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'कॉल ट्रांसफर नंबर', hintText: 'खाली छोड़ें तो ऊपर वाला नंबर इस्तेमाल होगा'),
        ),
        const SizedBox(height: 18),
        const Text('2. कॉल फॉरवर्डिंग का तरीका', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _forwardingMode,
          decoration: const InputDecoration(labelText: 'कब AI को कॉल भेजनी है?'),
          items: const [
            DropdownMenuItem(value: 'no_answer', child: Text('जब आप कॉल न उठाएँ')),
            DropdownMenuItem(value: 'busy', child: Text('जब आपका नंबर व्यस्त हो')),
            DropdownMenuItem(value: 'unreachable', child: Text('जब फोन बंद या नेटवर्क से बाहर हो')),
          ],
          onChanged: (value) { if (value != null) setState(() => _forwardingMode = value); },
        ),
        const SizedBox(height: 8),
        const Text('कॉल फॉरवर्डिंग आपके मोबाइल ऑपरेटर के जरिए चालू होगी। अभी ऐप आपके SIM पर कोई कोड अपने-आप नहीं चलाता। सही ऑपरेटर सेटअप मिलने पर ऐप में चरण-दर-चरण निर्देश दिए जाएँगे।', style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.4)),
        const SizedBox(height: 18),
        const Text('3. AI को क्या करना है?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        TextField(
          controller: _instructions,
          minLines: 4,
          maxLines: 7,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'अपने असिस्टेंट को निर्देश दें',
            hintText: 'जैसे: कॉल करने वाले का नाम, पता और कॉल का कारण पूछें। जरूरी काम हो तो मुझे कॉल ट्रांसफर करें।',
            alignLabelWithHint: true,
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _disclosureAccepted,
          onChanged: (value) => setState(() => _disclosureAccepted = value == true),
          title: const Text('AI हर कॉल की शुरुआत में अपनी पहचान बताएगा और कॉलर को जानकारी देगा।', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _transcriptEnabled,
          onChanged: (value) => setState(() => _transcriptEnabled = value == true),
          title: const Text('कॉलर को सूचना/सहमति देने के बाद बातचीत का टेक्स्ट और सारांश सेव करें।', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'सेव हो रहा है...' : 'सेटिंग सेव करें'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.call),
          label: const Text('AI को कॉल करें — टेलीफोनी सेटअप के बाद'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 10),
          Text(_status!, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
        ],
        const SizedBox(height: 22),
        const Text('हाल की कॉल', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        if (_logs.isEmpty)
          const Text('अभी कोई AI कॉल रिकॉर्ड उपलब्ध नहीं है।', style: TextStyle(color: Colors.blueGrey, fontSize: 12))
        else
          ..._logs.map((log) {
            final name = (log['caller_name']?.toString().trim().isNotEmpty ?? false)
                ? log['caller_name'].toString()
                : (log['caller_number']?.toString().isNotEmpty ?? false)
                    ? log['caller_number'].toString()
                    : 'अनजान कॉलर';
            final summary = log['summary']?.toString().trim() ?? '';
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.call_received)),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(summary.isNotEmpty ? summary : (log['call_reason']?.toString() ?? 'कॉल विवरण उपलब्ध नहीं')),
                trailing: Text(_statusLabel(log['status']?.toString()), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                isThreeLine: true,
                dense: true,
              ),
            );
          }),
        const SizedBox(height: 12),
        const Text('सुरक्षा: AI कभी भी OTP, UPI PIN, बैंक पासवर्ड या कार्ड PIN नहीं माँगेगा। कॉल संभालना तभी शुरू होगा जब टेलीफोनी प्रोवाइडर, OpenAI SIP webhook और कॉल-फॉरवर्डिंग का परीक्षण पूरा होगा।', style: TextStyle(color: Colors.blueGrey, fontSize: 11, height: 1.4)),
      ],
    );
  }
}
).hasMatch(digits.substring(1))) return '+91${digits.substring(1)}';
    return value.trim().replaceAll(RegExp(r'\\s+'), '');
  }

  bool _isValidIndianPhone(String value) => RegExp(r'^\\+91[6-9]\\d{9}
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) {
      setState(() => _status = 'सेटिंग सेव करने के लिए पहले लॉगिन करें।');
      return;
    }
    final phone = _normalisePhone(_phone.text);
    if (phone.isEmpty) {
      setState(() => _status = 'अपना मोबाइल नंबर दर्ज करें।');
      return;
    }
    if (!_disclosureAccepted) {
      setState(() => _status = 'AI पहचान और कॉलर को सूचना देने की सहमति चुनें।');
      return;
    }
    setState(() { _saving = true; _status = null; });
    try {
      await db.from('ai_call_assistant_settings').upsert({
        'user_id': user.id,
        'sim_slot': _simSlot,
        'phone_number': phone,
        'transfer_number': _normalisePhone(_transfer.text),
        'assistant_instructions': _instructions.text.trim(),
        'enabled': false,
        'forwarding_mode': _forwardingMode,
        'disclosure_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'transcript_enabled': _transcriptEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) setState(() => _status = 'आपकी Calling Assistant सेटिंग सुरक्षित रूप से सेव हो गई है।');
    } catch (error) {
      if (mounted) setState(() => _status = 'सेटिंग सेव नहीं हुई: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _statusLabel(String? value) {
    switch (value) {
      case 'completed': return 'पूरी हुई';
      case 'transferred': return 'आपको ट्रांसफर हुई';
      case 'missed': return 'मिस्ड कॉल';
      case 'failed': return 'कनेक्शन विफल';
      case 'answered': return 'AI ने जवाब दिया';
      default: return 'कॉल प्राप्त हुई';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_signedIn) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('AI Calling Assistant सेट करने के लिए Bharat Saathi में लॉगिन करें।'),
      ));
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE0F4F5), Color(0xFFE6EAFE)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.support_agent_rounded, size: 38, color: _teal),
              SizedBox(height: 10),
              Text('आपका AI फोन असिस्टेंट', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _ink)),
              SizedBox(height: 5),
              Text('AI आपकी ओर से आने वाली कॉल संभालेगा, ज़रूरी जानकारी लेगा और ज़रूरत पड़ने पर कॉल आपको ट्रांसफर करेगा।', style: TextStyle(color: Color(0xFF52627D), height: 1.4)),
              SizedBox(height: 10),
              Row(children: [
                Icon(Icons.radio_button_checked, size: 13, color: Colors.orange),
                SizedBox(width: 6),
                Text('टेलीफोनी कनेक्शन सेटअप बाकी है', style: TextStyle(color: Color(0xFF8B5B13), fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('1. अपना नंबर और SIM चुनें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _simSlot,
          decoration: const InputDecoration(labelText: 'किस SIM पर कॉल आती हैं?'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('SIM 1')),
            DropdownMenuItem(value: 2, child: Text('SIM 2')),
          ],
          onChanged: (value) { if (value != null) setState(() => _simSlot = value); },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'आपका मोबाइल नंबर', hintText: '+91XXXXXXXXXX'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _transfer,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'कॉल ट्रांसफर नंबर', hintText: 'खाली छोड़ें तो ऊपर वाला नंबर इस्तेमाल होगा'),
        ),
        const SizedBox(height: 18),
        const Text('2. कॉल फॉरवर्डिंग का तरीका', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _forwardingMode,
          decoration: const InputDecoration(labelText: 'कब AI को कॉल भेजनी है?'),
          items: const [
            DropdownMenuItem(value: 'no_answer', child: Text('जब आप कॉल न उठाएँ')),
            DropdownMenuItem(value: 'busy', child: Text('जब आपका नंबर व्यस्त हो')),
            DropdownMenuItem(value: 'unreachable', child: Text('जब फोन बंद या नेटवर्क से बाहर हो')),
          ],
          onChanged: (value) { if (value != null) setState(() => _forwardingMode = value); },
        ),
        const SizedBox(height: 8),
        const Text('कॉल फॉरवर्डिंग आपके मोबाइल ऑपरेटर के जरिए चालू होगी। अभी ऐप आपके SIM पर कोई कोड अपने-आप नहीं चलाता। सही ऑपरेटर सेटअप मिलने पर ऐप में चरण-दर-चरण निर्देश दिए जाएँगे।', style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.4)),
        const SizedBox(height: 18),
        const Text('3. AI को क्या करना है?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        TextField(
          controller: _instructions,
          minLines: 4,
          maxLines: 7,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'अपने असिस्टेंट को निर्देश दें',
            hintText: 'जैसे: कॉल करने वाले का नाम, पता और कॉल का कारण पूछें। जरूरी काम हो तो मुझे कॉल ट्रांसफर करें।',
            alignLabelWithHint: true,
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _disclosureAccepted,
          onChanged: (value) => setState(() => _disclosureAccepted = value == true),
          title: const Text('AI हर कॉल की शुरुआत में अपनी पहचान बताएगा और कॉलर को जानकारी देगा।', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _transcriptEnabled,
          onChanged: (value) => setState(() => _transcriptEnabled = value == true),
          title: const Text('कॉलर को सूचना/सहमति देने के बाद बातचीत का टेक्स्ट और सारांश सेव करें।', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'सेव हो रहा है...' : 'सेटिंग सेव करें'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.call),
          label: const Text('AI को कॉल करें — टेलीफोनी सेटअप के बाद'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 10),
          Text(_status!, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
        ],
        const SizedBox(height: 22),
        const Text('हाल की कॉल', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        if (_logs.isEmpty)
          const Text('अभी कोई AI कॉल रिकॉर्ड उपलब्ध नहीं है।', style: TextStyle(color: Colors.blueGrey, fontSize: 12))
        else
          ..._logs.map((log) {
            final name = (log['caller_name']?.toString().trim().isNotEmpty ?? false)
                ? log['caller_name'].toString()
                : (log['caller_number']?.toString().isNotEmpty ?? false)
                    ? log['caller_number'].toString()
                    : 'अनजान कॉलर';
            final summary = log['summary']?.toString().trim() ?? '';
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.call_received)),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(summary.isNotEmpty ? summary : (log['call_reason']?.toString() ?? 'कॉल विवरण उपलब्ध नहीं')),
                trailing: Text(_statusLabel(log['status']?.toString()), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                isThreeLine: true,
                dense: true,
              ),
            );
          }),
        const SizedBox(height: 12),
        const Text('सुरक्षा: AI कभी भी OTP, UPI PIN, बैंक पासवर्ड या कार्ड PIN नहीं माँगेगा। कॉल संभालना तभी शुरू होगा जब टेलीफोनी प्रोवाइडर, OpenAI SIP webhook और कॉल-फॉरवर्डिंग का परीक्षण पूरा होगा।', style: TextStyle(color: Colors.blueGrey, fontSize: 11, height: 1.4)),
      ],
    );
  }
}
).hasMatch(value);

  Future<void> _sendPhoneOtp() async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    final phone = _normalisePhone(_phone.text);
    if (user == null) { setState(() => _status = 'पहले Bharat Saathi में लॉगिन करें।'); return; }
    if (!_isValidIndianPhone(phone)) { setState(() => _status = 'सही 10 अंकों का भारतीय मोबाइल नंबर दर्ज करें।'); return; }
    if (user.phone == phone) {
      setState(() { _phoneVerified = true; _verifiedPhone = phone; _status = 'यह मोबाइल नंबर पहले से वेरिफाई है।'; });
      return;
    }
    setState(() { _sendingOtp = true; _status = null; });
    try {
      // Verify this number on the existing email/Google account; do not sign in as a new phone user.
      await db.auth.updateUser(UserAttributes(phone: phone));
      if (!mounted) return;
      setState(() { _pendingPhone = phone; _otpSent = true; _phoneVerified = false; _verifiedPhone = null; _status = 'OTP भेज दिया गया है। SMS में आया 6 अंकों का कोड डालें।'; });
    } catch (error) {
      if (mounted) setState(() => _status = 'OTP नहीं भेजा गया: $error');
    } finally { if (mounted) setState(() => _sendingOtp = false); }
  }

  Future<void> _resendPhoneOtp() async {
    final phone = _pendingPhone;
    if (phone == null) return;
    setState(() { _sendingOtp = true; _status = null; });
    try {
      await Supabase.instance.client.auth.resend(type: OtpType.phoneChange, phone: phone);
      if (mounted) setState(() => _status = 'नया OTP भेज दिया गया है।');
    } catch (error) { if (mounted) setState(() => _status = 'OTP दोबारा नहीं भेजा गया: $error'); }
    finally { if (mounted) setState(() => _sendingOtp = false); }
  }

  Future<void> _verifyPhoneOtp() async {
    final phone = _pendingPhone;
    final token = _otp.text.trim();
    if (phone == null || !RegExp(r'^\\d{6}
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) {
      setState(() => _status = 'सेटिंग सेव करने के लिए पहले लॉगिन करें।');
      return;
    }
    final phone = _normalisePhone(_phone.text);
    if (phone.isEmpty) {
      setState(() => _status = 'अपना मोबाइल नंबर दर्ज करें।');
      return;
    }
    if (!_disclosureAccepted) {
      setState(() => _status = 'AI पहचान और कॉलर को सूचना देने की सहमति चुनें।');
      return;
    }
    setState(() { _saving = true; _status = null; });
    try {
      await db.from('ai_call_assistant_settings').upsert({
        'user_id': user.id,
        'sim_slot': _simSlot,
        'phone_number': phone,
        'transfer_number': _normalisePhone(_transfer.text),
        'assistant_instructions': _instructions.text.trim(),
        'enabled': false,
        'forwarding_mode': _forwardingMode,
        'disclosure_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'transcript_enabled': _transcriptEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) setState(() => _status = 'आपकी Calling Assistant सेटिंग सुरक्षित रूप से सेव हो गई है।');
    } catch (error) {
      if (mounted) setState(() => _status = 'सेटिंग सेव नहीं हुई: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _statusLabel(String? value) {
    switch (value) {
      case 'completed': return 'पूरी हुई';
      case 'transferred': return 'आपको ट्रांसफर हुई';
      case 'missed': return 'मिस्ड कॉल';
      case 'failed': return 'कनेक्शन विफल';
      case 'answered': return 'AI ने जवाब दिया';
      default: return 'कॉल प्राप्त हुई';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_signedIn) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('AI Calling Assistant सेट करने के लिए Bharat Saathi में लॉगिन करें।'),
      ));
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE0F4F5), Color(0xFFE6EAFE)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.support_agent_rounded, size: 38, color: _teal),
              SizedBox(height: 10),
              Text('आपका AI फोन असिस्टेंट', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _ink)),
              SizedBox(height: 5),
              Text('AI आपकी ओर से आने वाली कॉल संभालेगा, ज़रूरी जानकारी लेगा और ज़रूरत पड़ने पर कॉल आपको ट्रांसफर करेगा।', style: TextStyle(color: Color(0xFF52627D), height: 1.4)),
              SizedBox(height: 10),
              Row(children: [
                Icon(Icons.radio_button_checked, size: 13, color: Colors.orange),
                SizedBox(width: 6),
                Text('टेलीफोनी कनेक्शन सेटअप बाकी है', style: TextStyle(color: Color(0xFF8B5B13), fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('1. अपना नंबर और SIM चुनें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _simSlot,
          decoration: const InputDecoration(labelText: 'किस SIM पर कॉल आती हैं?'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('SIM 1')),
            DropdownMenuItem(value: 2, child: Text('SIM 2')),
          ],
          onChanged: (value) { if (value != null) setState(() => _simSlot = value); },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'आपका मोबाइल नंबर', hintText: '+91XXXXXXXXXX'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _transfer,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'कॉल ट्रांसफर नंबर', hintText: 'खाली छोड़ें तो ऊपर वाला नंबर इस्तेमाल होगा'),
        ),
        const SizedBox(height: 18),
        const Text('2. कॉल फॉरवर्डिंग का तरीका', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _forwardingMode,
          decoration: const InputDecoration(labelText: 'कब AI को कॉल भेजनी है?'),
          items: const [
            DropdownMenuItem(value: 'no_answer', child: Text('जब आप कॉल न उठाएँ')),
            DropdownMenuItem(value: 'busy', child: Text('जब आपका नंबर व्यस्त हो')),
            DropdownMenuItem(value: 'unreachable', child: Text('जब फोन बंद या नेटवर्क से बाहर हो')),
          ],
          onChanged: (value) { if (value != null) setState(() => _forwardingMode = value); },
        ),
        const SizedBox(height: 8),
        const Text('कॉल फॉरवर्डिंग आपके मोबाइल ऑपरेटर के जरिए चालू होगी। अभी ऐप आपके SIM पर कोई कोड अपने-आप नहीं चलाता। सही ऑपरेटर सेटअप मिलने पर ऐप में चरण-दर-चरण निर्देश दिए जाएँगे।', style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.4)),
        const SizedBox(height: 18),
        const Text('3. AI को क्या करना है?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        TextField(
          controller: _instructions,
          minLines: 4,
          maxLines: 7,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'अपने असिस्टेंट को निर्देश दें',
            hintText: 'जैसे: कॉल करने वाले का नाम, पता और कॉल का कारण पूछें। जरूरी काम हो तो मुझे कॉल ट्रांसफर करें।',
            alignLabelWithHint: true,
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _disclosureAccepted,
          onChanged: (value) => setState(() => _disclosureAccepted = value == true),
          title: const Text('AI हर कॉल की शुरुआत में अपनी पहचान बताएगा और कॉलर को जानकारी देगा।', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _transcriptEnabled,
          onChanged: (value) => setState(() => _transcriptEnabled = value == true),
          title: const Text('कॉलर को सूचना/सहमति देने के बाद बातचीत का टेक्स्ट और सारांश सेव करें।', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'सेव हो रहा है...' : 'सेटिंग सेव करें'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.call),
          label: const Text('AI को कॉल करें — टेलीफोनी सेटअप के बाद'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 10),
          Text(_status!, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
        ],
        const SizedBox(height: 22),
        const Text('हाल की कॉल', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        if (_logs.isEmpty)
          const Text('अभी कोई AI कॉल रिकॉर्ड उपलब्ध नहीं है।', style: TextStyle(color: Colors.blueGrey, fontSize: 12))
        else
          ..._logs.map((log) {
            final name = (log['caller_name']?.toString().trim().isNotEmpty ?? false)
                ? log['caller_name'].toString()
                : (log['caller_number']?.toString().isNotEmpty ?? false)
                    ? log['caller_number'].toString()
                    : 'अनजान कॉलर';
            final summary = log['summary']?.toString().trim() ?? '';
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.call_received)),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(summary.isNotEmpty ? summary : (log['call_reason']?.toString() ?? 'कॉल विवरण उपलब्ध नहीं')),
                trailing: Text(_statusLabel(log['status']?.toString()), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                isThreeLine: true,
                dense: true,
              ),
            );
          }),
        const SizedBox(height: 12),
        const Text('सुरक्षा: AI कभी भी OTP, UPI PIN, बैंक पासवर्ड या कार्ड PIN नहीं माँगेगा। कॉल संभालना तभी शुरू होगा जब टेलीफोनी प्रोवाइडर, OpenAI SIP webhook और कॉल-फॉरवर्डिंग का परीक्षण पूरा होगा।', style: TextStyle(color: Colors.blueGrey, fontSize: 11, height: 1.4)),
      ],
    );
  }
}
).hasMatch(token)) { setState(() => _status = '6 अंकों का OTP दर्ज करें।'); return; }
    setState(() { _verifyingOtp = true; _status = null; });
    try {
      final db = Supabase.instance.client;
      final response = await db.auth.verifyOTP(phone: phone, token: token, type: OtpType.phoneChange);
      final verifiedPhone = response.user?.phone ?? db.auth.currentUser?.phone;
      if (verifiedPhone != phone) throw Exception('मोबाइल नंबर वेरिफाई नहीं हुआ।');
      final user = db.auth.currentUser;
      if (user == null) throw Exception('लॉगिन सेशन उपलब्ध नहीं है।');
      await db.from('ai_call_assistant_settings').upsert({
        'user_id': user.id, 'phone_number': phone, 'sim_slot': _simSlot,
        'enabled': false, 'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      setState(() { _phoneVerified = true; _verifiedPhone = phone; _otpSent = false; _pendingPhone = null; _otp.clear(); _status = 'मोबाइल नंबर वेरिफाई हो गया।'; });
    } catch (error) { if (mounted) setState(() => _status = 'OTP वेरिफाई नहीं हुआ: $error'); }
    finally { if (mounted) setState(() => _verifyingOtp = false); }
  }

  Future<void> _save() async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) {
      setState(() => _status = 'सेटिंग सेव करने के लिए पहले लॉगिन करें।');
      return;
    }
    final phone = _normalisePhone(_phone.text);
    if (phone.isEmpty) {
      setState(() => _status = 'अपना मोबाइल नंबर दर्ज करें।');
      return;
    }
    if (!_disclosureAccepted) {
      setState(() => _status = 'AI पहचान और कॉलर को सूचना देने की सहमति चुनें।');
      return;
    }
    setState(() { _saving = true; _status = null; });
    try {
      await db.from('ai_call_assistant_settings').upsert({
        'user_id': user.id,
        'sim_slot': _simSlot,
        'phone_number': phone,
        'transfer_number': _normalisePhone(_transfer.text),
        'assistant_instructions': _instructions.text.trim(),
        'enabled': false,
        'forwarding_mode': _forwardingMode,
        'disclosure_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'transcript_enabled': _transcriptEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) setState(() => _status = 'आपकी Calling Assistant सेटिंग सुरक्षित रूप से सेव हो गई है।');
    } catch (error) {
      if (mounted) setState(() => _status = 'सेटिंग सेव नहीं हुई: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _statusLabel(String? value) {
    switch (value) {
      case 'completed': return 'पूरी हुई';
      case 'transferred': return 'आपको ट्रांसफर हुई';
      case 'missed': return 'मिस्ड कॉल';
      case 'failed': return 'कनेक्शन विफल';
      case 'answered': return 'AI ने जवाब दिया';
      default: return 'कॉल प्राप्त हुई';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_signedIn) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('AI Calling Assistant सेट करने के लिए Bharat Saathi में लॉगिन करें।'),
      ));
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE0F4F5), Color(0xFFE6EAFE)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.support_agent_rounded, size: 38, color: _teal),
              SizedBox(height: 10),
              Text('आपका AI फोन असिस्टेंट', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _ink)),
              SizedBox(height: 5),
              Text('AI आपकी ओर से आने वाली कॉल संभालेगा, ज़रूरी जानकारी लेगा और ज़रूरत पड़ने पर कॉल आपको ट्रांसफर करेगा।', style: TextStyle(color: Color(0xFF52627D), height: 1.4)),
              SizedBox(height: 10),
              Row(children: [
                Icon(Icons.radio_button_checked, size: 13, color: Colors.orange),
                SizedBox(width: 6),
                Text('टेलीफोनी कनेक्शन सेटअप बाकी है', style: TextStyle(color: Color(0xFF8B5B13), fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('1. अपना नंबर और SIM चुनें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _simSlot,
          decoration: const InputDecoration(labelText: 'किस SIM पर कॉल आती हैं?'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('SIM 1')),
            DropdownMenuItem(value: 2, child: Text('SIM 2')),
          ],
          onChanged: (value) { if (value != null) setState(() => _simSlot = value); },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'आपका मोबाइल नंबर', hintText: '+91XXXXXXXXXX'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _transfer,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'कॉल ट्रांसफर नंबर', hintText: 'खाली छोड़ें तो ऊपर वाला नंबर इस्तेमाल होगा'),
        ),
        const SizedBox(height: 18),
        const Text('2. कॉल फॉरवर्डिंग का तरीका', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _forwardingMode,
          decoration: const InputDecoration(labelText: 'कब AI को कॉल भेजनी है?'),
          items: const [
            DropdownMenuItem(value: 'no_answer', child: Text('जब आप कॉल न उठाएँ')),
            DropdownMenuItem(value: 'busy', child: Text('जब आपका नंबर व्यस्त हो')),
            DropdownMenuItem(value: 'unreachable', child: Text('जब फोन बंद या नेटवर्क से बाहर हो')),
          ],
          onChanged: (value) { if (value != null) setState(() => _forwardingMode = value); },
        ),
        const SizedBox(height: 8),
        const Text('कॉल फॉरवर्डिंग आपके मोबाइल ऑपरेटर के जरिए चालू होगी। अभी ऐप आपके SIM पर कोई कोड अपने-आप नहीं चलाता। सही ऑपरेटर सेटअप मिलने पर ऐप में चरण-दर-चरण निर्देश दिए जाएँगे।', style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.4)),
        const SizedBox(height: 18),
        const Text('3. AI को क्या करना है?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        TextField(
          controller: _instructions,
          minLines: 4,
          maxLines: 7,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'अपने असिस्टेंट को निर्देश दें',
            hintText: 'जैसे: कॉल करने वाले का नाम, पता और कॉल का कारण पूछें। जरूरी काम हो तो मुझे कॉल ट्रांसफर करें।',
            alignLabelWithHint: true,
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _disclosureAccepted,
          onChanged: (value) => setState(() => _disclosureAccepted = value == true),
          title: const Text('AI हर कॉल की शुरुआत में अपनी पहचान बताएगा और कॉलर को जानकारी देगा।', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _transcriptEnabled,
          onChanged: (value) => setState(() => _transcriptEnabled = value == true),
          title: const Text('कॉलर को सूचना/सहमति देने के बाद बातचीत का टेक्स्ट और सारांश सेव करें।', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'सेव हो रहा है...' : 'सेटिंग सेव करें'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.call),
          label: const Text('AI को कॉल करें — टेलीफोनी सेटअप के बाद'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 10),
          Text(_status!, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
        ],
        const SizedBox(height: 22),
        const Text('हाल की कॉल', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 8),
        if (_logs.isEmpty)
          const Text('अभी कोई AI कॉल रिकॉर्ड उपलब्ध नहीं है।', style: TextStyle(color: Colors.blueGrey, fontSize: 12))
        else
          ..._logs.map((log) {
            final name = (log['caller_name']?.toString().trim().isNotEmpty ?? false)
                ? log['caller_name'].toString()
                : (log['caller_number']?.toString().isNotEmpty ?? false)
                    ? log['caller_number'].toString()
                    : 'अनजान कॉलर';
            final summary = log['summary']?.toString().trim() ?? '';
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.call_received)),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(summary.isNotEmpty ? summary : (log['call_reason']?.toString() ?? 'कॉल विवरण उपलब्ध नहीं')),
                trailing: Text(_statusLabel(log['status']?.toString()), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                isThreeLine: true,
                dense: true,
              ),
            );
          }),
        const SizedBox(height: 12),
        const Text('सुरक्षा: AI कभी भी OTP, UPI PIN, बैंक पासवर्ड या कार्ड PIN नहीं माँगेगा। कॉल संभालना तभी शुरू होगा जब टेलीफोनी प्रोवाइडर, OpenAI SIP webhook और कॉल-फॉरवर्डिंग का परीक्षण पूरा होगा।', style: TextStyle(color: Colors.blueGrey, fontSize: 11, height: 1.4)),
      ],
    );
  }
}
