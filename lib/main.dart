import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
const supabaseUrl='https://nlfdqkkrwthobvwqfepl.supabase.co';
const supabasePublishableKey='sb_publishable_m7oDiOBmOztXrL93smgRsQ_MQXfbqKk';
const privacyPolicyUrl='https://annukumar6280-glitch.github.io/Bharat-Saathi-/privacy-policy.html';
const termsConditionsUrl='https://annukumar6280-glitch.github.io/Bharat-Saathi-/terms-and-conditions.html';
const termsVersion='1.0';
Future<void> main()async{WidgetsFlutterBinding.ensureInitialized();var ready=false;try{await Supabase.initialize(url:supabaseUrl,publishableKey:supabasePublishableKey);ready=true;}catch(_){}if(!kIsWeb&&(defaultTargetPlatform==TargetPlatform.android||defaultTargetPlatform==TargetPlatform.iOS)){await MobileAds.instance.initialize();}runApp(BharatSaathiApp(supabaseAvailable:ready,requireAuth:true));}

bool bannerAdsEnabled=true;
const String _bannerAdUnitId='ca-app-pub-3940256099942544/6300978111';

class BannerAdSlot extends StatefulWidget{
 const BannerAdSlot({super.key});
 @override State<BannerAdSlot> createState()=>_BannerAdSlotState();
}
class _BannerAdSlotState extends State<BannerAdSlot>{
 BannerAd? _banner;
 bool _loaded=false;
 bool get _supported=>bannerAdsEnabled&&!kIsWeb&&(defaultTargetPlatform==TargetPlatform.android||defaultTargetPlatform==TargetPlatform.iOS);
 @override void initState(){super.initState();if(_supported){final ad=BannerAd(adUnitId:_bannerAdUnitId,size:AdSize.banner,request:const AdRequest(),listener:BannerAdListener(onAdLoaded:(ad){if(mounted)setState(()=>_loaded=true);},onAdFailedToLoad:(ad,error){ad.dispose();if(mounted)setState(()=>_loaded=false);}));_banner=ad;ad.load();}}
 @override void dispose(){_banner?.dispose();super.dispose();}
 @override Widget build(BuildContext context){final ad=_banner;if(!_loaded||ad==null)return const SizedBox.shrink();return Container(width:double.infinity,height:ad.size.height.toDouble(),alignment:Alignment.center,child:AdWidget(ad:ad));}
}

class LocalStore {
 static Database? _db;
 static Future<Database> get database async {
  if(_db!=null)return _db!;
  final root=await getDatabasesPath();
  _db=await openDatabase(p.join(root,'bharat_saathi.db'),version:2,onCreate:(db,version)async{
   await db.execute('CREATE TABLE app_state (user_id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at TEXT NOT NULL)');
   await db.execute('CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  },onUpgrade:(db,oldVersion,newVersion)async{
   if(oldVersion<2){
    await db.execute('ALTER TABLE app_state RENAME TO legacy_app_state');
    await db.execute('CREATE TABLE app_state (user_id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
   }
  });
  return _db!;
 }
 static Future<bool> hasUnassignedLegacyData(String? preferencesLegacy)async{
  final db=await database;
  final marker=await db.query('app_meta',columns:['value'],where:'key = ?',whereArgs:['legacy_data_assigned'],limit:1);
  if(marker.isNotEmpty)return false;
  final oldTable=await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='legacy_app_state'");
  if(oldTable.isNotEmpty){
   final rows=await db.query('legacy_app_state',columns:['payload'],where:'id = ?',whereArgs:[1],limit:1);
   if(rows.isNotEmpty&&rows.first['payload'] is String&&(rows.first['payload'] as String).isNotEmpty)return true;
  }
  return preferencesLegacy!=null&&preferencesLegacy.isNotEmpty;
 }
 static Future<bool> wasLegacyDeclinedForUser(String userId)async{
  final db=await database;
  final rows=await db.query('app_meta',columns:['value'],where:'key = ?',whereArgs:['legacy_declined_$userId'],limit:1);
  return rows.isNotEmpty;
 }
 static Future<void> declineLegacyForUser(String userId)async{
  final db=await database;
  await db.insert('app_meta',{'key':'legacy_declined_$userId','value':'1'},conflictAlgorithm:ConflictAlgorithm.replace);
 }
 static Map<String,dynamic>? _withoutRetiredFields(String? raw){
  if(raw==null||raw.isEmpty)return null;
  try{
   final decoded=jsonDecode(raw);
   if(decoded is! Map)return null;
   final cleaned=Map<String,dynamic>.from(decoded);
   for(final key in const ['products','sales','purchases','supplierLedger','salesReturns','stockAdjustments']){cleaned.remove(key);}
   return cleaned;
  }catch(_){return null;}
 }
 static Future<String?> sanitizeLegacyInventoryData(String? preferencesLegacy)async{
  final db=await database;
  await db.transaction((txn)async{
   final states=await txn.query('app_state',columns:['user_id','payload']);
   for(final row in states){
    final raw=row['payload'] as String?;
    final cleaned=_withoutRetiredFields(raw);
    if(cleaned!=null&&raw!=null&&jsonEncode(cleaned)!=raw){
     await txn.update('app_state',{'payload':jsonEncode(cleaned)},where:'user_id = ?',whereArgs:[row['user_id']]);
    }
   }
   final oldTable=await txn.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='legacy_app_state'");
   if(oldTable.isNotEmpty){
    final rows=await txn.query('legacy_app_state',columns:['id','payload']);
    for(final row in rows){
     final raw=row['payload'] as String?;
     final cleaned=_withoutRetiredFields(raw);
     if(cleaned!=null&&raw!=null&&jsonEncode(cleaned)!=raw){
      await txn.update('legacy_app_state',{'payload':jsonEncode(cleaned)},where:'id = ?',whereArgs:[row['id']]);
     }
    }
   }
  });
  final cleaned=_withoutRetiredFields(preferencesLegacy);
  return cleaned==null?preferencesLegacy:jsonEncode(cleaned);
 }
 static Future<bool> migrateLegacyForUser(String userId,String? preferencesLegacy)async{
  final db=await database;
  return db.transaction((txn)async{
   final marker=await txn.query('app_meta',columns:['value'],where:'key = ?',whereArgs:['legacy_data_assigned'],limit:1);
   if(marker.isNotEmpty)return true;
   String? legacyPayload;
   String? legacyUpdatedAt;
   final oldTable=await txn.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='legacy_app_state'");
   if(oldTable.isNotEmpty){
    final rows=await txn.query('legacy_app_state',columns:['payload','updated_at'],where:'id = ?',whereArgs:[1],limit:1);
    if(rows.isNotEmpty){final oldPayload=rows.first['payload'] as String?;if(oldPayload!=null&&oldPayload.isNotEmpty)legacyPayload=oldPayload;legacyUpdatedAt=rows.first['updated_at'] as String?;}
   }
   legacyPayload??=(preferencesLegacy!=null&&preferencesLegacy.isNotEmpty?preferencesLegacy:null);
   if(legacyPayload!=null){
    final existing=await txn.query('app_state',columns:['user_id'],where:'user_id = ?',whereArgs:[userId],limit:1);
    if(existing.isNotEmpty){
     await txn.insert('app_meta',{'key':'legacy_declined_$userId','value':'1'},conflictAlgorithm:ConflictAlgorithm.replace);
     return false;
    }
    await txn.insert('app_state',{'user_id':userId,'payload':legacyPayload,'updated_at':legacyUpdatedAt??DateTime.now().toUtc().toIso8601String()},conflictAlgorithm:ConflictAlgorithm.abort);
   }
   if(oldTable.isNotEmpty)await txn.execute('DROP TABLE legacy_app_state');
   await txn.insert('app_meta',{'key':'legacy_data_assigned','value':'1'},conflictAlgorithm:ConflictAlgorithm.replace);
   await txn.delete('app_meta',where:'key = ?',whereArgs:['legacy_declined_$userId']);
   return true;
  });
 }
 static Future<String?> read(String userId)async{
  final db=await database;
  final rows=await db.query('app_state',columns:['payload'],where:'user_id = ?',whereArgs:[userId],limit:1);
  return rows.isEmpty?null:rows.first['payload'] as String;
 }
 static Future<DateTime?> readUpdatedAt(String userId)async{
  final db=await database;
  final rows=await db.query('app_state',columns:['updated_at'],where:'user_id = ?',whereArgs:[userId],limit:1);
  if(rows.isEmpty)return null;
  return DateTime.tryParse(rows.first['updated_at'] as String);
 }
 static Future<void> clear([String? userId])async{
  final db=await database;
  if(userId==null){
   await db.delete('app_state');
   await db.delete('app_meta');
   final oldTable=await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='legacy_app_state'");
   if(oldTable.isNotEmpty)await db.delete('legacy_app_state');
  }else{
   await db.delete('app_state',where:'user_id = ?',whereArgs:[userId]);
  }
 }
 static Future<void> write(String userId,String payload)async{
  final db=await database;
  await db.transaction((txn)async{
   await txn.insert('app_state',{'user_id':userId,'payload':payload,'updated_at':DateTime.now().toUtc().toIso8601String()},conflictAlgorithm:ConflictAlgorithm.replace);
  });
 }
}
final ValueNotifier<bool> appDarkMode=ValueNotifier<bool>(false);
final ValueNotifier<int> homeTabRequest=ValueNotifier<int>(0);
bool get darkModeEnabled=>appDarkMode.value;
Color get navy=>darkModeEnabled?Color(0xFFE5EEFF):Color(0xFF14233B);
Color get blue=>darkModeEnabled?Color(0xFF8FB8F0):Color(0xFF29496D);
Color get gold=>Color(0xFFF2A93B);
Color get bg=>darkModeEnabled?Color(0xFF26364D):Color(0xFFE7EBF1);
Color get muted=>darkModeEnabled?Color(0xFFA9B8CC):Color(0xFF788596);
Color get green=>darkModeEnabled?Color(0xFF62C99A):Color(0xFF16845B);
Color get red=>darkModeEnabled?Color(0xFFFF8585):Color(0xFFD95454);
Color get surfaceColor=>darkModeEnabled?Color(0xFF17263B):Colors.white;
Color get appBgColor=>darkModeEnabled?Color(0xFF0D1728):Color(0xFFF4F6FB);
Color get borderColor=>darkModeEnabled?Color(0xFF30435D):Color(0xFFE1E7F0);
ThemeData buildAppTheme(bool dark){
 final scheme=ColorScheme.fromSeed(seedColor:dark?const Color(0xFF6FA4E8):const Color(0xFF29496D),brightness:dark?Brightness.dark:Brightness.light).copyWith(primary:dark?const Color(0xFF9CC3FF):const Color(0xFF14233B),secondary:dark?const Color(0xFF64C9C1):const Color(0xFF168C86),surface:dark?const Color(0xFF17263B):const Color(0xFFF8FAFD),onSurface:dark?const Color(0xFFE5EEFF):const Color(0xFF14233B));
 return ThemeData(useMaterial3:true,brightness:dark?Brightness.dark:Brightness.light,scaffoldBackgroundColor:dark?const Color(0xFF0D1728):const Color(0xFFF4F6FB),colorScheme:scheme,appBarTheme:AppBarTheme(backgroundColor:dark?const Color(0xFF0D1728):const Color(0xFFF4F6FB),foregroundColor:dark?const Color(0xFFE5EEFF):const Color(0xFF14233B),elevation:0,centerTitle:false),cardTheme:CardThemeData(color:dark?const Color(0xFF17263B):Colors.white),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:dark?const Color(0xFF17263B):Colors.white,contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:14),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide(color:dark?const Color(0xFF30435D):const Color(0xFFE1E7F0))),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide(color:dark?const Color(0xFF30435D):const Color(0xFFE1E7F0))),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:const BorderSide(color:Color(0xFF6FA4E8),width:1.5))),filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:dark?const Color(0xFF315A8A):const Color(0xFF14233B),foregroundColor:Colors.white,minimumSize:const Size(0,48),padding:const EdgeInsets.symmetric(horizontal:18,vertical:13),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))),outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(foregroundColor:dark?const Color(0xFFE5EEFF):const Color(0xFF14233B),minimumSize:const Size(0,46),side:BorderSide(color:dark?const Color(0xFF526985):const Color(0xFFCCD6E4)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))),snackBarTheme:const SnackBarThemeData(behavior:SnackBarBehavior.floating));
}
class BharatSaathiApp extends StatelessWidget{
 final bool supabaseAvailable,requireAuth;
 const BharatSaathiApp({super.key,this.supabaseAvailable=false,this.requireAuth=false});
 @override Widget build(BuildContext context)=>ValueListenableBuilder<bool>(
  valueListenable:appDarkMode,
  builder:(context,isDark,_)=>MaterialApp(
   title:'Bharat Saathi',debugShowCheckedModeBanner:false,
   theme:buildAppTheme(false),darkTheme:buildAppTheme(true),
   themeMode:isDark?ThemeMode.dark:ThemeMode.light,
   home:requireAuth?AuthGate(supabaseAvailable:supabaseAvailable):RetailerHome(supabaseAvailable:supabaseAvailable)
  )
 );
}
class AuthGate extends StatefulWidget{
 final bool supabaseAvailable;
 const AuthGate({super.key,required this.supabaseAvailable});
 @override State<AuthGate> createState()=>_AuthGateState();
}
class _AuthGateState extends State<AuthGate>{
 bool _signedIn=false;
 StreamSubscription<AuthState>? _authSubscription;
 @override void initState(){
  super.initState();
  if(widget.supabaseAvailable){
   _signedIn=Supabase.instance.client.auth.currentSession!=null;
   _authSubscription=Supabase.instance.client.auth.onAuthStateChange.listen((state){
    if(mounted)setState(()=>_signedIn=state.session!=null);
   },onError:(Object error,StackTrace stackTrace){
    if(mounted&&Supabase.instance.client.auth.currentSession==null)setState(()=>_signedIn=false);
   });
  }
 }
 @override void dispose(){_authSubscription?.cancel();super.dispose();}
 @override Widget build(BuildContext context){
  if(!widget.supabaseAvailable)return const AuthPage(supabaseAvailable:false);
  return _signedIn?RetailerHome(key:ValueKey(widget.supabaseAvailable?Supabase.instance.client.auth.currentUser?.id:'local'),supabaseAvailable:widget.supabaseAvailable):AuthPage(supabaseAvailable:widget.supabaseAvailable);
 }
}
class Record{String name,detail;double amount;IconData icon;DateTime? createdAt;Record(this.name,this.detail,this.amount,this.icon,[DateTime? timestamp]):createdAt=timestamp??DateTime.now();Map<String,dynamic> toJson()=>{'name':name,'detail':detail,'amount':amount,'icon':icon.codePoint,'createdAt':createdAt?.toIso8601String()};factory Record.fromJson(Map<String,dynamic> j){final timestamp=j['createdAt'] is String?DateTime.tryParse(j['createdAt'] as String):null;return Record(j['name'] as String,j['detail'] as String,(j['amount'] as num).toDouble(),Icons.receipt_long,timestamp)..createdAt=timestamp;}}
class RetailerHome extends StatefulWidget{final bool supabaseAvailable;const RetailerHome({super.key,this.supabaseAvailable=false});@override State<RetailerHome> createState()=>_RetailerHomeState();}
class _RetailerHomeState extends State<RetailerHome> with WidgetsBindingObserver{
 Timer? _autoSyncDebounce;
 Timer? _autoSyncRetry;
 bool _cloudSyncBusy=false;
 int tab=0;double cash=0,expenses=0,personalBudget=0;String personalBudgetName='व्यक्तिगत खर्च सीमा';bool loaded=false,english=false,darkMode=false;
 final _prefs=SharedPreferencesAsync();
 late final String _localUserId;

