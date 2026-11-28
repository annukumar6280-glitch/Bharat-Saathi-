import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ink=Color(0xFF25345B);

class UtilityModulePage extends StatelessWidget {
  final String kind,title;
  const UtilityModulePage({super.key,required this.kind,required this.title});
  @override Widget build(BuildContext context){
    final Widget page=switch(kind){
      'qr'=>const _QrTool(),
      'poster'=>const _PosterTool(),
      'reminders'=>const _ReminderTool(),
      'calculator'=>const _BusinessCalculator(),
      _=>const _QrTool(),
    };
    return Scaffold(appBar:AppBar(title:Text(title)),body:page);
  }
}

class _QrTool extends StatefulWidget{const _QrTool();@override State<_QrTool> createState()=>_QrToolState();}
class _QrToolState extends State<_QrTool>{
 final input=TextEditingController();final qrKey=GlobalKey();String mode='text';String? scanned;
 @override void dispose(){input.dispose();super.dispose();}
 Future<void> _shareQr()async{
  try{
   final boundary=qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
   if(boundary==null)throw Exception('पहले QR कोड बनाएँ।');
   final image=await boundary.toImage(pixelRatio:3);
   final data=await image.toByteData(format:ui.ImageByteFormat.png);
   if(data==null)throw Exception('QR इमेज तैयार नहीं हुई।');
   await Share.shareXFiles([XFile.fromData(data.buffer.asUint8List(),mimeType:'image/png',name:'bharat-saathi-qr.png')],text:'Bharat Saathi QR Code');
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
 }
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
  SegmentedButton<String>(segments:const [ButtonSegment(value:'text',label:Text('Text / Link')),ButtonSegment(value:'upi',label:Text('UPI QR'))],selected:{mode},onSelectionChanged:(s)=>setState(()=>mode=s.first)),
  const SizedBox(height:14),
  TextField(controller:input,onChanged:(_)=>setState((){}),decoration:InputDecoration(labelText:mode=='upi'?'UPI ID (जैसे name@upi)':'Text या Website URL',hintText:mode=='upi'?'yourname@upi':'https://example.com')),
  const SizedBox(height:16),
  if(input.text.trim().isNotEmpty)Center(child:RepaintBoundary(key:qrKey,child:Container(color:Colors.white,padding:const EdgeInsets.all(14),child:QrImageView(data:mode=='upi'?'upi://pay?pa=${input.text.trim()}&pn=Bharat%20Saathi':input.text.trim(),size:220)))),
  FilledButton(onPressed:()=>setState((){}),child:const Text('QR कोड बनाएँ')),
  OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>_QrScanner(onValue:(v){setState(()=>scanned=v);Navigator.pop(context);}))),icon:const Icon(Icons.qr_code_scanner),label:const Text('QR स्कैन करें')),
  if(scanned!=null)SelectableText('स्कैन परिणाम: $scanned'),
  if(input.text.trim().isNotEmpty)FilledButton.icon(onPressed:_shareQr,icon:const Icon(Icons.download_rounded),label:const Text('QR इमेज डाउनलोड / शेयर करें')),
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
    content:const Text('5 सेकंड के वीडियो पर 50 Bharat Saathi कॉइन खर्च होंगे। Fal AI की अलग लागत लगभग \$0.35 प्रति 5 सेकंड है और आपके Fal खाते से कटेगी; दर बदल सकती है। क्या आप आगे बढ़ना चाहते हैं?'),
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
    ? 'Create a polished short vertical 9:16 silent video. Scene and motion brief: ${brief.text.trim()}. Use cinematic camera movement, coherent motion, professional lighting and a clean composition. If a reference image is supplied, use it as the visual starting reference. Do not add watermarks, fake text, prices or contact details.'
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
    final requestId=data['requestId']?.toString();
    final model=data['model']?.toString();
    if(requestId==null||requestId.isEmpty||model==null||model.isEmpty)throw Exception('AI सर्वर ने वीडियो जॉब ID नहीं लौटाई।');
    String? videoUrl;
    for(var attempt=0;attempt<120;attempt++){
     await Future.delayed(const Duration(seconds:5));
     if(!mounted)return;
     final statusResponse=await Supabase.instance.client.functions.invoke(
      'ai-creative-studio',
      body:{'action':'video_status','generationType':'video','requestId':requestId,'model':model},
     );
     final statusData=statusResponse.data;
     if(statusData is! Map)throw Exception('वीडियो की स्थिति जाँची नहीं जा सकी।');
     if(statusData['error']!=null)throw Exception(statusData['error'].toString());
     final status=statusData['status']?.toString()??'IN_PROGRESS';
     if(status=='COMPLETED'){videoUrl=statusData['videoUrl']?.toString();break;}
     if(status=='FAILED')throw Exception('वीडियो नहीं बन पाया। आपके कॉइन वापस कर दिए गए हैं।');
    }
    if(videoUrl==null||videoUrl.isEmpty)throw Exception('वीडियो अभी प्रोसेस हो रहा है। जॉब सर्वर पर जारी रह सकती है; थोड़ी देर बाद फिर कोशिश करें।');
    final httpClient=HttpClient();
    try{
     final request=await httpClient.getUrl(Uri.parse(videoUrl));
     final videoResponse=await request.close();
     if(videoResponse.statusCode!=200)throw Exception('बनी हुई वीडियो डाउनलोड नहीं हो पाई।');
     final builder=BytesBuilder();
     await for(final chunk in videoResponse){
      builder.add(chunk);
      if(builder.length>100*1024*1024)throw Exception('वीडियो 100 MB से बड़ी है।');
     }
     final bytes=builder.takeBytes();
     if(bytes.isEmpty)throw Exception('AI ने खाली वीडियो लौटाई।');
     final directory=await getTemporaryDirectory();
     final file=File('${directory.path}/bharat-saathi-ai-video.mp4');
     await file.writeAsBytes(bytes,flush:true);
     final controller=VideoPlayerController.file(file);
     await controller.initialize();
     await controller.setLooping(true);
     if(!mounted){await controller.dispose();return;}
     setState(()=>generatedVideo=bytes);
     setState(()=>videoController=controller);
     await controller.play();
    }finally{httpClient.close(force:true);}
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
  SegmentedButton<String>(segments:const [ButtonSegment(value:'image',label:Text('फोटो / पोस्टर'),icon:Icon(Icons.image_outlined)),ButtonSegment(value:'video',label:Text('वीडियो'),icon:Icon(Icons.video_library_outlined))],selected:{generationType},onSelectionChanged:(v)=>setState(()=>generationType=v.first)),
  const SizedBox(height:10),
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
 final title=TextEditingController(),noteTitle=TextEditingController(),noteBody=TextEditingController();
 List<Map<String,dynamic>> items=[],notes=[];
 DateTime due=DateTime.now().add(const Duration(days:1));
 TimeOfDay dueTime=const TimeOfDay(hour:9,minute:0);
 final FlutterLocalNotificationsPlugin _notifications=FlutterLocalNotificationsPlugin();
 bool loading=true,notificationsReady=false;String tab='reminders';String? notificationMessage;int? editingNoteIndex;
 String get _reminderStorageKey=>'bs_reminders_v1_${Supabase.instance.client.auth.currentUser?.id??'guest'}';
 String get _notesStorageKey=>'bs_notes_v1_${Supabase.instance.client.auth.currentUser?.id??'guest'}';
 DateTime get dueAt=>DateTime(due.year,due.month,due.day,dueTime.hour,dueTime.minute);
 @override void initState(){super.initState();_initNotifications();_load();}
 Future<void> _initNotifications()async{
  try{
   tzdata.initializeTimeZones();
   tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
   await _notifications.initialize(settings:const InitializationSettings(android:AndroidInitializationSettings('@mipmap/ic_launcher')));
   if(mounted)setState(()=>notificationsReady=true);
  }catch(_){if(mounted)setState(()=>notificationMessage='इस फोन पर रिमाइंडर नोटिफिकेशन शुरू नहीं हो पाए।');}
 }
 Future<bool> _scheduleReminder(int id,String reminderTitle,DateTime when)async{
  if(!notificationsReady)return false;
  final android=_notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  final permission=await android?.requestNotificationsPermission();
  if(permission==false){if(mounted)setState(()=>notificationMessage='रिमाइंडर सेव है, लेकिन Android Notifications बंद हैं।');return false;}
  await _notifications.zonedSchedule(
   id:id,
   title:'Bharat Saathi • रिमाइंडर',
   body:reminderTitle,
   scheduledDate:tz.TZDateTime.from(when,tz.local),
   notificationDetails:const NotificationDetails(android:AndroidNotificationDetails('bharat_saathi_reminders','Bharat Saathi Reminders',channelDescription:'आपके सेव किए हुए काम और भुगतान की याद दिलाने के लिए।',importance:Importance.high,priority:Priority.high)),
   androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,
  );
  return true;
 }
 @override void dispose(){title.dispose();noteTitle.dispose();noteBody.dispose();super.dispose();}
 Future<void> _load()async{
  final p=await SharedPreferences.getInstance();
  for(final entry in [(_reminderStorageKey,'reminders'),(_notesStorageKey,'notes')]){
   final raw=p.getString(entry.$1);
   if(raw!=null){try{final data=List<Map<String,dynamic>>.from(jsonDecode(raw));if(entry.$2=='reminders'){items=data;}else{notes=data;}}catch(_){}}
  }
  if(mounted)setState(()=>loading=false);
 }
 Future<void> _saveReminders()async{final p=await SharedPreferences.getInstance();await p.setString(_reminderStorageKey,jsonEncode(items));}
 Future<void> _saveNotes()async{final p=await SharedPreferences.getInstance();await p.setString(_notesStorageKey,jsonEncode(notes));}
 Future<void> _editReminder(int index)async{
  final current=items[index];
  final oldDue=DateTime.tryParse(current['due']?.toString()??'')??DateTime.now().add(const Duration(days:1));
  final controller=TextEditingController(text:current['title']?.toString()??'');
  final newTitle=await showDialog<String>(context:context,builder:(context)=>AlertDialog(
   title:const Text('रिमाइंडर बदलें'),
   content:TextField(controller:controller,decoration:const InputDecoration(labelText:'काम / भुगतान की याद')),
   actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('रद्द करें')),FilledButton(onPressed:()=>Navigator.pop(context,controller.text.trim()),child:const Text('आगे'))],
  ));
  controller.dispose();
  if(!mounted)return;
  if(newTitle==null||newTitle.isEmpty)return;
  final pickedDate=await showDatePicker(context:context,initialDate:oldDue.isBefore(DateTime.now())?DateTime.now():oldDue,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:3650)));
  if(!mounted)return;
  if(pickedDate==null)return;
  final pickedTime=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(oldDue));
  if(!mounted)return;
  if(pickedTime==null)return;
  final when=DateTime(pickedDate.year,pickedDate.month,pickedDate.day,pickedTime.hour,pickedTime.minute);
  if(!when.isAfter(DateTime.now())){if(mounted)setState(()=>notificationMessage='भविष्य की तारीख और समय चुनें।');return;}
  final oldId=current['notificationId'];
  if(oldId is int)await _notifications.cancel(id:oldId);
  var id=when.millisecondsSinceEpoch~/1000;
  while(items.asMap().entries.any((e)=>e.key!=index&&e.value['notificationId']==id)){id++;}
  items[index]={'title':newTitle,'due':when.toIso8601String(),'done':false,'notificationId':id};
  await _saveReminders();
  try{final scheduled=await _scheduleReminder(id,newTitle,when);if(mounted)setState(()=>notificationMessage=scheduled?'रिमाइंडर अपडेट और शेड्यूल हो गया।':'रिमाइंडर अपडेट है, लेकिन नोटिफिकेशन की अनुमति नहीं मिली।');}
  catch(_){if(mounted)setState(()=>notificationMessage='रिमाइंडर अपडेट है, लेकिन नोटिफिकेशन शेड्यूल नहीं हो पाया।');}
  if(mounted)setState((){});
 }
 Future<void> _add()async{
  if(title.text.trim().isEmpty)return;
  final when=dueAt;
  if(!when.isAfter(DateTime.now())){if(mounted)setState(()=>notificationMessage='भविष्य की तारीख और समय चुनें।');return;}
  var id=when.millisecondsSinceEpoch~/1000;
  while(items.any((e)=>e['notificationId']==id)){id++;}
  final reminderTitle=title.text.trim();
  items.insert(0,{'title':reminderTitle,'due':when.toIso8601String(),'done':false,'notificationId':id});
  title.clear();await _saveReminders();
  try{final scheduled=await _scheduleReminder(id,reminderTitle,when);if(scheduled&&mounted)setState(()=>notificationMessage='रिमाइंडर सेव और शेड्यूल हो गया।');}
  catch(_){if(mounted)setState(()=>notificationMessage='रिमाइंडर सेव है, लेकिन नोटिफिकेशन शेड्यूल नहीं हो पाया।');}
  if(mounted)setState((){});
 }
 void _editNote(int index){
  final note=notes[index];
  noteTitle.text=note['title']?.toString()??'';
  noteBody.text=note['body']?.toString()??'';
  setState(()=>editingNoteIndex=index);
 }
 Future<void> _addNote()async{
  if(noteTitle.text.trim().isEmpty&&noteBody.text.trim().isEmpty)return;
  final note=<String,dynamic>{'title':noteTitle.text.trim().isEmpty?'नोट':noteTitle.text.trim(),'body':noteBody.text.trim(),'updated':DateTime.now().toIso8601String()};
  if(editingNoteIndex!=null&&editingNoteIndex!<notes.length){notes[editingNoteIndex!]=note;editingNoteIndex=null;}
  else{notes.insert(0,note);}
  noteTitle.clear();noteBody.clear();await _saveNotes();if(mounted)setState((){});
 }
 void _cancelNoteEdit(){noteTitle.clear();noteBody.clear();setState(()=>editingNoteIndex=null);}
 @override Widget build(BuildContext context)=>loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
  SegmentedButton<String>(segments:const [ButtonSegment(value:'reminders',label:Text('रिमाइंडर'),icon:Icon(Icons.notifications_active_outlined)),ButtonSegment(value:'notes',label:Text('नोट्स'),icon:Icon(Icons.sticky_note_2_outlined))],selected:{tab},onSelectionChanged:(v)=>setState(()=>tab=v.first)),
  const SizedBox(height:14),
  if(tab=='reminders')...[
   TextField(controller:title,decoration:const InputDecoration(labelText:'काम / भुगतान की याद')),
   const SizedBox(height:8),
   OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:context,initialDate:due.isBefore(DateTime.now())?DateTime.now():due,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:3650)));if(d!=null)setState(()=>due=d);},icon:const Icon(Icons.calendar_month),label:Text('तारीख: ${due.day}-${due.month}-${due.year}')),
   const SizedBox(height:6),
   OutlinedButton.icon(onPressed:()async{final t=await showTimePicker(context:context,initialTime:dueTime);if(t!=null)setState(()=>dueTime=t);},icon:const Icon(Icons.access_time),label:Text('समय: ${dueTime.format(context)}')),
   FilledButton(onPressed:_add,child:const Text('रिमाइंडर सेव करें')),
   if(notificationMessage!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(notificationMessage!,style:const TextStyle(color:Colors.blueGrey,fontSize:11))),
   const Padding(padding:EdgeInsets.only(top:4),child:Text('Android Notifications की अनुमति माँगी जाएगी। कुछ फोन बैटरी प्रतिबंधों के कारण समय पर नोटिफिकेशन रोक सकते हैं।',style:TextStyle(color:Colors.blueGrey,fontSize:11))),
   const Divider(height:28),
   if(items.isEmpty)const Text('अभी कोई रिमाइंडर नहीं है।'),
   ...items.asMap().entries.map((e){
    final reminderDue=DateTime.parse(e.value['due'].toString()).toLocal();
    return Card(child:CheckboxListTile(
     value:e.value['done'] as bool,
     onChanged:(v)async{
      items[e.key]['done']=v??false;
      final id=items[e.key]['notificationId'];
      if(id is int){
       if(v??false){await _notifications.cancel(id:id);}
       else if(reminderDue.isAfter(DateTime.now())){await _scheduleReminder(id,items[e.key]['title'].toString(),reminderDue);}
      }
      await _saveReminders();setState((){});
     },
     title:Text(e.value['title'].toString()),
     subtitle:Text('${reminderDue.day}-${reminderDue.month}-${reminderDue.year} • ${TimeOfDay.fromDateTime(reminderDue).format(context)}'),
     secondary:Row(mainAxisSize:MainAxisSize.min,children:[
      IconButton(tooltip:'बदलें',onPressed:()=>_editReminder(e.key),icon:const Icon(Icons.edit_outlined)),
      IconButton(tooltip:'हटाएँ',onPressed:()async{final id=e.value['notificationId'];if(id is int)await _notifications.cancel(id:id);items.removeAt(e.key);await _saveReminders();setState((){});},icon:const Icon(Icons.delete_outline)),
     ]),
    ));
   }),
  ]else...[
   TextField(controller:noteTitle,decoration:const InputDecoration(labelText:'नोट का शीर्षक (वैकल्पिक)')),
   const SizedBox(height:8),
   TextField(controller:noteBody,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'अपना नोट लिखें',alignLabelWithHint:true)),
   const SizedBox(height:8),
   Row(children:[Expanded(child:FilledButton.icon(onPressed:_addNote,icon:const Icon(Icons.save_outlined),label:Text(editingNoteIndex==null?'नोट सेव करें':'नोट अपडेट करें'))),if(editingNoteIndex!=null)IconButton(tooltip:'एडिट रद्द करें',onPressed:_cancelNoteEdit,icon:const Icon(Icons.close))]),
   const Divider(height:28),
   if(notes.isEmpty)const Text('अभी कोई नोट सेव नहीं है।'),
   ...notes.asMap().entries.map((e)=>Card(child:ListTile(onTap:()=>_editNote(e.key),title:Text(e.value['title'].toString(),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(e.value['body'].toString(),maxLines:5,overflow:TextOverflow.ellipsis),trailing:IconButton(tooltip:'नोट हटाएँ',onPressed:()async{notes.removeAt(e.key);if(editingNoteIndex==e.key)_cancelNoteEdit();await _saveNotes();if(mounted)setState((){});},icon:const Icon(Icons.delete_outline))))),
  ],
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
 Future<void> _discount()async{
  final controller=TextEditingController();
  final rate=await showDialog<double>(context:context,builder:(context)=>AlertDialog(
   title:const Text('डिस्काउंट प्रतिशत'),
   content:TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'डिस्काउंट %',hintText:'जैसे 10')),
   actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('रद्द करें')),FilledButton(onPressed:(){final v=double.tryParse(controller.text.trim());if(v!=null&&v>=0&&v<=100)Navigator.pop(context,v);},child:const Text('लागू करें'))],
  ));
  controller.dispose();if(rate==null)return;
  final amount=double.tryParse(display);if(amount==null||!amount.isFinite||amount<0)return;
  final finalAmount=amount*(1-rate/100);
  setState((){history.add('Discount ${_fmt(rate)}%: ${_fmt(amount)} → ${_fmt(finalAmount)}');expression='Discount ${_fmt(rate)}%';display=_fmt(finalAmount);first=null;operator=null;fresh=true;});
 }
 Future<void> _profit()async{
  final cost=TextEditingController(),selling=TextEditingController();
  final values=await showDialog<List<double>>(context:context,builder:(context)=>AlertDialog(
   title:const Text('मुनाफा कैलकुलेटर'),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:cost,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'खरीद / लागत राशि (₹)')),
    const SizedBox(height:8),
    TextField(controller:selling,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'बिक्री राशि (₹)')),
   ]),
   actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('रद्द करें')),FilledButton(onPressed:(){final a=double.tryParse(cost.text.trim()),b=double.tryParse(selling.text.trim());if(a!=null&&b!=null&&a>=0&&b>=0)Navigator.pop(context,[a,b]);},child:const Text('गणना करें'))],
  ));
  cost.dispose();selling.dispose();if(values==null)return;
  final profit=values[1]-values[0],margin=values[1]>0?profit/values[1]*100:0.0;
  setState((){history.add('लागत ${_fmt(values[0])}, बिक्री ${_fmt(values[1])}, मुनाफा ${_fmt(profit)}');expression='मुनाफा • Margin ${_fmt(margin)}%';display=_fmt(profit);first=null;operator=null;fresh=true;});
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
   Row(children:[_key('Discount',color:const Color(0xFFE2F1FF),textColor:const Color(0xFF205A9B),onTap:_discount),_key('Profit',color:const Color(0xFFE1F4E9),textColor:const Color(0xFF176B45),onTap:_profit)]),
  ];
  return Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFF1F4FF),Color(0xFFE8E7FF),Color(0xFFE1F6F1)])),child:SafeArea(child:Column(children:[
   Padding(padding:const EdgeInsets.fromLTRB(18,22,18,14),child:Row(children:[const Icon(Icons.calculate_rounded,color:Color(0xFF5D6FC6),size:26),const SizedBox(width:9),const Text('कैलकुलेटर',style:TextStyle(color:_ink,fontSize:20,fontWeight:FontWeight.w900)),const Spacer(),Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:const Text('GST Ready',style:TextStyle(color:Color(0xFF9A6A12),fontWeight:FontWeight.w800,fontSize:11)))])),
   Expanded(child:Container(width:double.infinity,margin:const EdgeInsets.fromLTRB(14,6,14,14),padding:const EdgeInsets.fromLTRB(20,18,20,20),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(26),border:Border.all(color:const Color(0xFFDDE4F5)),boxShadow:const [BoxShadow(color:Color(0x18536FC4),blurRadius:18,offset:Offset(0,7))]),child:Column(mainAxisAlignment:MainAxisAlignment.end,crossAxisAlignment:CrossAxisAlignment.end,children:[if(history.isNotEmpty)SizedBox(height:118,width:double.infinity,child:ListView.builder(reverse:true,itemCount:history.length,itemBuilder:(context,index){final line=history[history.length-1-index];return Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Text(line,textAlign:TextAlign.right,style:const TextStyle(color:Color(0xFF66728D),fontSize:13,fontWeight:FontWeight.w600),maxLines:1,overflow:TextOverflow.ellipsis));})),Text(expression,style:const TextStyle(color:Color(0xFF8993AC),fontSize:16),maxLines:1),const SizedBox(height:12),FittedBox(fit:BoxFit.scaleDown,child:Text(display,style:const TextStyle(color:_ink,fontSize:48,fontWeight:FontWeight.w900)))]))),
   Padding(padding:const EdgeInsets.fromLTRB(10,0,10,14),child:Column(children:rows))
  ])));
 }
}