 final expensesList=<Record>[];
 final personalTransactions=<Record>[];
 final personalKhata=<Record>[];
 final khata=<Record>[];
final serviceTransactions=<Record>[];
 @override void initState(){super.initState();_localUserId=widget.supabaseAvailable?(Supabase.instance.client.auth.currentUser?.id??'local'):'local';WidgetsBinding.instance.addObserver(this);homeTabRequest.addListener(_returnToHomeTab);_autoSyncRetry=Timer.periodic(const Duration(seconds:60),(_)=>_syncCloudNow());_restore();}
  void _returnToHomeTab(){if(mounted&&tab!=0)setState(()=>tab=0);}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)_syncCloudNow();}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);homeTabRequest.removeListener(_returnToHomeTab);_autoSyncDebounce?.cancel();_autoSyncRetry?.cancel();super.dispose();}
  void _scheduleCloudSync(){if(!widget.supabaseAvailable||Supabase.instance.client.auth.currentUser==null)return;_autoSyncDebounce?.cancel();_autoSyncDebounce=Timer(const Duration(seconds:3),_syncCloudNow);}
  Future<void> _uploadCloudSnapshot(User user,String raw,DateTime localUpdatedAt)async{
   final decoded=jsonDecode(raw);
   if(decoded is! Map<String,dynamic>)throw const FormatException('स्थानीय रिकॉर्ड का प्रारूप सही नहीं है।');
   for(final key in const ['products','sales','purchases','supplierLedger','salesReturns','stockAdjustments']){decoded.remove(key);}
   await Supabase.instance.client.from('user_backups').upsert({'user_id':user.id,'payload':decoded,'schema_version':1,'updated_at':localUpdatedAt.toUtc().toIso8601String()});
  }
  Future<String?> _reconcileCloudSnapshot(String? raw)async{
   final user=widget.supabaseAvailable?Supabase.instance.client.auth.currentUser:null;
   if(user==null)return raw;
   final client=Supabase.instance.client;
   final row=await client.from('user_backups').select('payload,schema_version,updated_at').eq('user_id',user.id).maybeSingle();
   if(row==null){if(raw!=null){final localAt=await LocalStore.readUpdatedAt(user.id);if(localAt!=null)await _uploadCloudSnapshot(user,raw,localAt);}return raw;}
   if((row['schema_version'] as num?)?.toInt()!=1)return raw;
   final remoteAt=DateTime.tryParse(row['updated_at'] as String? ?? '');
   final localAt=await LocalStore.readUpdatedAt(user.id);
   if(raw==null||(remoteAt!=null&&(localAt==null||remoteAt.isAfter(localAt)))){
    raw=jsonEncode(row['payload']);
    await LocalStore.write(user.id,raw);
    return raw;
   }
   if(localAt!=null&&(remoteAt==null||localAt.isAfter(remoteAt)))await _uploadCloudSnapshot(user,raw,localAt);
   return raw;
  }
  Future<void> _syncCloudNow()async{
   if(_cloudSyncBusy||!mounted||!widget.supabaseAvailable)return;
   final user=Supabase.instance.client.auth.currentUser;if(user==null)return;
   _cloudSyncBusy=true;
   try{
    final before=await LocalStore.read(user.id);
    if(before==null){_cloudSyncBusy=false;return;}
    final beforeAt=await LocalStore.readUpdatedAt(user.id);
    final resolved=await _reconcileCloudSnapshot(before);
    if(resolved!=before){await _restore(syncCloud:false);}
    else{
     final afterAt=await LocalStore.readUpdatedAt(user.id);
     if(afterAt!=null&&beforeAt!=null&&afterAt.isAfter(beforeAt))_scheduleCloudSync();
    }
   }catch(_){
    // Keep the local copy. The periodic and foreground retry will try again.
   }finally{_cloudSyncBusy=false;}
  }
 Future<void> _restore({bool syncCloud=true})async{
  if(mounted)setState(()=>loaded=false);
  cash=0;expenses=0;personalBudget=0;personalBudgetName='व्यक्तिगत खर्च सीमा';
  expensesList.clear();khata.clear();personalTransactions.clear();serviceTransactions.clear();
  var shouldSanitizeSnapshot=false;
  try{
   final userId=_localUserId;
   var legacyPrefs=await _prefs.getString('bharat_saathi_store_v1').timeout(const Duration(seconds:2));
   legacyPrefs=await LocalStore.sanitizeLegacyInventoryData(legacyPrefs);
   if(legacyPrefs!=null)await _prefs.setString('bharat_saathi_store_v1',legacyPrefs);
   final legacyDeclined=await LocalStore.wasLegacyDeclinedForUser(userId);
   final hasLegacy=await LocalStore.hasUnassignedLegacyData(legacyPrefs);
   if(hasLegacy&&!legacyDeclined&&widget.supabaseAvailable){
    if(!mounted)return;
    final importLegacy=await showDialog<bool>(context:context,barrierDismissible:false,builder:(dialogContext)=>AlertDialog(
     title:const Text('पुराने डेटा की पहचान / Legacy data found'),
     content:const Text('इस फोन में पिछले संस्करण के रिकॉर्ड मिले हैं। उन्हें केवल उसी अकाउंट में जोड़ें जो पहले इस फोन पर इस्तेमाल होता था। अगर यह दूसरा अकाउंट है, तो “अभी नहीं” चुनें। पुराना डेटा किसी दूसरे अकाउंट में अपने-आप नहीं जाएगा।\n\nLegacy records from an earlier app version were found. Import them only into the account that previously used this phone. Choose “Not now” if this is a different account. The data will not be assigned automatically to another account.'),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('अभी नहीं / Not now')),
      TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('इस अकाउंट में नहीं जोड़ें / Do not add')),
      FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('इसी अकाउंट में जोड़ें / Add to this account')),
     ],
    ));
    if(!mounted)return;
    if(importLegacy==true){
     final migrated=await LocalStore.migrateLegacyForUser(userId,legacyPrefs);
     if(migrated&&legacyPrefs!=null)await _prefs.remove('bharat_saathi_store_v1');
     if(!migrated){
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(
       title:const Text('पुराना डेटा अभी नहीं जोड़ा गया / Legacy data not imported'),
       content:const Text('इस अकाउंट में पहले से रिकॉर्ड हैं। उन्हें सुरक्षित रखने के लिए पुराने रिकॉर्ड से बदला नहीं गया। पुराना डेटा अलग रखा गया है; दूसरे सही अकाउंट से लॉगिन करके उसे जोड़ सकते हैं।\n\nThis account already has records. They were not overwritten. The older snapshot remains separate and can be assigned to another correct account.'),
       actions:[FilledButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('ठीक है / OK'))],
      ));
     }
    }else if(importLegacy==false){
     await LocalStore.declineLegacyForUser(userId);
    }
   }else if(!legacyDeclined&&!hasLegacy){
    final migrated=await LocalStore.migrateLegacyForUser(userId,legacyPrefs);
    if(migrated&&legacyPrefs!=null)await _prefs.remove('bharat_saathi_store_v1');
   }
   var raw=await LocalStore.read(userId).timeout(const Duration(seconds:2));
   if(syncCloud)raw=await _reconcileCloudSnapshot(raw);
   if(raw!=null){final d=jsonDecode(raw) as Map<String,dynamic>;cash=(d['cash'] as num?)?.toDouble()??0;expenses=(d['expenses'] as num?)?.toDouble()??0;personalBudget=(d['personalBudget'] as num?)?.toDouble()??0;personalBudgetName=(d['personalBudgetName'] as String?)??'व्यक्तिगत खर्च सीमा';english=(d['language'] as String?)=='en';darkMode=(d['darkMode'] as bool?)??false;appDarkMode.value=darkMode;personalKhata.addAll((d['personalKhata'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));expensesList.addAll((d['expensesList'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));khata.addAll((d['khata'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));personalTransactions.addAll((d['personalTransactions'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));serviceTransactions.addAll((d['serviceTransactions'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));shouldSanitizeSnapshot=true;}
  }catch(_){}
  if(mounted)setState(()=>loaded=true);
  if(shouldSanitizeSnapshot){await _persist();}else if(syncCloud){_scheduleCloudSync();}
 }
 Future<void> _persist()async{try{await LocalStore.write(_localUserId,jsonEncode({'cash':cash,'expenses':expenses,'personalBudget':personalBudget,'personalBudgetName':personalBudgetName,'expensesList':expensesList.map((e)=>e.toJson()).toList(),'khata':khata.map((e)=>e.toJson()).toList(),'personalTransactions':personalTransactions.map((e)=>e.toJson()).toList(),'personalKhata':personalKhata.map((e)=>e.toJson()).toList(),'language':english?'en':'hi','darkMode':darkMode,'serviceTransactions':serviceTransactions.map((e)=>e.toJson()).toList()}));_scheduleCloudSync();}catch(_){if(mounted)msg('डेटा इस डिवाइस पर डेटाबेस में सेव नहीं हो पाया');}}
 void msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),behavior:SnackBarBehavior.floating));
 Future<void> form(String title,String label,String valueLabel,void Function(String,double) save)async{
 final n=TextEditingController(),v=TextEditingController();
 await showModalBottomSheet<void>(context:context,isScrollControlled:true,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),builder:(c)=>Padding(padding:EdgeInsets.fromLTRB(20,22,20,20+MediaQuery.of(c).viewInsets.bottom),child:Column(mainAxisSize:MainAxisSize.min,children:[
 Text(title,style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),SizedBox(height:16),
 TextField(controller:n,decoration:InputDecoration(labelText:label,prefixIcon:const Icon(Icons.edit_outlined))),
 const SizedBox(height:10),TextField(controller:v,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:valueLabel,prefixIcon:const Icon(Icons.currency_rupee))),
 SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton(style:FilledButton.styleFrom(backgroundColor:navy,padding:EdgeInsets.all(15)),onPressed:(){final a=double.tryParse(v.text);if(n.text.trim().isEmpty||a==null||a<=0){msg('सही जानकारी भरें');return;}save(n.text.trim(),a);Navigator.pop(c);},child:Text('सेव करें')))
 ])));
 }
 Future<void> expense()=>form('खर्च दर्ज करें','खर्च का विवरण','खर्च राशि (₹)',(n,a){setState((){expenses+=a;cash-=a;expensesList.insert(0,Record(n,'खर्च • अभी',a,Icons.payments_outlined));});_persist();msg('खर्च इस डिवाइस पर सेव हुआ');});
 Future<void> entry([bool payment=false])=>form(payment?'भुगतान दर्ज करें':'खाता एंट्री','ग्राहक का नाम',payment?'भुगतान राशि (₹)':'उधार राशि (₹)',(n,a){final outstanding=khata.where((e)=>e.name.toLowerCase()==n.toLowerCase()).fold<double>(0,(sum,e)=>sum+e.amount);if(payment&&(outstanding<=0||a>outstanding)){msg(outstanding<=0?'इस ग्राहक का बकाया उपलब्ध नहीं है':'भुगतान बकाया राशि से अधिक नहीं हो सकता');return;}setState((){khata.insert(0,Record(n,payment?'भुगतान • अभी':'उधार • अभी',payment?-a:a,payment?Icons.payments_outlined:Icons.person));if(payment)cash+=a;});_persist();msg('खाता रिकॉर्ड इस डिवाइस पर सेव हुआ');});

 Future<void> personalLoanEntry([bool payment=false])=>form(payment?'वापसी दर्ज करें':'उधार दर्ज करें','व्यक्ति का नाम',payment?'वापसी राशि (₹)':'उधार राशि (₹)',(n,a){
 final due=personalKhata.where((e)=>e.name.toLowerCase()==n.toLowerCase()).fold<double>(0,(sum,e)=>sum+e.amount);
 if(payment&&(due<=0||a>due)){msg('वापसी बकाया से अधिक नहीं हो सकती');return;}
 setState(()=>personalKhata.insert(0,Record(n,payment?'पैसा वापस मिला':'उधार दिया',payment?-a:a,Icons.people_outline)));
 _persist();msg('पर्सनल उधार सेव हुआ');
 });

 void setPersonalBudget()=>form('खर्च सीमा सेट करें','सीमा का नाम','अधिकतम राशि (₹)',(n,a){setState((){personalBudget=a;personalBudgetName=n;});_persist();msg('खर्च सीमा सेव हुई');});
 void personalEntry(bool income)=>form(income?'व्यक्तिगत आय दर्ज करें':'व्यक्तिगत खर्च दर्ज करें',income?'आय का स्रोत':'खर्च का विवरण',income?'आय राशि (₹)':'खर्च राशि (₹)',(n,a){setState(()=>personalTransactions.insert(0,Record(n,income?'आय • अभी':'खर्च • अभी',income?a:-a,income?Icons.trending_up:Icons.payments_outlined)));_persist();msg('व्यक्तिगत रिकॉर्ड इस डिवाइस पर सेव हुआ');});
 @override Widget build(BuildContext context){
 final currentUser=widget.supabaseAvailable?Supabase.instance.client.auth.currentUser:null;
 final metadataName=currentUser?.userMetadata?['full_name'];
 final accountName=metadataName is String&&metadataName.trim().isNotEmpty?metadataName.trim():(currentUser?.email?.split('@').first??'').trim();
 final pages=<Widget>[
  Dashboard(english:english,supabaseAvailable:widget.supabaseAvailable,accountName:accountName,onWallet:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CommerceWalletPage(supabaseAvailable:widget.supabaseAvailable))),shopDue:khata.fold<double>(0,(s,e)=>s+e.amount),personalDue:personalKhata.fold<double>(0,(s,e)=>s+e.amount),monthExpense:expensesList.where((e)=>e.createdAt!=null&&e.createdAt!.year==DateTime.now().year&&e.createdAt!.month==DateTime.now().month).fold<double>(0,(s,e)=>s+e.amount),onKhata:()=>setState(()=>tab=1),onDocument:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const BillListPage())),onExpense:()=>setState(()=>tab=2),onRecharge:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ServiceCategoryPage(kind:'recharge',english:english))),onBills:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ServiceCategoryPage(kind:'bills',english:english))),onChallan:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ServiceCategoryPage(kind:'challan',english:english))),onInsurance:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ServiceCategoryPage(kind:'insurance',english:english)))),
  KhataHubPage(shop:khata,personal:personalKhata,onShop:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LocalLedgerPage(title:'दुकानदार का खाता',items:khata,onCredit:()=>entry(),onPayment:()=>entry(true)))),onPersonal:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LocalLedgerPage(title:'पर्सनल उधार',items:personalKhata,onCredit:()=>personalLoanEntry(),onPayment:()=>personalLoanEntry(true)))),onLinked:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LinkedKhataPage(supabaseAvailable:widget.supabaseAvailable)))),
  ExpenseOnlyPage(items:expensesList,onAdd:expense),
  TransactionHistoryPage(items:serviceTransactions,english:english),
   ProfilePage(supabaseAvailable:widget.supabaseAvailable,onRestore:_restore,english:english,darkMode:darkMode,onDarkMode:(v){setState(()=>darkMode=v);appDarkMode.value=v;_persist();},onLanguage:(v){setState(()=>english=v);_persist();},expensesList:expensesList,khata:khata,personalTransactions:personalTransactions)
 ];
 return Scaffold(appBar:AppBar(titleSpacing:17,backgroundColor:appBgColor,foregroundColor:navy,title:Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(12)),child:Icon(Icons.account_balance_wallet,color:gold)),SizedBox(width:10),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(english?'Bharat Saathi':'भारत साथी',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text(english?'Smart Khata & Expenses':'स्मार्ट खाता और खर्च',style:TextStyle(fontSize:10,color:muted))])]),actions:[IconButton(onPressed:()=>setState(()=>tab=4),icon:Icon(Icons.person_outline))]),body:SafeArea(child:loaded?Column(children:[if(tab==3)const BannerAdSlot(),Expanded(child:IndexedStack(index:tab,children:pages))]):Center(child:CircularProgressIndicator())),bottomNavigationBar:Column(mainAxisSize:MainAxisSize.min,children:[if(tab==1||tab==2||tab==4)const BannerAdSlot(),NavigationBar(height:68,backgroundColor:surfaceColor,indicatorColor:darkMode?Color(0xFF29496D):Color(0xFFE8EEF6),selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:[NavigationDestination(icon:Icon(Icons.home_outlined),label:english?'Home':'होम'),NavigationDestination(icon:Icon(Icons.menu_book_outlined),label:english?'Khata':'खाता'),NavigationDestination(icon:Icon(Icons.payments_outlined),label:english?'Expenses':'खर्च'),NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:english?'History':'इतिहास'),NavigationDestination(icon:Icon(Icons.person_outline),label:english?'Profile':'प्रोफाइल')]) ]));
 }
 Widget fab(String s,VoidCallback f)=>FloatingActionButton.extended(onPressed:f,backgroundColor:navy,foregroundColor:Colors.white,icon:Icon(Icons.add),label:Text(s));
}

class HomeServiceWalletCard extends StatelessWidget{
 final bool supabaseAvailable,english;final VoidCallback onTap;
 const HomeServiceWalletCard({super.key,required this.supabaseAvailable,required this.onTap,required this.english});
 @override Widget build(BuildContext context)=>Material(color:Colors.transparent,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(19),child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF176B72),Color(0xFF203F69)]),borderRadius:BorderRadius.circular(19),boxShadow:[BoxShadow(color:const Color(0xFF173B5B).withValues(alpha:.13),blurRadius:16,offset:const Offset(0,7))]),child:Row(children:[
  const Icon(Icons.account_balance_wallet_rounded,color:Color(0xFFFFD58A),size:25),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text(english?'Commission Wallet':'कमीशन वॉलेट',style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900)),
   const SizedBox(height:4),Text(english?'Your service and referral earnings':'आपकी सेल्फ और रेफरल कमीशन की कमाई',style:const TextStyle(color:Colors.white70,fontSize:11)),
   const SizedBox(height:5),Text(english?'Use earned commission as a discount on services':'कमाई हुई कमीशन राशि अगली सर्विस पर छूट बनेगी',style:const TextStyle(color:Color(0xFFFFD58A),fontSize:10,fontWeight:FontWeight.w700))
  ])),const Icon(Icons.chevron_right,color:Colors.white70)
 ]))));
}

class Dashboard extends StatelessWidget{
 final bool english,supabaseAvailable;final String accountName;final double shopDue,personalDue,monthExpense;final VoidCallback onKhata,onDocument,onExpense,onRecharge,onBills,onChallan,onInsurance,onWallet;
 const Dashboard({super.key,required this.english,required this.supabaseAvailable,required this.accountName,required this.onWallet,required this.shopDue,required this.personalDue,required this.monthExpense,required this.onKhata,required this.onDocument,required this.onExpense,required this.onRecharge,required this.onBills,required this.onChallan,required this.onInsurance});
 @override Widget build(BuildContext context)=>Container(
  color:appBgColor,
  child:ListView(padding:const EdgeInsets.fromLTRB(16,14,16,24),children:[
   Container(padding:const EdgeInsets.fromLTRB(18,20,18,20),decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF142B49),Color(0xFF294D73)]),borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(accountName.isNotEmpty?(english?'Account: $accountName':'खाता: $accountName'):(english?'Your account':'आपका खाता'),style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900),maxLines:2,overflow:TextOverflow.ellipsis),
    const SizedBox(height:5),
    Text(english?'Your daily business at a glance':'आपके रोज़ के कारोबार का साफ़ और आसान हिसाब',style:const TextStyle(color:Color(0xFFD5DFEA),fontSize:12))
   ])),
   const SizedBox(height:14),
   GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.52,children:[
    _tile(english?'Khata Book':'खाता बुक',english?'Shop and personal ledger':'दुकान और पर्सनल हिसाब',Icons.menu_book_rounded,const Color(0xFFE8F0FF),onKhata),
    _tile(english?'Bill / Item List':'बिल / सामान लिस्ट',english?'Create bill or shopping list':'बिल या सामान की पर्ची बनाएँ',Icons.receipt_long_rounded,const Color(0xFFFFF2DE),onDocument)
   ]),
   const SizedBox(height:14),
   HomeServiceWalletCard(supabaseAvailable:supabaseAvailable,onTap:onWallet,english:english),
   const SizedBox(height:20),
   Row(children:[Expanded(child:Text(english?'Services':'मुख्य सेवाएँ',style:TextStyle(color:navy,fontSize:18,fontWeight:FontWeight.w900))),Text(english?'Quick access':'आसान पहुँच',style:TextStyle(color:muted,fontSize:11))]),
   const SizedBox(height:12),
   GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.52,children:[
    _tile(english?'Mobile Recharge':'मोबाइल रिचार्ज',english?'Prepaid and postpaid':'प्रीपेड और पोस्टपेड',Icons.phone_android_rounded,const Color(0xFFE6F7F0),onRecharge),
    _tile(english?'Bill Payment':'बिल पेमेंट',english?'Electricity, gas and more':'बिजली, गैस और दूसरे बिल',Icons.receipt_long_rounded,const Color(0xFFFFF2DE),onBills),
    _tile(english?'Challan Payment':'चालान पेमेंट',english?'Traffic challan services':'ट्रैफिक चालान सुविधा',Icons.local_police_rounded,const Color(0xFFF1EAFE),onChallan),
    _tile(english?'Bike / Car Insurance':'बाइक / कार इंश्योरेंस',english?'Vehicle insurance':'वाहन बीमा सेवा',Icons.directions_car_filled_rounded,const Color(0xFFE8F0FF),onInsurance)
   ]),
   const SizedBox(height:12),
   Text(english?'Recharge, bill, challan and insurance services are being connected.':'रिचार्ज, बिल, चालान और इंश्योरेंस सेवाओं को जोड़ा जा रहा है।',style:TextStyle(color:muted,fontSize:10))
  ])
 );
 Widget _tile(String title,String subtitle,IconData icon,Color iconBg,VoidCallback tap)=>Material(color:surfaceColor,borderRadius:BorderRadius.circular(17),child:InkWell(onTap:tap,borderRadius:BorderRadius.circular(17),child:Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(borderRadius:BorderRadius.circular(17),border:Border.all(color:borderColor),boxShadow:darkModeEnabled?[BoxShadow(color:Colors.black.withValues(alpha:.16),blurRadius:10,offset:const Offset(0,4))]:[]),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Container(width:44,height:44,decoration:BoxDecoration(color:darkModeEnabled?const Color(0xFF233D5B):iconBg,borderRadius:BorderRadius.circular(13),border:Border.all(color:darkModeEnabled?const Color(0xFF385779):borderColor)),child:Icon(icon,color:darkModeEnabled?const Color(0xFF9CCBFF):navy,size:25)),
  Spacer(),Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:navy,fontWeight:FontWeight.w900,fontSize:13)),SizedBox(height:3),Text(subtitle,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:muted,fontSize:10))
 ]))));
}
double calculateBillLineTotal(double quantity,double unitPrice)=>quantity*unitPrice;
double calculateBillTotal(Iterable<double> lineTotals)=>lineTotals.fold<double>(0,(sum,value)=>sum+value);

class BillListPage extends StatefulWidget{
 const BillListPage({super.key});
 @override State<BillListPage> createState()=>_BillListPageState();
}
class _BillListPageState extends State<BillListPage>{
 final _name=TextEditingController(),_phone=TextEditingController();
 final List<_BillRow> _rows=[_BillRow()];
 String _mode='bill';bool _started=false,_pdfBusy=false;
 static const Map<String,String> _units={'kg':'किलो','g':'ग्राम','packet':'पैकेट','piece':'पीस'};
 @override void initState(){super.initState();_watch(_rows.first);}
 void _watch(_BillRow r){r.item.addListener(_refresh);r.qty.addListener(_refresh);r.price.addListener(_refresh);}
 void _refresh(){if(mounted)setState((){});}
 @override void dispose(){_name.dispose();_phone.dispose();for(final r in _rows)r.dispose();super.dispose();}
 double _qty(_BillRow r)=>double.tryParse(r.qty.text.trim())??0;
 double _price(_BillRow r)=>double.tryParse(r.price.text.trim())??0;
 double _lineTotal(_BillRow r)=>calculateBillLineTotal(_qty(r),_price(r));
 String? _validateRows(){if(_validRows.isEmpty)return 'कम से कम एक सामान का नाम भरें।';for(var i=0;i<_rows.length;i++){final r=_rows[i];if(r.item.text.trim().isEmpty)continue;final q=double.tryParse(r.qty.text.trim());if(q==null||!q.isFinite||q<=0)return 'सामान ${i+1} की मात्रा शून्य से अधिक भरें।';final raw=r.price.text.trim();if(raw.isNotEmpty){final p=double.tryParse(raw);if(p==null||!p.isFinite||p<0)return 'सामान ${i+1} की कीमत सही भरें।';}if(_mode=='bill'&&raw.isEmpty)return 'बिल में सामान ${i+1} की कीमत भरें।';}return null;}
 double get _total=>calculateBillTotal(_rows.where((r)=>r.item.text.trim().isNotEmpty).map(_lineTotal));
 String _qtyText(_BillRow r){final v=double.tryParse(r.qty.text.trim())??0;return v==v.roundToDouble()?v.toInt().toString():v.toString();}
 String _phoneForWhatsApp(){var p=_phone.text.replaceAll(RegExp(r'[^0-9]'),'');if(p.length==10)p='91$p';if(p.startsWith('0')&&p.length==11)p='91${p.substring(1)}';return p;}
 void _addRow(){final r=_BillRow();_watch(r);setState(()=>_rows.add(r));}
 void _removeRow(int i){if(_rows.length==1)return;setState(()=>_rows.removeAt(i).dispose());}
 List<_BillRow> get _validRows=>_rows.where((r)=>r.item.text.trim().isNotEmpty).toList();
 String _message(){
  final b=StringBuffer();b.writeln(_mode=='bill'?'*बिल*':'*सामान मंगवाने की लिस्ट*');b.writeln('ग्राहक: ${_name.text.trim()}');b.writeln('मोबाइल: ${_phone.text.trim()}');b.writeln('--------------------');
  var i=0;for(final r in _validRows){i++;final q=_qtyText(r);final unit=_units[r.unit]??r.unit;final price=r.price.text.trim().isEmpty?'':' — ₹${_price(r).toStringAsFixed(2)}';final total=_mode=='bill'?' — कुल ₹${_lineTotal(r).toStringAsFixed(2)}':'';b.writeln('$i. ${r.item.text.trim()} — $q $unit$price$total');}
  if(_mode=='bill')b.writeln('कुल राशि: *₹${_total.toStringAsFixed(2)}*');b.writeln('दिनांक: ${DateTime.now().toLocal().toString().substring(0,16)}');b.writeln('धन्यवाद');return b.toString();
 }
 Future<Uint8List> _buildPdf()async{
  final regular=await PdfGoogleFonts.notoSansDevanagariRegular();
  final bold=await PdfGoogleFonts.notoSansDevanagariBold();
  final doc=pw.Document();
  doc.addPage(pw.MultiPage(
   theme:pw.ThemeData.withFont(base:regular,bold:bold),
   pageFormat:PdfPageFormat.a4,
   build:(context)=>[
    pw.Center(child:pw.Text(_mode=='bill'?'बिल / रसीद':'सामान मंगवाने की लिस्ट',style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold))),
    pw.SizedBox(height:14),
    pw.Text('ग्राहक: ${_name.text.trim()}'),
    pw.Text('WhatsApp: ${_phone.text.trim()}'),
    pw.Text('दिनांक: ${DateTime.now().toLocal().toString().substring(0,16)}'),
    pw.Divider(),
    pw.Row(children:[pw.Expanded(child:pw.Text('सामान')),pw.SizedBox(width:105,child:pw.Text('मात्रा',textAlign:pw.TextAlign.right)),pw.SizedBox(width:90,child:pw.Text('प्रति यूनिट',textAlign:pw.TextAlign.right)),if(_mode=='bill')pw.SizedBox(width:90,child:pw.Text('कुल',textAlign:pw.TextAlign.right))]),
    ..._validRows.asMap().entries.map((entry){
     final r=entry.value;final qty='${_qtyText(r)} ${_units[r.unit]??r.unit}';
     return pw.Padding(padding:const pw.EdgeInsets.symmetric(vertical:6),child:pw.Row(children:[
      pw.Expanded(child:pw.Text('${entry.key+1}. ${r.item.text.trim()}')),
      pw.SizedBox(width:105,child:pw.Text(qty,textAlign:pw.TextAlign.right)),
      pw.SizedBox(width:90,child:pw.Text(r.price.text.trim().isEmpty?'—':'₹${_price(r).toStringAsFixed(2)}',textAlign:pw.TextAlign.right)),
      if(_mode=='bill')pw.SizedBox(width:90,child:pw.Text('₹${_lineTotal(r).toStringAsFixed(2)}',textAlign:pw.TextAlign.right))
     ]));
    }),
    pw.Divider(),
    if(_mode=='bill')pw.Align(alignment:pw.Alignment.centerRight,child:pw.Text('कुल राशि: ₹${_total.toStringAsFixed(2)}',style:pw.TextStyle(fontSize:16,fontWeight:pw.FontWeight.bold))),
    pw.SizedBox(height:18),
    pw.Text('Bharat Saathi',style:pw.TextStyle(fontWeight:pw.FontWeight.bold))
   ],
  ));
  return doc.save();
 }
 Future<void> _sharePdf()async{
  final validation=_validateRows();if(validation!=null){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(validation)));return;}
  setState(()=>_pdfBusy=true);
  try{
   final bytes=await _buildPdf();
   final safeName=_name.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'),'_');
   final fileName='${_mode=='bill'?'BharatSaathi_Bill':'BharatSaathi_List'}_${safeName.isEmpty?'document':safeName}.pdf';
   await Share.shareXFiles([XFile.fromData(bytes,name:fileName,mimeType:'application/pdf')],text:_mode=='bill'?'बिल की PDF रसीद':'सामान की लिस्ट की PDF');
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('PDF नहीं बन पाया: $e')));}
  finally{if(mounted)setState(()=>_pdfBusy=false);}
 }
 Future<void> _printPdf()async{
  final validation=_validateRows();if(validation!=null){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(validation)));return;}
  setState(()=>_pdfBusy=true);
  try{final bytes=await _buildPdf();await Printing.layoutPdf(onLayout:(_)=>bytes);}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('PDF प्रिंट नहीं हो पाया: $e')));}
  finally{if(mounted)setState(()=>_pdfBusy=false);}
 }
 Future<void> _sendWhatsApp()async{
  final validation=_validateRows();if(validation!=null){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(validation)));return;}
  final phone=_phoneForWhatsApp();if(phone.length<11||phone.length>15){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('सही WhatsApp नंबर दर्ज करें।')));return;}
  if(!RegExp(r'^(91)?[6-9][0-9]{9}$').hasMatch(phone)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('भारत का सही 10 अंकों का WhatsApp नंबर दर्ज करें।')));return;}
  final uri=Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(_message())}');
  if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('WhatsApp नहीं खुल पाया।')));}
 }
 @override Widget build(BuildContext context){
  return Scaffold(appBar:AppBar(title:const Text('बिल / सामान लिस्ट')),body:!_started?ListView(padding:const EdgeInsets.all(18),children:[
   const Text('पहले ग्राहक की जानकारी भरें',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
   const SizedBox(height:14),TextField(controller:_name,decoration:const InputDecoration(labelText:'ग्राहक / लिस्ट पाने वाले का नाम',border:OutlineInputBorder())),
   const SizedBox(height:12),TextField(controller:_phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'WhatsApp मोबाइल नंबर',hintText:'भारत का 10 अंकों का नंबर',border:OutlineInputBorder())),
   const SizedBox(height:18),FilledButton(onPressed:(){if(_name.text.trim().isEmpty||!RegExp(r'^(91)?[6-9][0-9]{9}$').hasMatch(_phoneForWhatsApp())){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('नाम और सही मोबाइल नंबर भरें।')));return;}setState(()=>_started=true);},child:const Text('आगे बढ़ें'))
  ]):ListView(padding:const EdgeInsets.all(16),children:[
   Text('नाम: ${_name.text.trim()}  •  ${_phone.text.trim()}',style:const TextStyle(fontWeight:FontWeight.w800)),
   const SizedBox(height:12),SegmentedButton<String>(segments:const [ButtonSegment(value:'bill',label:Text('बिल'),icon:Icon(Icons.receipt_long)),ButtonSegment(value:'list',label:Text('सामान लिस्ट'),icon:Icon(Icons.shopping_bag_outlined))],selected:{_mode},onSelectionChanged:(v)=>setState(()=>_mode=v.first)),
   const SizedBox(height:8),
   Text(_mode=='bill'?'हर सामान की मात्रा और उस सामान की कुल कीमत भरें।':'सामान का नाम, मात्रा और उसकी यूनिट चुनें। कीमत भरना जरूरी नहीं है।',style:TextStyle(color:muted,fontSize:12)),
   const SizedBox(height:8),
   ...List.generate(_rows.length,(i){final r=_rows[i];return Card(color:surfaceColor,child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
    Row(children:[Expanded(child:Text('सामान ${i+1}',style:const TextStyle(fontWeight:FontWeight.w800))),IconButton(onPressed:()=>_removeRow(i),icon:const Icon(Icons.delete_outline))]),
    TextField(controller:r.item,decoration:const InputDecoration(labelText:'सामान का नाम',border:OutlineInputBorder())),
    const SizedBox(height:8),
    Row(children:[
     Expanded(flex:2,child:TextField(controller:r.qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'मात्रा (जैसे 200 या 2)',border:OutlineInputBorder()))),
     const SizedBox(width:8),
     Expanded(child:DropdownButtonFormField<String>(value:r.unit,decoration:const InputDecoration(labelText:'यूनिट',border:OutlineInputBorder()),items:_units.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v){if(v!=null)setState(()=>r.unit=v);})),
    ]),
    Padding(padding:const EdgeInsets.only(top:8),child:TextField(controller:r.price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:_mode=='bill'?'प्रति यूनिट कीमत (₹)':'कीमत (वैकल्पिक ₹)',hintText:_mode=='bill'?'उदाहरण: 45':'खाली छोड़ सकते हैं',border:const OutlineInputBorder())))
   ])));}),
   OutlinedButton.icon(onPressed:_addRow,icon:const Icon(Icons.add),label:const Text('एक और सामान जोड़ें')),
   if(_mode=='bill')Padding(padding:const EdgeInsets.symmetric(vertical:14),child:Text('कुल राशि: ₹${_total.toStringAsFixed(2)}',textAlign:TextAlign.right,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900))),
   const SizedBox(height:8),FilledButton.icon(onPressed:_sendWhatsApp,icon:const Icon(Icons.chat),label:const Text('WhatsApp पर टेक्स्ट भेजें')),
   const SizedBox(height:8),OutlinedButton.icon(onPressed:()=>Share.share(_message()),icon:const Icon(Icons.share),label:const Text('टेक्स्ट लिस्ट शेयर करें')),
   const SizedBox(height:8),OutlinedButton.icon(onPressed:_pdfBusy?null:_sharePdf,icon:_pdfBusy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.picture_as_pdf),label:Text(_pdfBusy?'PDF तैयार हो रहा है...':'PDF बनाएं / डाउनलोड या शेयर करें')),
   const SizedBox(height:8),FilledButton.icon(onPressed:_pdfBusy?null:_sharePdf,icon:const Icon(Icons.picture_as_pdf),label:const Text('PDF WhatsApp पर भेजें')),
   OutlinedButton.icon(onPressed:_pdfBusy?null:_printPdf,icon:const Icon(Icons.print_outlined),label:const Text('प्रिंट / PDF सेव करें')),
   const SizedBox(height:8),const Text('PDF शेयर करने पर Android Share Sheet खुलेगी। WhatsApp चुनकर ग्राहक की चैट चुनें और Send दबाएँ। ऐप आपकी अनुमति के बिना संदेश नहीं भेजता।',style:TextStyle(fontSize:11,color:Colors.grey))
  ]));
 }
}
class _BillRow{
 final item=TextEditingController();final qty=TextEditingController(text:'1');final price=TextEditingController();String unit='piece';
 void dispose(){item.dispose();qty.dispose();price.dispose();}
}
class KhataHubPage extends StatelessWidget{
 final List<Record> shop,personal;final VoidCallback onShop,onPersonal,onLinked;
 const KhataHubPage({super.key,required this.shop,required this.personal,required this.onShop,required this.onPersonal,required this.onLinked});
 double _sum(List<Record> a)=>a.fold<double>(0,(s,e)=>s+e.amount);
 @override Widget build(BuildContext context)=>ListView(padding:EdgeInsets.all(17),children:[heading('खाता बुक','दुकान और पर्सनल उधार'),_card('दुकानदार का खाता','ग्राहक को कितना उधार दिया और कितना वापस मिला','₹'+money(_sum(shop)),onShop),_card('पर्सनल उधार','दोस्तों और रिश्तेदारों का हिसाब','₹'+money(_sum(personal)),onPersonal),_card('ऐप वाले ग्राहक से जोड़ें','मोबाइल नंबर से साझा खाता लिंक करें','',onLinked),Text('यह डिजिटल खाता है; बैंक या UPI से अपने-आप पैसे नहीं कटते।',style:TextStyle(color:muted,fontSize:11))]);
 Widget _card(String a,String b,String c,VoidCallback f)=>Card(color:surfaceColor,child:ListTile(title:Text(a,style:TextStyle(color:navy,fontWeight:FontWeight.w900)),subtitle:Text(b),trailing:c.isEmpty?Icon(Icons.chevron_right):Text(c),onTap:f));
}
class LocalLedgerPage extends StatefulWidget{
 final String title;final List<Record> items;final Future<void> Function() onCredit,onPayment;
 const LocalLedgerPage({super.key,required this.title,required this.items,required this.onCredit,required this.onPayment});
 @override State<LocalLedgerPage> createState()=>_LocalLedgerPageState();
}
class _LocalLedgerPageState extends State<LocalLedgerPage>{
 @override Widget build(BuildContext context){final people=<String,double>{};for(final e in widget.items){people[e.name]=(people[e.name]??0)+e.amount;}return Scaffold(bottomNavigationBar:const BannerAdSlot(),appBar:AppBar(title:Text(widget.title)),body:ListView(padding:EdgeInsets.all(16),children:[Text('कुल बकाया: ₹'+money(widget.items.fold<double>(0,(s,e)=>s+e.amount)),style:TextStyle(color:navy,fontWeight:FontWeight.w900,fontSize:21)),Row(children:[Expanded(child:FilledButton(onPressed:()async{await widget.onCredit();if(mounted)setState((){});},child:Text('उधार दें'))),SizedBox(width:8),Expanded(child:OutlinedButton(onPressed:()async{await widget.onPayment();if(mounted)setState((){});},child:Text('वापसी दर्ज करें')))]),...people.entries.map((e)=>ListTile(title:Text(e.key),trailing:Text('₹'+money(e.value),style:TextStyle(color:navy,fontWeight:FontWeight.w900))))]));}
}
class ExpenseOnlyPage extends StatefulWidget{
 final List<Record> items;final Future<void> Function() onAdd;
 const ExpenseOnlyPage({super.key,required this.items,required this.onAdd});
 @override State<ExpenseOnlyPage> createState()=>_ExpenseOnlyPageState();
}
class _ExpenseOnlyPageState extends State<ExpenseOnlyPage>{
 @override Widget build(BuildContext context){final now=DateTime.now();final rows=widget.items.where((e)=>e.createdAt!=null&&e.createdAt!.year==now.year&&e.createdAt!.month==now.month).toList();final total=rows.fold<double>(0,(s,e)=>s+e.amount);return Scaffold(appBar:AppBar(title:Text('महीने का खर्च')),body:ListView(padding:EdgeInsets.all(16),children:[Text('इस महीने का खर्च: ₹'+money(total),style:TextStyle(color:navy,fontSize:22,fontWeight:FontWeight.w900)),FilledButton.icon(onPressed:()async{await widget.onAdd();if(mounted)setState((){});},icon:Icon(Icons.add),label:Text('खर्च जोड़ें')),...rows.map((e)=>ListTile(title:Text(e.name),subtitle:Text(e.detail),trailing:Text('₹'+money(e.amount))))]));}
}
class ServiceCategoryPage extends StatelessWidget{
 final String kind;final bool english;const ServiceCategoryPage({super.key,required this.kind,required this.english});
 @override Widget build(BuildContext context){
  final insurance=kind=='insurance';
  final opts=kind=='recharge'?(english?['Prepaid mobile recharge','Postpaid mobile bill']:['प्रीपेड मोबाइल रिचार्ज','पोस्टपेड मोबाइल बिल']):kind=='bills'?(english?['Electricity bill','Water bill','Gas bill','DTH recharge','Broadband / internet bill','Landline bill','FASTag recharge (Coming Soon)']:['बिजली बिल','पानी बिल','गैस बिल','DTH रिचार्ज','ब्रॉडबैंड / इंटरनेट बिल','लैंडलाइन बिल','FASTag रिचार्ज (Coming Soon)']):kind=='challan'?(english?['Traffic challan','Vehicle challan status']:['ट्रैफिक चालान','वाहन चालान की स्थिति']):(english?['Bike Insurance','Car Insurance']:['बाइक इंश्योरेंस','कार इंश्योरेंस']);
  final title=kind=='recharge'?(english?'Mobile Recharge':'मोबाइल रिचार्ज'):kind=='bills'?(english?'Bill Payment':'बिल पेमेंट'):kind=='challan'?(english?'Challan Payment':'चालान पेमेंट'):(english?'Bike / Car Insurance':'बाइक / कार इंश्योरेंस');
  return Scaffold(bottomNavigationBar:const BannerAdSlot(),appBar:AppBar(title:Text(title)),body:ListView(padding:EdgeInsets.all(16),children:opts.map((x)=>Card(color:surfaceColor,child:ListTile(title:Text(x),trailing:Chip(label:Text('COMING SOON')),onTap:()=>openComingSoon(context,x)))).toList()));
 }
}
class LinkedKhataPage extends StatefulWidget{final bool supabaseAvailable;const LinkedKhataPage({super.key,required this.supabaseAvailable});@override State<LinkedKhataPage> createState()=>_LinkedKhataPageState();}
class _LinkedKhataPageState extends State<LinkedKhataPage>{
 List<Map<String,dynamic>> rows=[];bool busy=false;SupabaseClient get c=>Supabase.instance.client;
 @override void initState(){super.initState();load();}
 Future<void> load()async{final u=c.auth.currentUser;if(!widget.supabaseAvailable||u==null)return;setState(()=>busy=true);try{final a=await c.from('khata_links').select('id,retailer_id,customer_id,shop_name,retailer_name,customer_name,retailer_phone,customer_phone,status').eq('retailer_id',u.id);final b=await c.from('khata_links').select('id,retailer_id,customer_id,shop_name,retailer_name,customer_name,retailer_phone,customer_phone,status').eq('customer_id',u.id);final m=<String,Map<String,dynamic>>{};for(final e in [...a,...b]){m[e['id']]=Map<String,dynamic>.from(e);}if(mounted)setState(()=>rows=m.values.toList());}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}if(mounted)setState(()=>busy=false);}
 Future<void> request()async{final p=TextEditingController(),shop=TextEditingController(text:'मेरी दुकान');await showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(x)=>Padding(padding:EdgeInsets.fromLTRB(18,18,18,18+MediaQuery.of(x).viewInsets.bottom),child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:shop,decoration:const InputDecoration(labelText:'दुकान का नाम')),TextField(controller:p,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'ग्राहक का रजिस्टर्ड मोबाइल')),FilledButton(onPressed:()async{Navigator.pop(x);try{await c.rpc('request_khata_link',params:{'p_phone':p.text,'p_shop_name':shop.text});await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}},child:const Text('लिंक अनुरोध भेजें'))])));}
 Future<void> respond(String id,bool ok)async{await c.rpc('respond_khata_link',params:{'p_link_id':id,'p_accept':ok});await load();}

 Future<void> addEntry(Map<String,dynamic> link,String type)async{
 final amount=TextEditingController(),note=TextEditingController();
 await showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(ctx)=>Padding(
  padding:EdgeInsets.fromLTRB(18,18,18,18+MediaQuery.of(ctx).viewInsets.bottom),
  child:Column(mainAxisSize:MainAxisSize.min,children:[
   TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'राशि (₹)')),
   TextField(controller:note,decoration:const InputDecoration(labelText:'विवरण')),
   FilledButton(onPressed:()async{
    final v=double.tryParse(amount.text);if(v==null||v<=0)return;
    Navigator.pop(ctx);
    try{await Supabase.instance.client.rpc('add_khata_transaction',params:{'p_link_id':link['id'],'p_type':type,'p_amount':v,'p_note':note.text});await load();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
   },child:const Text('सेव करें'))
  ])));
 }
 @override Widget build(BuildContext context){final u=c.auth.currentUser;if(!widget.supabaseAvailable||u==null)return Scaffold(bottomNavigationBar:const BannerAdSlot(),appBar:AppBar(title:Text('लिंक किया हुआ खाता')),body:Center(child:Text('पहले ईमेल और पासवर्ड से लॉगिन करें।')));return Scaffold(bottomNavigationBar:const BannerAdSlot(),appBar:AppBar(title:Text('लिंक किया हुआ खाता'),actions:[IconButton(onPressed:load,icon:Icon(Icons.refresh))]),body:ListView(padding:EdgeInsets.all(16),children:[Text('ग्राहक का रजिस्टर्ड मोबाइल नंबर डालें। ग्राहक की स्वीकृति के बाद दोनों तरफ एक ही खाता दिखेगा।'),FilledButton(onPressed:request,child:Text('ग्राहक को जोड़ें')),if(busy)LinearProgressIndicator(),...rows.map((r){final retailer=r['retailer_id']==u.id;final pending=r['status']=='pending';final name=retailer?(r['customer_name']??'ग्राहक'):(r['retailer_name']??'दुकानदार');return Card(color:surfaceColor,child:ListTile(title:Text(name.toString()),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r['status'].toString()),if(r['status']=='accepted')_LinkedDetails(link:r,retailer:retailer,onCredit:()=>addEntry(r,'credit'),onPayment:()=>addEntry(r,'payment'))]),trailing:pending&&!retailer?TextButton(onPressed:()=>respond(r['id'],true),child:Text('स्वीकार करें')):null));})]));}
}
class Chart extends StatelessWidget {
  const Chart({super.key});

  @override
  Widget build(BuildContext context) {
    const values = [0.42, 0.68, 0.50, 0.88, 0.62, 1.0, 0.76];
    const days = ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₹24,860', style: TextStyle(color: navy, fontSize: 20, fontWeight: FontWeight.w900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFE8F5EE), borderRadius: BorderRadius.circular(20)),
                child: Text('+12.8%', style: TextStyle(color: green, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 19,
                              height: 70 * values[i],
                              decoration: BoxDecoration(
                                color: i == 5 ? gold : Color(0xFFDCE5EF),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(days[i], style: TextStyle(fontSize: 9, color: muted)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
Widget mini(String a,String b,IconData i)=>Row(children:[Icon(i,color:gold,size:14),SizedBox(width:4),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:TextStyle(color:Colors.white60,fontSize:9)),Text(b,style:TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w800))])]);
Widget metric(String a,String b,IconData i,Color c)=>Container(padding:EdgeInsets.all(13),decoration:BoxDecoration(color:surfaceColor,borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Expanded(child:Text(a,style:TextStyle(color:muted,fontSize:10))),Icon(i,color:c,size:18)]),SizedBox(height:7),FittedBox(alignment:Alignment.centerLeft,child:Text(b,style:TextStyle(color:navy,fontSize:18,fontWeight:FontWeight.w900)))]));
Widget section(String a,String b)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:TextStyle(color:navy,fontSize:16,fontWeight:FontWeight.w900)),Text(b,style:TextStyle(color:muted,fontSize:10))]);
Widget quick(String a,IconData i,Color bgc,Color fg,VoidCallback f)=>InkWell(onTap:f,borderRadius:BorderRadius.circular(16),child:Container(padding:EdgeInsets.symmetric(vertical:14,horizontal:3),decoration:BoxDecoration(color:surfaceColor,borderRadius:BorderRadius.circular(16)),child:Column(children:[Container(width:42,height:42,decoration:BoxDecoration(color:bgc,borderRadius:BorderRadius.circular(13)),child:Icon(i,color:fg)),SizedBox(height:8),Text(a,style:TextStyle(color:navy,fontSize:10,fontWeight:FontWeight.w800))])));
Widget activity(Record r)=>Container(margin:EdgeInsets.only(top:7),padding:EdgeInsets.all(12),decoration:BoxDecoration(color:surfaceColor,borderRadius:BorderRadius.circular(14)),child:Row(children:[CircleAvatar(backgroundColor:Color(0xFFEAF0F6),child:Icon(r.icon,color:blue,size:18)),SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r.name,style:TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:12)),Text(r.detail,style:TextStyle(color:muted,fontSize:10))])),Text('₹${money(r.amount)}',style:TextStyle(color:green,fontWeight:FontWeight.w900,fontSize:12))]));
class PersonalFinancePage extends StatelessWidget{
 final List<Record> items;final double budget;final String budgetName;final VoidCallback onSetBudget,onIncome,onExpense;
 const PersonalFinancePage({super.key,required this.items,required this.budget,required this.budgetName,required this.onSetBudget,required this.onIncome,required this.onExpense});
 @override Widget build(BuildContext context){
 final income=items.where((e)=>e.amount>0).fold<double>(0,(s,e)=>s+e.amount);
 final now=DateTime.now();final spent=items.where((e){final d=e.createdAt;return e.amount<0&&d!=null&&d.year==now.year&&d.month==now.month;}).fold<double>(0,(s,e)=>s+e.amount.abs());
 return ListView(padding:const EdgeInsets.all(17),children:[
 heading('पर्सनल फाइनेंस','अपनी आय और मासिक खर्च का हिसाब रखें'),const SizedBox(height:14),
 Container(padding:EdgeInsets.all(18),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 const Text('कुल बचत / शेष',style:TextStyle(color:Colors.white70,fontSize:11)),
 Text('₹${money(income-spent)}',style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.w900)),
 const SizedBox(height:12),Row(children:[Expanded(child:mini('कुल आय','₹${money(income)}',Icons.trending_up)),Expanded(child:mini('कुल खर्च','₹${money(spent)}',Icons.payments_outlined))])
 ])),const SizedBox(height:14),
 Row(children:[Expanded(child:FilledButton.icon(onPressed:onIncome,icon:Icon(Icons.add),label:Text('आय जोड़ें'),style:FilledButton.styleFrom(backgroundColor:green))),SizedBox(width:9),Expanded(child:FilledButton.icon(onPressed:onExpense,icon:Icon(Icons.remove),label:Text('खर्च जोड़ें'),style:FilledButton.styleFrom(backgroundColor:red)))]),
 SizedBox(height:20),section('मासिक खर्च सीमा',budgetName),SizedBox(height:8),Container(padding:EdgeInsets.all(14),decoration:BoxDecoration(color:surfaceColor,borderRadius:BorderRadius.circular(15)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(budget>0?'₹${money(spent)} / ₹${money(budget)}':'सीमा तय नहीं है',style:TextStyle(color:navy,fontWeight:FontWeight.w800)),TextButton(onPressed:onSetBudget,child:Text(budget>0?'बदलें':'सेट करें'))]),if(budget>0)LinearProgressIndicator(value:(spent/budget).clamp(0.0,1.0).toDouble(),backgroundColor:bg,color:spent>budget?red:green),if(budget>0)Padding(padding:EdgeInsets.only(top:7),child:Text(spent>budget?'खर्च तय सीमा से अधिक है।':'सीमा में शेष ₹${money((budget-spent).clamp(0.0,double.infinity))}',style:TextStyle(color:spent>budget?red:muted,fontSize:11)))])),SizedBox(height:20),section('लेन-देन','इस डिवाइस पर सेव रिकॉर्ड'),
 if(items.isEmpty)Padding(padding:EdgeInsets.symmetric(vertical:24),child:Center(child:Text('अभी कोई व्यक्तिगत लेन-देन नहीं है।',style:TextStyle(color:muted))))
 else ...items.map((e)=>Container(margin:EdgeInsets.only(top:8),padding:EdgeInsets.all(13),decoration:BoxDecoration(color:surfaceColor,borderRadius:BorderRadius.circular(14)),child:Row(children:[CircleAvatar(backgroundColor:e.amount>=0?Color(0xFFE3F4EC):Color(0xFFFFE8E8),child:Icon(e.icon,color:e.amount>=0?green:red)),SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e.name,style:TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:12)),Text(e.detail,style:TextStyle(color:muted,fontSize:10))])),Text('${e.amount>=0?'+':'−'} ₹${money(e.amount.abs())}',style:TextStyle(color:e.amount>=0?green:red,fontWeight:FontWeight.w900))])))
 ]);
 }
}
class KhataPage extends StatelessWidget {
  final List<Record> items;final VoidCallback onPayment;
  const KhataPage({super.key, required this.items,required this.onPayment});

  @override
  Widget build(BuildContext context) {
    final due = items.fold<double>(0, (sum, entry) => sum + entry.amount);
    return ListView(
      padding: const EdgeInsets.all(17),
      children: [
        heading('ग्राहक खाता', 'उधार और भुगतान का हिसाब'),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('कुल ग्राहक बकाया', style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text('₹${money(due)}', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:onPayment,icon:Icon(Icons.payments_outlined),label:Text('ग्राहक से भुगतान दर्ज करें'),style:FilledButton.styleFrom(backgroundColor:green))),
        const SizedBox(height:8),
        ...items.map((entry) {
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color:surfaceColor, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFEAF0F6),
                  child: Text(entry.name[0], style: TextStyle(color: navy, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name, style: TextStyle(color: navy, fontWeight: FontWeight.w800, fontSize: 12)),
                      Text(entry.detail, style: TextStyle(color: muted, fontSize: 10)),
                    ],
                  ),
                ),
                Text(
                  '${entry.amount < 0 ? '−' : '+'} ₹${money(entry.amount.abs())}',
                  style: TextStyle(color: entry.amount < 0 ? green : red, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
String _normalizeIndianMobile(String value){var digits=value.replaceAll(RegExp(r'[^0-9]'),'');if(digits.length==12&&digits.startsWith('91'))digits=digits.substring(2);if(digits.length==11&&digits.startsWith('0'))digits=digits.substring(1);return digits;}
String _uuidV4(){final random=Random.secure();final bytes=List<int>.generate(16,(_)=>random.nextInt(256));bytes[6]=(bytes[6]&0x0f)|0x40;bytes[8]=(bytes[8]&0x3f)|0x80;final h=bytes.map((b)=>b.toRadixString(16).padLeft(2,'0')).join();return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';}
class AuthPage extends StatefulWidget{final bool supabaseAvailable;const AuthPage({super.key,required this.supabaseAvailable});@override State<AuthPage> createState()=>_AuthPageState();}
class _AuthPageState extends State<AuthPage>{
 final email=TextEditingController(),password=TextEditingController(),fullName=TextEditingController(),phone=TextEditingController();bool signUp=false,busy=false,showPassword=false,acceptedLegalTerms=false;String? notice;bool errorNotice=false;
 SupabaseClient get client=>Supabase.instance.client;
 void message(String text,{bool error=false}){if(!mounted)return;setState((){notice=text;errorNotice=error;});}
 Future<void> _ensureProfileAndAccounts({String? nameOverride,String? mobileOverride})async{
 final user=client.auth.currentUser;if(user==null)throw const AuthException('लॉगिन सत्र उपलब्ध नहीं है');
 final enteredName=nameOverride?.trim()??'';
 final name=enteredName.isNotEmpty?enteredName:(user.email??'Bharat Saathi').split('@').first;
 final mobile=_normalizeIndianMobile(mobileOverride??(user.userMetadata?['phone'] as String? ?? ''));
  await client.from('profiles').upsert({'id':user.id,'full_name':name,'phone':mobile,'preferred_language':'hi'});
 final existing=await client.from('accounts').select('id,account_type').eq('created_by',user.id);
 final types=<String>{for(final row in existing)(row['account_type'] as String)};
 for(final type in ['personal','retailer']){
 if(types.contains(type))continue;
 final id=_uuidV4();
 await client.from('accounts').insert({'id':id,'account_type':type,'display_name':type=='personal'?'व्यक्तिगत खाता':'मेरा रिटेल स्टोर','currency_code':'INR','created_by':user.id});
 await client.from('account_members').insert({'account_id':id,'user_id':user.id,'role':'owner'});
 }
 }
 Future<void> submit()async{
 if(!widget.supabaseAvailable){message('लॉगिन सेवा उपलब्ध नहीं है। इंटरनेट कनेक्शन जाँचें।',error:true);return;}
 final mobile=_normalizeIndianMobile(phone.text.trim());
 final mail=email.text.trim();
 final enteredName=fullName.text.trim();
 final validMobile=RegExp(r'^[6-9][0-9]{9}$').hasMatch(mobile);
 if(signUp&&!acceptedLegalTerms){message('रजिस्ट्रेशन जारी रखने के लिए Privacy Policy और Terms & Conditions से सहमति दें।',error:true);return;}
 if(password.text.length<8||!validMobile||(signUp&&(!mail.contains('@')||fullName.text.trim().isEmpty))){
  message(signUp?'नाम, सही ईमेल, 10 अंकों का मोबाइल और कम-से-कम 8 अक्षर का पासवर्ड भरें।':'10 अंकों का सही मोबाइल नंबर और कम-से-कम 8 अक्षर का पासवर्ड भरें।',error:true);return;
 }
 setState(()=>busy=true);
 var returnToHome=false;
 try{
  if(signUp){
   final response=await client.auth.signUp(
    email:mail,password:password.text,
    data:{'full_name':enteredName,'phone':mobile,'accepted_terms':true,'terms_version':termsVersion,'terms_accepted_at':DateTime.now().toUtc().toIso8601String()},
    emailRedirectTo:'https://annukumar6280-glitch.github.io/Bharat-Saathi-/email-confirmed.html'
   );
   if(response.session==null){if(mounted)setState(()=>signUp=false);message('रजिस्ट्रेशन हो गया। ईमेल पर आए लिंक से अकाउंट कन्फर्म करें। उसके बाद मोबाइल नंबर और पासवर्ड से लॉगिन करें।');}
   else{await _ensureProfileAndAccounts(nameOverride:enteredName,mobileOverride:mobile);returnToHome=true;}
  }else{
   final response=await client.functions.invoke('phone-password-login',body:{'phone':mobile,'password':password.text});
   final payload=response.data;
   if(response.status!=200||payload is! Map||payload['refresh_token'] is! String){
    final serverMessage=payload is Map?payload['error']?.toString():null;
    throw AuthException(serverMessage??'मोबाइल नंबर या पासवर्ड गलत है, या ईमेल सत्यापन बाकी है।');
   }
   await client.auth.setSession(payload['refresh_token'] as String);
   await _ensureProfileAndAccounts(mobileOverride:mobile);
   returnToHome=true;
  }
 }on AuthException catch(e){message(e.message,error:true);}
 on PostgrestException catch(e){message(e.message.contains('profiles_phone_normalized_unique')?'यह मोबाइल नंबर किसी दूसरे अकाउंट से जुड़ा हुआ है। दूसरा नंबर इस्तेमाल करें।':'डेटाबेस सेटअप त्रुटि: ${e.message}',error:true);}
 catch(e){
  final detail=e.toString().toLowerCase();
  message(detail.contains('401')||detail.contains('invalid login')||detail.contains('unauthorized')?'मोबाइल नंबर या पासवर्ड गलत है, या ईमेल सत्यापन बाकी है।':'कनेक्शन या अकाउंट सेटअप पूरा नहीं हुआ। दोबारा प्रयास करें।',error:true);
 }
 if(mounted)setState(()=>busy=false);
 if(returnToHome&&mounted){homeTabRequest.value=homeTabRequest.value+1;Navigator.of(context).popUntil((route)=>route.isFirst);}
}
 Future<void> resendVerification()async{
 if(!widget.supabaseAvailable){message('Supabase कनेक्शन उपलब्ध नहीं है।',error:true);return;}
 final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
  title:const Text('वेरिफिकेशन लिंक दोबारा भेजें'),
  content:TextField(controller:email,keyboardType:TextInputType.emailAddress,autocorrect:false,decoration:const InputDecoration(labelText:'रजिस्ट्रेशन वाला ईमेल')),
  actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('रद्द करें')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('लिंक भेजें'))]
 ));
 if(confirmed!=true)return;
 final mail=email.text.trim();
 if(!mail.contains('@')){message('रजिस्ट्रेशन वाला सही ईमेल भरें।',error:true);return;}
 setState(()=>busy=true);
 try{
  await client.auth.resend(
   type:OtpType.signup,
   email:mail,
   emailRedirectTo:'https://annukumar6280-glitch.github.io/Bharat-Saathi-/email-confirmed.html'
  );
  message('यदि इस ईमेल का रजिस्ट्रेशन अभी कन्फर्म नहीं हुआ है, तो नया लिंक भेजने का अनुरोध सफल हुआ। Inbox और Spam फ़ोल्डर देखें।');
 }on AuthException catch(e){message(e.message,error:true);}
 catch(_){message('वेरिफिकेशन ईमेल नहीं भेजा जा सका। ईमेल और Auth/SMTP सेटिंग जाँचें।',error:true);}
 if(mounted)setState(()=>busy=false);
}
 Future<void> resetPassword()async{
 if(!widget.supabaseAvailable){message('Supabase कनेक्शन उपलब्ध नहीं है।',error:true);return;}
 final resetEmail=TextEditingController();
 final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
  title:const Text('पासवर्ड रीसेट करें'),
  content:TextField(controller:resetEmail,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'रजिस्ट्रेशन वाला ईमेल')),
  actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('रद्द करें')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('रीसेट ईमेल भेजें'))]
 ));
 if(confirmed!=true){resetEmail.dispose();return;}
 final resetMail=resetEmail.text.trim();resetEmail.dispose();
 if(!resetMail.contains('@')){message('पासवर्ड रीसेट के लिए सही रजिस्ट्रेशन ईमेल भरें।',error:true);return;}
 setState(()=>busy=true);
 try{await client.auth.resetPasswordForEmail(resetMail);message('पासवर्ड रीसेट ईमेल भेजने का अनुरोध सफल हुआ।');}
 on AuthException catch(e){message(e.message,error:true);}catch(_){message('रीसेट ईमेल नहीं भेजा जा सका। ईमेल और SMTP सेटिंग जाँचें।',error:true);}
 if(mounted)setState(()=>busy=false);
}
 Future<void> signOut()async{setState(()=>busy=true);try{await client.auth.signOut();if(mounted)Navigator.of(context).popUntil((route)=>route.isFirst);}catch(_){message('लॉगआउट पूरा नहीं हुआ।',error:true);}if(mounted)setState(()=>busy=false);}
 @override void dispose(){email.dispose();password.dispose();fullName.dispose();phone.dispose();super.dispose();}
 @override Widget build(BuildContext context){
 final user=widget.supabaseAvailable?client.auth.currentUser:null;
 return Scaffold(bottomNavigationBar:const BannerAdSlot(),appBar:AppBar(title:const Text('अकाउंट और सुरक्षा')),body:ListView(padding:const EdgeInsets.all(20),children:[
 Container(padding:EdgeInsets.all(18),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(18)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Bharat Saathi अकाउंट',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),SizedBox(height:6),Text('ईमेल से सुरक्षित लॉगिन। SMS OTP अभी Coming Soon है।',style:TextStyle(color:Colors.white70,fontSize:12))])),
 const SizedBox(height:18),
 if(!widget.supabaseAvailable)Text('अकाउंट सेवा से कनेक्शन उपलब्ध नहीं है। इंटरनेट कनेक्शन जाँचें।',style:TextStyle(color:red)),
 if(user!=null)...[
 Text('लॉगिन सफल',style:TextStyle(color:green,fontSize:18,fontWeight:FontWeight.w900)),SizedBox(height:6),Text(user.email??'',style:TextStyle(color:navy)),SizedBox(height:12),Text('आपके रिकॉर्ड पहले इस फोन में सुरक्षित सेव होते हैं। इंटरनेट उपलब्ध होने पर वे अपने-आप क्लाउड से सिंक होते हैं और दूसरे फोन पर लॉगिन करने पर वापस आ सकते हैं। इंटरनेट न होने पर सिंक बाद में दोबारा होगा।',style:TextStyle(color:muted,fontSize:12)),SizedBox(height:18),FilledButton(onPressed:busy?null:signOut,child:Text(busy?'कृपया प्रतीक्षा करें':'लॉगआउट करें'))
 ]else...[
 if(signUp)TextField(controller:fullName,decoration:const InputDecoration(labelText:'पूरा नाम',prefixIcon:Icon(Icons.person_outline))),
 if(signUp)const SizedBox(height:10),
 if(signUp)TextField(controller:email,keyboardType:TextInputType.emailAddress,autocorrect:false,decoration:const InputDecoration(labelText:'ईमेल आईडी (कन्फर्मेशन के लिए)',prefixIcon:Icon(Icons.email_outlined))),
 if(signUp)const SizedBox(height:10),
 TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'मोबाइल नंबर (10 अंक)',prefixIcon:Icon(Icons.phone_android),hintText:'जैसे 9876543210')),
 const SizedBox(height:10),
 TextField(controller:password,obscureText:!showPassword,decoration:InputDecoration(labelText:'पासवर्ड (कम-से-कम 8 अक्षर)',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(onPressed:()=>setState(()=>showPassword=!showPassword),icon:Icon(showPassword?Icons.visibility_off:Icons.visibility)))),
 if(signUp)Padding(padding:const EdgeInsets.only(top:8),child:Text('रजिस्ट्रेशन के बाद ईमेल पर आए लिंक से अकाउंट कन्फर्म करें। लॉगिन मोबाइल नंबर और पासवर्ड से होगा।',style:TextStyle(color:muted,fontSize:11))),
 if(signUp)Padding(padding:const EdgeInsets.only(top:4),child:Text('मोबाइल नंबर अभी SMS OTP से verify नहीं होता। केवल अपना नंबर दें। / This number is not verified by SMS OTP yet; enter only a number you own.',style:TextStyle(color:muted,fontSize:11))),
 if(signUp)Padding(padding:const EdgeInsets.only(top:10),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Checkbox(value:acceptedLegalTerms,onChanged:busy?null:(value)=>setState(()=>acceptedLegalTerms=value??false),materialTapTargetSize:MaterialTapTargetSize.shrinkWrap,visualDensity:VisualDensity.compact),
  Expanded(child:Padding(padding:const EdgeInsets.only(top:8),child:Wrap(crossAxisAlignment:WrapCrossAlignment.center,children:[
   const Text('मैंने पढ़ लिया है और सहमत हूँ: ',style:TextStyle(fontSize:11)),
   InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const PrivacyPolicyPage(english:true))),child:const Text('Privacy Policy',style:TextStyle(color:Color(0xFF2367B2),fontSize:11,decoration:TextDecoration.underline,fontWeight:FontWeight.w700))),
   const Text(' और ',style:TextStyle(fontSize:11)),
   InkWell(onTap:()=>launchUrl(Uri.parse(termsConditionsUrl),mode:LaunchMode.externalApplication),child:const Text('Terms & Conditions',style:TextStyle(color:Color(0xFF2367B2),fontSize:11,decoration:TextDecoration.underline,fontWeight:FontWeight.w700))),
   const Text('।',style:TextStyle(fontSize:11))
  ])))
 ])),
 SizedBox(height:16),FilledButton(onPressed:busy?null:submit,style:FilledButton.styleFrom(backgroundColor:navy,padding:EdgeInsets.all(15)),child:Text(busy?'कृपया प्रतीक्षा करें':signUp?'अकाउंट बनाएं':'मोबाइल नंबर से लॉगिन करें')),
 Padding(padding:const EdgeInsets.only(top:6),child:Row(children:[
  Expanded(child:OutlinedButton(onPressed:busy?null:()=>setState(()=>signUp=false),style:OutlinedButton.styleFrom(minimumSize:const Size(0,34),padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),visualDensity:VisualDensity.compact),child:Text('लॉगिन करें',style:TextStyle(fontSize:12,fontWeight:!signUp?FontWeight.w800:FontWeight.w500)))),
  const SizedBox(width:8),
  Expanded(child:OutlinedButton(onPressed:busy?null:()=>setState(()=>signUp=true),style:OutlinedButton.styleFrom(minimumSize:const Size(0,34),padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),visualDensity:VisualDensity.compact,side:BorderSide(color:signUp?blue:borderColor,width:signUp?1.5:1)),child:Text('रजिस्टर करें',style:TextStyle(fontSize:12,fontWeight:signUp?FontWeight.w800:FontWeight.w500))))
 ])),
 if(!signUp)TextButton(onPressed:busy?null:resendVerification,child:const Text('वेरिफिकेशन लिंक दोबारा भेजें')),
 if(!signUp)TextButton(onPressed:busy?null:resetPassword,child:const Text('पासवर्ड भूल गए? ईमेल से रीसेट करें'))
 ],
 if(notice!=null)Padding(padding:EdgeInsets.only(top:14),child:Text(notice!,style:TextStyle(color:errorNotice?red:green,fontSize:12,fontWeight:FontWeight.w700)))
 ]));
 }
}
class CloudBackupPage extends StatefulWidget{final bool supabaseAvailable;final Future<void> Function() onRestore;const CloudBackupPage({super.key,required this.supabaseAvailable,required this.onRestore});@override State<CloudBackupPage> createState()=>_CloudBackupPageState();}
class _CloudBackupPageState extends State<CloudBackupPage>{
 bool busy=false;String? notice;bool noticeError=false;SupabaseClient get client=>Supabase.instance.client;
 void showMessage(String text,{bool error=false}){if(mounted)setState((){notice=text;noticeError=error;});}
 Future<void> _login()async{await Navigator.push<void>(context,MaterialPageRoute<void>(builder:(_)=>AuthPage(supabaseAvailable:widget.supabaseAvailable)));if(mounted)setState(()=>notice=null);}
 Future<void> restore()async{
 if(!widget.supabaseAvailable){showMessage('Supabase कनेक्शन उपलब्ध नहीं है।',error:true);return;}
 final user=client.auth.currentUser;if(user==null){showMessage('पहले लॉगिन करें।',error:true);return;}
 setState(()=>busy=true);
 try{
 final row=await client.from('user_backups').select('payload,schema_version,updated_at').eq('user_id',user.id).maybeSingle();
 if(row==null){showMessage('इस अकाउंट का कोई क्लाउड बैकअप नहीं मिला।');}
 else if((row['schema_version'] as num?)?.toInt()!=1){showMessage('यह बैकअप इस ऐप संस्करण के अनुकूल नहीं है।',error:true);}
 else{
 if(!mounted)return;
 final confirmed=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('क्लाउड बैकअप रीस्टोर करें?'),content:const Text('यह इस फोन के मौजूदा स्थानीय रिकॉर्ड को क्लाउड बैकअप से बदल देगा। रीस्टोर करने के बाद इस फोन के पुराने स्थानीय रिकॉर्ड वापस नहीं मिलेंगे।'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('रद्द करें')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('रीस्टोर करें'))]));
 if(confirmed==true){await LocalStore.write(user.id,jsonEncode(row['payload']));await widget.onRestore();showMessage('क्लाउड बैकअप इस डिवाइस पर रीस्टोर हो गया।');}
 }
 }on PostgrestException catch(e){showMessage('रीस्टोर त्रुटि: ${e.message}',error:true);}catch(_){showMessage('रीस्टोर पूरा नहीं हुआ। इंटरनेट और लॉगिन जाँचें।',error:true);}
 if(mounted)setState(()=>busy=false);
 }
 @override Widget build(BuildContext context){
 final user=widget.supabaseAvailable?client.auth.currentUser:null;
 return Scaffold(bottomNavigationBar:const BannerAdSlot(),appBar:AppBar(title:const Text('डेटा बैकअप')),body:ListView(padding:const EdgeInsets.all(20),children:[
 Container(padding:EdgeInsets.all(18),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(18)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('आपके रिकॉर्ड का सुरक्षित बैकअप',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),SizedBox(height:7),Text('लॉगिन रहने पर आपके रिकॉर्ड अपने-आप क्लाउड में सिंक होते रहते हैं। इंटरनेट न होने पर रिकॉर्ड फोन में सुरक्षित रहते हैं; कनेक्शन लौटने पर ऐप चलते समय या दोबारा खोलने पर सिंक फिर शुरू होता है। ऐप पूरी तरह बंद रहने पर बैकग्राउंड सिंक की गारंटी नहीं है। जरूरत पड़ने पर आप क्लाउड से रिकॉर्ड रीस्टोर कर सकते हैं। यह अभी स्नैपशॉट सिंक है; एक ही अकाउंट को एक समय पर एक फोन पर इस्तेमाल करें। दो फोन पर एक साथ किए गए बदलाव अपने-आप मर्ज नहीं होते।',style:TextStyle(color:Colors.white70,fontSize:12))])),
 const SizedBox(height:18),
 if(!widget.supabaseAvailable)Text('Supabase कनेक्शन उपलब्ध नहीं है।',style:TextStyle(color:red))
 else if(user==null)...[Text('क्लाउड बैकअप के लिए पहले लॉगिन करें।',style:TextStyle(color:navy,fontWeight:FontWeight.w700)),SizedBox(height:10),FilledButton(onPressed:busy?null:_login,child:Text('लॉगिन करें'))]
 else ...[Text('लॉगिन अकाउंट: ${user.email??'ईमेल उपलब्ध नहीं'}',style:TextStyle(color:navy,fontWeight:FontWeight.w700)),SizedBox(height:14),OutlinedButton.icon(onPressed:busy?null:restore,icon:Icon(Icons.cloud_download_outlined),label:Text('क्लाउड बैकअप रीस्टोर करें'))],
 if(busy)const Padding(padding:EdgeInsets.all(18),child:Center(child:CircularProgressIndicator())),
 if(notice!=null)Padding(padding:EdgeInsets.only(top:14),child:Text(notice!,style:TextStyle(color:noticeError?red:green,fontSize:12,fontWeight:FontWeight.w700)))
 ]));
 }
}
class TransactionHistoryPage extends StatelessWidget{
 final List<Record> items;final bool english;
 const TransactionHistoryPage({super.key,required this.items,required this.english});
 @override Widget build(BuildContext context){
  final sorted=[...items]..sort((a,b)=>(b.createdAt??DateTime(2000)).compareTo(a.createdAt??DateTime(2000)));
  return ListView(padding:const EdgeInsets.all(17),children:[
   heading(english?'Transaction History':'ट्रांजैक्शन हिस्ट्री',english?'Successful mobile recharges and bill payments':'रिचार्ज और बिल पेमेंट के सफल रिकॉर्ड'),
   const SizedBox(height:14),
   if(sorted.isEmpty)Container(padding:EdgeInsets.all(22),decoration:BoxDecoration(color:surfaceColor,borderRadius:BorderRadius.circular(18),border:Border.all(color:borderColor)),child:Column(children:[
    Icon(Icons.receipt_long_outlined,color:blue,size:42),SizedBox(height:12),
    Text(english?'No transactions yet':'अभी कोई ट्रांजैक्शन नहीं है',style:TextStyle(color:navy,fontSize:16,fontWeight:FontWeight.w900)),
    const SizedBox(height:7),
    Text(english?'Successful recharge and bill payment records will appear here.':'जब रिचार्ज और बिल पेमेंट सेवा सक्रिय होगी, सफल भुगतान का रिकॉर्ड यहाँ दिखेगा।',style:TextStyle(color:muted,fontSize:12),textAlign:TextAlign.center),
   ]))
   else ...sorted.map((e)=>Container(margin:EdgeInsets.only(bottom:9),padding:EdgeInsets.all(14),decoration:BoxDecoration(color:surfaceColor,borderRadius:BorderRadius.circular(15),border:Border.all(color:borderColor)),child:Row(children:[
    CircleAvatar(backgroundColor:darkModeEnabled?Color(0xFF29496D):Color(0xFFE8EEF6),child:Icon(e.icon,color:blue)),
    const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(e.name,style:TextStyle(color:navy,fontWeight:FontWeight.w800)),Text(e.detail,style:TextStyle(color:muted,fontSize:11)),
     Text(e.createdAt?.toLocal().toString()??'',style:TextStyle(color:muted,fontSize:10))
    ])),Text('₹${money(e.amount)}',style:TextStyle(color:green,fontWeight:FontWeight.w900))
   ]))),
   const SizedBox(height:8),
   Text(english?'Only successful service transactions are listed.':'इस सूची में केवल सफल सर्विस ट्रांजैक्शन दिखेंगे।',style:TextStyle(color:muted,fontSize:10))
  ]);
 }
}
class PrivacyPolicyPage extends StatelessWidget{
 final bool english;
 const PrivacyPolicyPage({super.key,this.english=false});
 static const List<List<String>> _hi=[
  ['1. यह नीति किस पर लागू है','यह नीति Bharat Saathi Android ऐप, अकाउंट, लिंक्ड खाता, रेफरल/कमीशन जानकारी और स्वचालित क्लाउड सिंक पर लागू होती है। ऐप इस्तेमाल करने के लिए अकाउंट और लॉगिन आवश्यक है।'],
  ['2. ऐप में दर्ज और डिवाइस पर सेव डेटा','आप नाम, ईमेल, मोबाइल नंबर, व्यक्तिगत और दुकान के खाते, खर्च तथा सेवा रिकॉर्ड दर्ज कर सकते हैं। रिकॉर्ड पहले डिवाइस के स्थानीय SQLite डेटाबेस में सेव होते हैं।'],
  ['3. अकाउंट और लॉगिन जानकारी','रजिस्ट्रेशन में Supabase Auth ईमेल और पासवर्ड संभालता है। आपका नाम और 10 अंकों का मोबाइल नंबर प्रोफाइल से जुड़ता है। ईमेल कन्फर्म होने के बाद मोबाइल नंबर और पासवर्ड से लॉगिन होता है। मोबाइल नंबर अभी SMS OTP से सत्यापित नहीं होता। लॉगिन से पहले मोबाइल नंबर खोजने की सेवा ईमेल नहीं दिखाती; सफल लॉगिन के बाद अकाउंट ईमेल बैकअप स्क्रीन पर दिख सकता है। पासवर्ड ऐप में पढ़ने योग्य रूप में सेव नहीं होता।'],
  ['4. हर अकाउंट का अलग डेटा और ऑटोमैटिक क्लाउड सिंक','डिवाइस पर स्थानीय रिकॉर्ड लॉगिन किए हुए अकाउंट की अलग पहचान के अंतर्गत रखे जाते हैं। एक ही फोन पर अलग अकाउंट का स्थानीय डेटा अलग रहता है। लॉगिन रहने और इंटरनेट उपलब्ध होने पर ऐप रिकॉर्ड का स्नैपशॉट उसी अकाउंट के Supabase क्लाउड बैकअप में अपने-आप सिंक करता है। बदलाव के बाद सिंक शेड्यूल होता है; ऐप चलते समय समय-समय पर और दोबारा खुलने पर पुनः प्रयास होता है। ऑफलाइन रिकॉर्ड डिवाइस पर रहते हैं। ऐप पूरी तरह बंद रहने पर बैकग्राउंड सिंक की गारंटी नहीं है। उसी अकाउंट से दूसरे डिवाइस पर लॉगिन करके उपलब्ध बैकअप रीस्टोर किया जा सकता है। यह स्नैपशॉट बैकअप है, हर रिकॉर्ड का अलग सर्वर-लेजर सिंक नहीं। एक ही अकाउंट को एक समय पर एक फोन पर इस्तेमाल करें; अलग-अलग फोन पर एक साथ किए गए बदलाव अपने-आप मर्ज नहीं होते। पुराने संस्करण से अपडेट करने पर पुराने स्थानीय स्नैपशॉट को किसी अकाउंट में जोड़ने से पहले ऐप पुष्टि पूछता है। केवल सही पुराने अकाउंट की पुष्टि करने पर और तभी डेटा जोड़ा जाएगा जब उस अकाउंट में पहले से रिकॉर्ड न हों। मौजूदा रिकॉर्ड कभी ओवरराइट नहीं होंगे; इसलिए पहले उसी अकाउंट से लॉगिन करें जो पहले इस फोन पर इस्तेमाल होता था।'],
  ['5. लिंक्ड खाता और रेफरल जानकारी','लिंक्ड खाता इस्तेमाल करने पर संबंधित मोबाइल नंबर, दुकान/प्रदर्शन नाम, जुड़े खातों का संबंध और प्रतिभागियों द्वारा दर्ज उधारी/भुगतान तथा नोट Supabase में प्रोसेस होते हैं। रेफरल/कमीशन सुविधा इस्तेमाल करने पर रेफरल कोड, पात्रता और कमीशन रिकॉर्ड भी प्रोसेस हो सकते हैं। संबंधित जानकारी सुविधा के नियमों के अनुसार दिखाई जाती है।'],
  ['6. विज्ञापन और तकनीकी जानकारी','ऐप में Google Mobile Ads SDK का बैनर विज्ञापन घटक शामिल है। मौजूदा डेवलपमेंट बिल्ड में Google के टेस्ट विज्ञापन आईडी हैं। Google SDK IP पता, विज्ञापन/ऐप पहचानकर्ता, विज्ञापन इंटरैक्शन और डायग्नोस्टिक जानकारी प्रोसेस कर सकता है। वास्तविक प्रोसेसिंग SDK संस्करण और डिवाइस सेटिंग पर निर्भर करती है।'],
  ['7. डेटा का उपयोग और सेवा प्रदाता','जानकारी का उपयोग अकाउंट लॉगिन, रिकॉर्ड सेव करने, ऑटोमैटिक सिंक/रीस्टोर, लिंक्ड खाता, रेफरल/कमीशन, सुरक्षा और विज्ञापन के लिए होता है। Supabase Auth, डेटाबेस और क्लाउड सेवा देता है। Google Mobile Ads विज्ञापन SDK देता है। हम व्यक्तिगत जानकारी बेचते नहीं हैं। ऐप में Recharge, BBPS, UPI भुगतान/ट्रांसफर और अन्य बाहरी भुगतान सेवाएँ अभी Coming Soon हैं; इन्हें चालू सेवा न समझें।'],
  ['8. सुरक्षा, स्टोरेज और डेटा की अवधि','डिवाइस और सर्वर के बीच संचार HTTPS/TLS से होता है। स्थानीय रिकॉर्ड ऐप के निजी डिवाइस स्टोरेज में रहते हैं; डिवाइस बैकअप चालू होने पर Android सिस्टम बैकअप में भी ऐप का निजी डेटा शामिल हो सकता है, जिसकी गारंटी नहीं है। यह Supabase क्लाउड सिंक से अलग है। ऐप-स्तर पर SQLite डेटाबेस एन्क्रिप्शन अलग से लागू होने की पुष्टि नहीं है। ऐप डेटा साफ करने या ऐप हटाने से स्थानीय कॉपी मिट सकती है। क्लाउड रिकॉर्ड अकाउंट सक्रिय रहने या सेवा देने के लिए आवश्यक अवधि तक रखे जा सकते हैं। किसी ऑनलाइन सेवा में पूर्ण सुरक्षा की गारंटी नहीं दी जा सकती।'],
  ['9. अकाउंट हटाना और आपकी पसंद','ऐप में अभी अकाउंट हटाने का बटन उपलब्ध नहीं है। अकाउंट हटाने के लिए बाहरी अनुरोध पेज https://annukumar6280-glitch.github.io/Bharat-Saathi-/delete-account.html खोलें या सहायता WhatsApp पर संपर्क करें। अकाउंट का स्वामित्व सत्यापित करने के बाद अनुरोध की समीक्षा की जाएगी। दूसरे डिवाइस पर पहले से सेव स्थानीय कॉपी अपने-आप मिटने की गारंटी नहीं है। इंटरनेट न होने पर पहले से लॉगिन सत्र में स्थानीय रिकॉर्ड उपलब्ध हो सकते हैं; नया लॉगिन करने के लिए इंटरनेट आवश्यक है।'],
  ['10. बच्चों की गोपनीयता','Bharat Saathi सामान्य उत्पादकता, खाता और खर्च प्रबंधन ऐप है, बच्चों के लिए बनाया गया ऐप नहीं है। बच्चे की व्यक्तिगत जानकारी दर्ज न करें।'],
  ['11. नीति में बदलाव','ऐप की सुविधाओं, SDK या कानूनी आवश्यकताओं में बदलाव होने पर नीति अपडेट की जाएगी। प्रभावी तारीख इस पेज पर दिखाई जाएगी।'],
  ['12. संपर्क','गोपनीयता, डेटा या अकाउंट अनुरोध के लिए Bharat Saathi सहायता WhatsApp 916283398317 पर संपर्क करें। पासवर्ड या OTP कभी साझा न करें।']
 ];
 static const List<List<String>> _en=[
  ['1. Scope','This policy applies to the Bharat Saathi Android app, user accounts, linked khata, referral/commission information and automatic cloud synchronization. An account and sign-in are required to use the app.'],
  ['2. Information entered and stored on the device','You may provide your name, email address and mobile number, and enter personal or shop khata entries, linked-khata records, expenses and service records. Records are first saved in the device’s local SQLite database.'],
  ['3. Account and login information','Supabase Auth handles your registration email and password. Your name and 10-digit mobile number are associated with your profile. After email confirmation, you can sign in with your mobile number and password. The phone lookup does not reveal the account email before password verification; after successful login, the account email may be displayed to the signed-in user on the backup screen. The app does not store your password in readable form.'],
  ['4. Account separation and automatic cloud sync','Local records are stored under the identity of the signed-in account, separately from other accounts on the same device. While signed in and connected to the internet, the app automatically synchronizes a snapshot to that account’s Supabase cloud-backup record. Sync is scheduled after changes and retried periodically while the app is running and when it resumes. Offline records remain on the device. Background sync is not guaranteed while the app is fully closed. The latest available snapshot can be restored on another device by signing in to the same account. This is snapshot backup, not row-by-row synchronization to a server-side accounting ledger. Use one device per account at a time; concurrent edits on different devices are not automatically merged. When upgrading from an older version, the app asks which account should receive the previous single local snapshot. It is assigned only after confirmation; sign in first with the account that previously used the phone and confirm only if it is the correct account.'],
  ['5. Linked khata and referral information','If you use linked khata, the app processes relevant mobile numbers, shop/display names, account relationships and credit/payment entries and notes created by participants. If you use referral/commission features, referral codes, eligibility and commission records may also be processed. Information is made available according to each feature’s access rules.'],
  ['6. Advertising and diagnostics','The app includes the Google Mobile Ads SDK banner-ad component. The current development build uses Google test ad identifiers. The SDK may process IP address, advertising or app-set identifiers, ad interactions and diagnostic information. Actual processing depends on SDK version and device settings.'],
  ['7. Uses and service providers','Information is used for account login, local record keeping, automatic sync/restore, linked khata, referral/commission, security and advertising. Supabase provides authentication, database and cloud services. Google provides the mobile advertising SDK. We do not sell personal information. Recharge, BBPS, UPI payments/transfers and other external payment services are currently marked Coming Soon and are not active payment services.'],
  ['8. Security, storage and retention','Data sent between the device and servers uses HTTPS/TLS. Local records are stored in the app’s private device storage. Android system backup may also include app-private data if device backup is enabled; this is controlled by Android/Google settings and is not guaranteed. It is separate from Supabase cloud sync. Separate app-level encryption of the SQLite database has not been implemented. Local data may be erased if you clear app data or uninstall the app. Cloud account data may be retained while your account is active or as needed to provide the service. No online service can guarantee absolute security.'],
  ['9. Account deletion and your choices','The app currently has no in-app account-deletion button. To request deletion, use the external request page at https://annukumar6280-glitch.github.io/Bharat-Saathi-/delete-account.html or contact support through WhatsApp. We review requests after verifying account ownership. Local copies already stored on other devices may not be erased automatically. An existing signed-in session may access local records offline; internet is required for a new sign-in.'],
  ['10. Children’s privacy','Bharat Saathi is a general productivity, khata and expense-management app and is not designed for children. Do not enter a child’s personal information.'],
  ['11. Policy changes','We may update this policy when app features, SDKs or legal requirements change. The effective date will be shown on this page.'],
  ['12. Contact','For privacy, data or account requests, contact Bharat Saathi support on WhatsApp: +91 6283398317. Never share your password or OTP.']
 ];
 @override Widget build(BuildContext context){
  final sections=english?_en:_hi;
  return Scaffold(appBar:AppBar(title:Text(english?'Privacy Policy':'प्राइवेसी पॉलिसी')),body:ListView(padding:const EdgeInsets.fromLTRB(16,8,16,28),children:[
   Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(english?'Bharat Saathi Privacy Policy':'भारत साथी – गोपनीयता नीति',style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
    const SizedBox(height:6),Text(english?'Effective date: 15 November 2026':'प्रभावी तारीख: 15 नवंबर 2026',style:const TextStyle(color:Colors.white70,fontSize:12))
   ])),
   const SizedBox(height:8),
   Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:surfaceColor,borderRadius:BorderRadius.circular(14),border:Border.all(color:borderColor)),child:Text(english?'Summary: Your records are stored locally under your signed-in account. When you are signed in and internet is available, the app automatically syncs that account’s snapshot to the cloud.':'सारांश: आपके रिकॉर्ड आपके लॉगिन अकाउंट के अनुसार अलग सेव होते हैं। लॉगिन और इंटरनेट उपलब्ध होने पर ऐप उसी अकाउंट का स्नैपशॉट अपने-आप क्लाउड बैकअप में सिंक करता है।',style:TextStyle(color:navy,fontWeight:FontWeight.w700))),
   for(final section in sections)Card(color:surfaceColor,margin:const EdgeInsets.only(top:10),child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(section[0],style:TextStyle(color:navy,fontSize:15,fontWeight:FontWeight.w900)),
    const SizedBox(height:7),Text(section[1],style:TextStyle(color:muted,fontSize:13,height:1.55))
   ]))),
   const SizedBox(height:14),Center(child:Text('© 2026 Bharat Saathi',style:TextStyle(color:muted,fontSize:11)))
  ]));
 }
}

class ProfilePage extends StatelessWidget{
 final bool supabaseAvailable,english,darkMode;final Future<void> Function() onRestore;final ValueChanged<bool> onLanguage,onDarkMode;
 final List<Record> expensesList,khata,personalTransactions;
 const ProfilePage({super.key,required this.supabaseAvailable,required this.onRestore,required this.expensesList,required this.khata,required this.personalTransactions,required this.english,required this.onLanguage,required this.darkMode,required this.onDarkMode});
 @override Widget build(BuildContext context){
  final user=supabaseAvailable?Supabase.instance.client.auth.currentUser:null;
  final admin=user!=null&&(user.appMetadata['role']=='admin'||user.appMetadata['role']=='super_admin');
  return ListView(padding:const EdgeInsets.all(17),children:[
   heading(english?'Profile & Settings':'प्रोफाइल और सेटिंग',english?'Manage your account':'अपने अकाउंट को मैनेज करें'),
   setting(Icons.lock_outline,english?'Account & Security':'अकाउंट और सुरक्षा',english?'Login or create your account':'लॉगिन करें या नया अकाउंट रजिस्टर करें',()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>AuthPage(supabaseAvailable:supabaseAvailable)))),
   setting(Icons.privacy_tip_outlined,english?'Privacy Policy':'प्राइवेसी पॉलिसी',english?'How Bharat Saathi handles your data':'आपका डेटा कैसे उपयोग होता है',()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const PrivacyPolicyPage(english:false)))),
   Card(color:surfaceColor,child:ListTile(leading:Icon(Icons.language),title:Text('भाषा / Language'),trailing:DropdownButton<bool>(value:english,items:const[DropdownMenuItem(value:false,child:Text('हिंदी')),DropdownMenuItem(value:true,child:Text('English'))],onChanged:(v){if(v!=null)onLanguage(v);}))),
   SwitchListTile(secondary:Icon(Icons.dark_mode_outlined,color:blue),title:Text(english?'Dark theme':'डार्क थीम',style:TextStyle(color:navy,fontWeight:FontWeight.w800)),subtitle:Text(english?'Professional deep-blue appearance':'ऑन करने पर पूरे ऐप में प्रोफेशनल ब्लू डार्क थीम लागू होगी',style:TextStyle(color:muted,fontSize:11)),value:darkMode,onChanged:onDarkMode,activeThumbColor:blue,contentPadding:EdgeInsets.symmetric(horizontal:14)),
    setting(Icons.percent_rounded,english?'Commission List':'कमीशन लिस्ट',english?'Self and referral commission by service':'हर सर्विस का सेल्फ और रेफरल कमीशन',()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CommissionListPage(supabaseAvailable:supabaseAvailable)))),
   setting(Icons.share_outlined,english?'Refer & Earn':'रेफर करें और कमाएँ',english?'Your referral code and referral history':'आपका रेफरल कोड और रेफरल जानकारी',()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ReferralPage(supabaseAvailable:supabaseAvailable)))),
   if(admin)setting(Icons.admin_panel_settings_outlined,english?'Admin Commission Settings':'एडमिन कमीशन सेटिंग',english?'Configure service and referral rates':'सर्विस और रेफरल कमीशन की दरें सेट करें',()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const AdminCommissionPage()))),
   setting(Icons.sync,english?'Connected Khata':'लिंक किया हुआ खाता',english?'Shared shopkeeper and customer ledger':'दुकानदार और ग्राहक का साझा खाता',()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LinkedKhataPage(supabaseAvailable:supabaseAvailable)))),
   setting(Icons.help_outline,english?'Help Centre':'सहायता केंद्र','WhatsApp: 6283398317',()=>launchUrl(Uri.parse('https://wa.me/916283398317?text='+Uri.encodeComponent('नमस्ते Bharat Saathi सहायता केंद्र')),mode:LaunchMode.externalApplication)),
   setting(Icons.cloud_sync,english?'Automatic cloud sync':'ऑटोमैटिक क्लाउड सिंक',english?'Records sync automatically; restore from cloud':'रिकॉर्ड अपने-आप सिंक होते हैं; क्लाउड से रीस्टोर करें',()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CloudBackupPage(supabaseAvailable:supabaseAvailable,onRestore:onRestore)))),
  ]);
 }
}
class CommissionListPage extends StatefulWidget{
 final bool supabaseAvailable;const CommissionListPage({super.key,required this.supabaseAvailable});
 @override State<CommissionListPage> createState()=>_CommissionListPageState();
}
class _CommissionListPageState extends State<CommissionListPage>{
 bool loading=true;String? error;String referralCode='';List<Map<String,dynamic>> rules=[];
 Future<void> _load()async{
  if(!widget.supabaseAvailable){setState(()=>loading=false);return;}
  final user=Supabase.instance.client.auth.currentUser;
  if(user==null){setState(()=>loading=false);return;}
  try{
   final p=await Supabase.instance.client.from('commerce_profiles').select('referral_code').eq('user_id',user.id).maybeSingle();
   final r=await Supabase.instance.client.from('service_commission_rules').select().eq('is_active',true).order('service_name');
   if(mounted)setState((){referralCode=(p?['referral_code'] as String?)??'';rules=r.map((e)=>Map<String,dynamic>.from(e)).toList();loading=false;});
  }catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
 }
 @override void initState(){super.initState();_load();}
 String pct(dynamic v)=>'${((v as num?)??0).toStringAsFixed(2)}%';
 @override Widget build(BuildContext context){
  final signed=widget.supabaseAvailable&&Supabase.instance.client.auth.currentUser!=null;
  return Scaffold(bottomNavigationBar:const BannerAdSlot(),appBar:AppBar(title:const Text('कमीशन लिस्ट')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
   if(!signed)Card(color:surfaceColor,child:ListTile(leading:const Icon(Icons.lock_outline),title:const Text('कमीशन देखने के लिए लॉगिन करें'),subtitle:const Text('Self और Direct Referral Commission सभी यूज़र के लिए उपलब्ध हैं'),onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>AuthPage(supabaseAvailable:widget.supabaseAvailable))))),
   if(error!=null)Text(error!,style:TextStyle(color:red)),
   if(signed)Container(padding:EdgeInsets.all(16),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('BHARAT SAATHI • FREE',style:TextStyle(color:gold,fontWeight:FontWeight.w900,letterSpacing:1)),
    const SizedBox(height:5),const Text('कोई Paid Membership नहीं। सभी योग्य यूज़र Self और Direct Referral Service Commission के पात्र हैं।',style:TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w700)),
    if(referralCode.isNotEmpty)Text('Referral ID: $referralCode',style:const TextStyle(color:Colors.white70,fontSize:11))
   ])),
   if(signed&&rules.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('अभी एडमिन ने किसी सर्विस की कमीशन दर सेट नहीं की है।')),
   ...rules.map((r)=>Card(color:surfaceColor,child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(r['service_name']?.toString()??r['service_code']?.toString()??'Service',style:TextStyle(color:navy,fontWeight:FontWeight.w900,fontSize:15)),
    const SizedBox(height:9),
    _commissionLine('Self Commission',pct(r['self_commission_pct'])),
    _commissionLine('Direct Referral Service Commission',pct(r['referral_commission_pct'])),
   ])))),
   if(signed)Card(color:surfaceColor,child:Padding(padding:EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('पहला सफल Referral Reward',style:TextStyle(color:navy,fontWeight:FontWeight.w900)),
    SizedBox(height:5),Text('आपके Referral से जुड़ा यूज़र पहली सफल Recharge या Bill Payment पूरी करेगा, तो आपको एक बार ₹10 मिलेंगे।')
   ]))),
   const SizedBox(height:12),
   Text('कमीशन की दरें एडमिन तय करता है। कमीशन केवल सफल और सत्यापित सर्विस ट्रांजैक्शन पर मिलेगा। सर्विस पर कमीशन डिस्काउंट का विकल्प Gateway और सर्विस पार्टनर जुड़ने के बाद सक्रिय होगा। बैंक / UPI निकासी उपलब्ध नहीं है।',style:TextStyle(color:muted,fontSize:11))
  ]));
 }
 Widget _commissionLine(String label,String value)=>Padding(padding:EdgeInsets.symmetric(vertical:3),child:Row(children:[Expanded(child:Text(label,style:TextStyle(color:muted,fontSize:12))),Text(value,style:TextStyle(color:navy,fontWeight:FontWeight.w900,fontSize:13))]));
}
class CommerceWalletPage extends StatefulWidget{
 final bool supabaseAvailable;const CommerceWalletPage({super.key,required this.supabaseAvailable});
 @override State<CommerceWalletPage> createState()=>_CommerceWalletPageState();
}
class _CommerceWalletPageState extends State<CommerceWalletPage>{
 Map<String,dynamic>? wallet;List<Map<String,dynamic>> history=[];bool loading=true;String? error;
 Future<void> _load()async{
  final user=widget.supabaseAvailable?Supabase.instance.client.auth.currentUser:null;
  if(user==null){if(mounted)setState(()=>loading=false);return;}
  try{
   final w=await Supabase.instance.client.from('commerce_wallets').select('commission_balance').eq('user_id',user.id).maybeSingle();
   final h=await Supabase.instance.client.from('commerce_wallet_transactions').select().eq('user_id',user.id).eq('wallet_type','commission').order('created_at',ascending:false).limit(30);
   if(mounted)setState((){wallet=w;history=h.map((e)=>Map<String,dynamic>.from(e)).toList();loading=false;});
  }catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
 }
 @override void initState(){super.initState();_load();}
 @override Widget build(BuildContext context)=>Scaffold(bottomNavigationBar:const BannerAdSlot(),appBar:AppBar(title:const Text('Commission Wallet')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
  if(!widget.supabaseAvailable||Supabase.instance.client.auth.currentUser==null)const Text('कमीशन देखने के लिए पहले लॉगिन करें।'),
  if(error!=null)Text(error!,style:TextStyle(color:red)),
  _walletCard('Commission Wallet','Self और Direct Referral Commission की कमाई','₹${(wallet?['commission_balance'] as num?)?.toStringAsFixed(2)??'0.00'}',Icons.savings_outlined),
  const SizedBox(height:12),
  Text('कमीशन राशि अगली Recharge या Bill Payment के checkout पर छूट के रूप में लगाई जाएगी। Add Money या अलग Service Wallet नहीं होगा।',style:TextStyle(color:muted,fontSize:12)),
  const SizedBox(height:8),
  Text('सुरक्षित आरक्षण और असफल भुगतान पर कमीशन वापसी का सर्वर सिस्टम तैयार है। Recharge/Bill Payment अभी Coming Soon हैं; Gateway और सर्विस पार्टनर जुड़ने के बाद checkout पर “कमीशन इस्तेमाल करें” विकल्प सक्रिय होगा। बैंक / UPI निकासी उपलब्ध नहीं है।',style:TextStyle(color:muted,fontSize:11)),
  SizedBox(height:16),Text('Commission Transactions',style:TextStyle(color:navy,fontWeight:FontWeight.w900,fontSize:16)),
  ...history.map((e)=>ListTile(dense:true,leading:Icon(Icons.savings_outlined,color:blue),title:Text(e['description']?.toString()??e['transaction_type'].toString()),subtitle:Text('${e['created_at']}'),trailing:Text('₹${(e['amount'] as num).toStringAsFixed(2)}')))
 ]));
 Widget _walletCard(String title,String subtitle,String amount,IconData icon)=>Container(padding:EdgeInsets.all(16),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(17)),child:Row(children:[Icon(icon,color:gold,size:28),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),Text(subtitle,style:TextStyle(color:Colors.white70,fontSize:11))])),Text(amount,style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:18))]));
}
class ReferralPage extends StatefulWidget{
 final bool supabaseAvailable;const ReferralPage({super.key,required this.supabaseAvailable});
 @override State<ReferralPage> createState()=>_ReferralPageState();
}
class _ReferralPageState extends State<ReferralPage>{
 String code='';bool loading=true;String? error;
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{
  final u=widget.supabaseAvailable?Supabase.instance.client.auth.currentUser:null;
  if(u==null){setState(()=>loading=false);return;}
  try{final r=await Supabase.instance.client.from('commerce_profiles').select('referral_code').eq('user_id',u.id).maybeSingle();if(mounted)setState((){code=(r?['referral_code'] as String?)??'';loading=false;});}catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
 }
 Future<void> _apply()async{
  if(!widget.supabaseAvailable||Supabase.instance.client.auth.currentUser==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('पहले लॉगिन करें।')));return;}
  final c=TextEditingController();final value=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Referral Code लगाएँ'),content:TextField(controller:c,decoration:const InputDecoration(labelText:'Referral Code')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('रद्द करें')),FilledButton(onPressed:()=>Navigator.pop(ctx,c.text.trim()),child:const Text('Apply'))]));
  if(value==null||value.isEmpty)return;
  try{await Supabase.instance.client.rpc('apply_bharat_saathi_referral_code',params:{'p_referral_code':value});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Referral Code जुड़ गया।')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Referral Code लागू नहीं हुआ: $e')));}
 }
 @override Widget build(BuildContext context)=>Scaffold(bottomNavigationBar:const BannerAdSlot(),appBar:AppBar(title:const Text('Refer & Earn')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(18),children:[
  if(!widget.supabaseAvailable||Supabase.instance.client.auth.currentUser==null)const Text('रेफरल कोड देखने के लिए लॉगिन करें।'),
  if(error!=null)Text(error!,style:TextStyle(color:red)),
  Container(padding:EdgeInsets.all(18),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('आपका Referral Code',style:TextStyle(color:Colors.white70)),SizedBox(height:8),Text(code.isEmpty?'—':code,style:TextStyle(color:gold,fontSize:27,fontWeight:FontWeight.w900)),SizedBox(height:12),Row(children:[Expanded(child:OutlinedButton(onPressed:code.isEmpty?null:()=>Clipboard.setData(ClipboardData(text:code)),child:Text('Copy Code'))),SizedBox(width:8),Expanded(child:FilledButton(onPressed:code.isEmpty?null:()=>Share.share('Bharat Saathi से जुड़ें। मेरा Referral Code: $code'),child:Text('Share')))])])),
  const SizedBox(height:12),OutlinedButton(onPressed:_apply,child:const Text('किसी का Referral Code लगाएँ')),
  Card(color:surfaceColor,child:Padding(padding:EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('₹10 First Successful Referral Reward',style:TextStyle(color:navy,fontWeight:FontWeight.w900)),
   SizedBox(height:5),Text('आपके Referral से जुड़ा यूज़र पहली सफल Recharge या Bill Payment पूरी करेगा, तो आपको ₹10 एक बार मिलेंगे।'),
   SizedBox(height:8),Text('इसके बाद उस यूज़र की योग्य सर्विस ट्रांजैक्शन पर आपको केवल Direct Referral Service Commission मिलेगा।')
  ])))
 ]));
}
class AdminCommissionPage extends StatefulWidget{const AdminCommissionPage({super.key});@override State<AdminCommissionPage> createState()=>_AdminCommissionPageState();}
class _AdminCommissionPageState extends State<AdminCommissionPage>{
 List<Map<String,dynamic>> rules=[];bool loading=true;String? error;
 Future<void> _load()async{try{final c=Supabase.instance.client;final a=await c.from('service_commission_rules').select().order('service_name');if(mounted)setState((){rules=a.map((e)=>Map<String,dynamic>.from(e)).toList();loading=false;});}catch(e){if(mounted)setState((){error=e.toString();loading=false;});}}
 @override void initState(){super.initState();_load();}
 Future<void> _editRule([Map<String,dynamic>? old])async{
  final code=TextEditingController(text:old?['service_code']?.toString()??''),name=TextEditingController(text:old?['service_name']?.toString()??'');
  final total=TextEditingController(text:old?['total_provider_commission_pct']?.toString()??'0'),company=TextEditingController(text:old?['company_share_pct']?.toString()??'0'),self=TextEditingController(text:old?['self_commission_pct']?.toString()??'0'),referral=TextEditingController(text:old?['referral_commission_pct']?.toString()??'0');
  final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(old==null?'नई सर्विस कमीशन':'कमीशन दर बदलें'),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
   TextField(controller:code,decoration:const InputDecoration(labelText:'Service code (unique)')),TextField(controller:name,decoration:const InputDecoration(labelText:'Service name')),
   TextField(controller:total,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Provider total commission %')),TextField(controller:company,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Company share %')),
   TextField(controller:self,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Self commission %')),TextField(controller:referral,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Direct referral commission %'))
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('रद्द करें')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('सेव करें'))]));
  if(ok!=true)return;
  try{final c=Supabase.instance.client;await c.from('service_commission_rules').upsert({'service_code':code.text.trim().toLowerCase(),'service_name':name.text.trim(),'total_provider_commission_pct':double.parse(total.text),'company_share_pct':double.parse(company.text),'self_commission_pct':double.parse(self.text),'referral_commission_pct':double.parse(referral.text),'updated_by':c.auth.currentUser!.id,'updated_at':DateTime.now().toUtc().toIso8601String()});await _load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('सेव नहीं हुआ: $e')));}
 }
 @override Widget build(BuildContext context)=>Scaffold(bottomNavigationBar:const BannerAdSlot(),appBar:AppBar(title:const Text('Admin Commission Settings')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
  if(error!=null)Text(error!,style:TextStyle(color:red)),
  Text('Service-wise Commission',style:TextStyle(color:navy,fontWeight:FontWeight.w900,fontSize:17)),
  Padding(padding:EdgeInsets.only(top:5,bottom:12),child:Text('सभी यूज़र के लिए Self Commission और केवल एक Direct Referral Level सेट करें। ₹10 का First Successful Referral Reward सिस्टम में निश्चित है।',style:TextStyle(color:muted,fontSize:12))),
  FilledButton.icon(onPressed:()=>_editRule(),icon:const Icon(Icons.add),label:const Text('नई सर्विस कमीशन जोड़ें')),
  ...rules.map((r)=>Card(color:surfaceColor,child:ListTile(title:Text(r['service_name'].toString()),subtitle:Text('Self ${r['self_commission_pct']}% • Direct Referral ${r['referral_commission_pct']}% • Company ${r['company_share_pct']}%'),trailing:IconButton(onPressed:()=>_editRule(r),icon:const Icon(Icons.edit_outlined)))))
 ]));
}
Widget heading(String a,String b)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:TextStyle(color:navy,fontSize:22,fontWeight:FontWeight.w900)),Text(b,style:TextStyle(color:muted,fontSize:11))]);
Widget setting(IconData i,String a,String b,[VoidCallback? onTap])=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(14),child:Container(margin:EdgeInsets.only(top:9),padding:EdgeInsets.all(14),decoration:BoxDecoration(color:surfaceColor,borderRadius:BorderRadius.circular(14)),child:Row(children:[Icon(i,color:blue),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:12)),Text(b,style:TextStyle(color:muted,fontSize:10))])),Icon(Icons.chevron_right,color:muted)])));
void openComingSoon(BuildContext context,String feature)=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ComingSoonPage(feature:feature)));

class _LinkedDetails extends StatefulWidget{
 final Map<String,dynamic> link;final bool retailer;final VoidCallback onCredit,onPayment;
 const _LinkedDetails({required this.link,required this.retailer,required this.onCredit,required this.onPayment});
 @override State<_LinkedDetails> createState()=>_LinkedDetailsState();
}
class _LinkedDetailsState extends State<_LinkedDetails>{
 List<Map<String,dynamic>> rows=[];double due=0;bool loading=true;RealtimeChannel? channel;
 @override void initState(){super.initState();_load();channel=Supabase.instance.client.channel('khata-detail-'+widget.link['id'].toString()).onPostgresChanges(event:PostgresChangeEvent.all,schema:'public',table:'khata_transactions',callback:(_)=>_load()).subscribe();}
 @override void dispose(){if(channel!=null)Supabase.instance.client.removeChannel(channel!);super.dispose();}
 Future<void> _load()async{try{final r=await Supabase.instance.client.from('khata_transactions').select('transaction_type,amount,note,created_at').eq('link_id',widget.link['id']).order('created_at',ascending:false);if(mounted)setState((){rows=r.map((e)=>Map<String,dynamic>.from(e)).toList();due=rows.fold<double>(0,(s,e)=>s+((e['transaction_type']=='credit'?1:-1)*(e['amount'] as num).toDouble()));loading=false;});}catch(_){if(mounted)setState(()=>loading=false);}}
 @override Widget build(BuildContext context){final phone=widget.retailer?(widget.link['customer_phone'] as String? ?? ''):(widget.link['retailer_phone'] as String? ?? '');return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text('कुल बाकी: ₹'+money(due),style:TextStyle(color:due>0?red:green,fontWeight:FontWeight.w900)),
 if(widget.retailer)Row(children:[Expanded(child:FilledButton(onPressed:widget.onCredit,child:Text('उधार दर्ज करें'))),SizedBox(width:6),Expanded(child:OutlinedButton(onPressed:widget.onPayment,child:Text('वापसी दर्ज करें')))])else OutlinedButton(onPressed:widget.onPayment,child:Text('वापसी दर्ज करें')),
 if(widget.retailer&&phone.isNotEmpty)TextButton.icon(onPressed:()=>launchUrl(Uri.parse('https://wa.me/91'+phone.replaceAll(RegExp(r'[^0-9]'),'')+'?text='+Uri.encodeComponent('नमस्ते, आपके Bharat Saathi खाते का बकाया ₹'+money(due)+' है।')),mode:LaunchMode.externalApplication),icon:const Icon(Icons.chat),label:const Text('WhatsApp संदेश')),
 if(loading)LinearProgressIndicator()else ...rows.take(8).map((e)=>Text((e['transaction_type']=='credit'?'उधार +₹':'वापसी −₹')+money((e['amount'] as num).toDouble())+' • '+(e['note']??''),style:TextStyle(color:muted,fontSize:11)))
 ]);}
}
class ComingSoonPage extends StatelessWidget{final String feature;const ComingSoonPage({super.key,required this.feature});@override Widget build(BuildContext context)=>Scaffold(bottomNavigationBar:const BannerAdSlot(),appBar:AppBar(title:Text(feature)),body:Center(child:Padding(padding:EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[Container(width:76,height:76,decoration:BoxDecoration(color:Color(0xFFFFF2D9),borderRadius:BorderRadius.circular(22)),child:Icon(Icons.hourglass_top_rounded,color:Color(0xFF9A6515),size:38)),SizedBox(height:18),Text(feature,style:TextStyle(color:navy,fontSize:21,fontWeight:FontWeight.w900),textAlign:TextAlign.center),SizedBox(height:9),Text('यह सुविधा अभी उपलब्ध नहीं है। अधिकृत सेवा प्रदाता, API credentials और आवश्यक सुरक्षा जाँच पूरी होने के बाद ही इसे चालू किया जाएगा।',style:TextStyle(color:muted,fontSize:13),textAlign:TextAlign.center),SizedBox(height:16),Chip(label:Text('COMING SOON'))]))));}
String money(num n){final s=n.round().toString();if(s.length<=3)return s;var h=s.substring(0,s.length-3);final t=s.substring(s.length-3);final g=<String>[];while(h.length>2){g.insert(0,h.substring(h.length-2));h=h.substring(0,h.length-2);}if(h.isNotEmpty)g.insert(0,h);return '${g.join(',')},$t';}
