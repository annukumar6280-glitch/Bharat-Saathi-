import 'dart:convert';
import 'dart:math';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
const supabaseUrl='https://nlfdqkkrwthobvwqfepl.supabase.co';
const supabasePublishableKey='sb_publishable_m7oDiOBmOztXrL93smgRsQ_MQXfbqKk';
Future<void> main()async{WidgetsFlutterBinding.ensureInitialized();var ready=false;try{await Supabase.initialize(url:supabaseUrl,publishableKey:supabasePublishableKey);ready=true;}catch(_){}runApp(BharatSaathiApp(supabaseAvailable:ready));}
class LocalStore {
 static Database? _db;
 static Future<Database> get database async {
  if(_db!=null)return _db!;
  final root=await getDatabasesPath();
  _db=await openDatabase(p.join(root,'bharat_saathi.db'),version:1,onCreate:(db,version)async{
   await db.execute('CREATE TABLE app_state (id INTEGER PRIMARY KEY CHECK (id = 1), payload TEXT NOT NULL, updated_at TEXT NOT NULL)');
  });
  return _db!;
 }
 static Future<String?> read()async{
  final db=await database;
  final rows=await db.query('app_state',columns:['payload'],where:'id = ?',whereArgs:[1],limit:1);
  return rows.isEmpty?null:rows.first['payload'] as String;
 }
 static Future<void> clear()async{final db=await database;await db.delete('app_state');}
 static Future<void> write(String payload)async{
  final db=await database;
  await db.transaction((txn)async{
   await txn.insert('app_state',{'id':1,'payload':payload,'updated_at':DateTime.now().toUtc().toIso8601String()},conflictAlgorithm:ConflictAlgorithm.replace);
  });
 }
}
const navy=Color(0xFF14233B),blue=Color(0xFF29496D),gold=Color(0xFFF2A93B),bg=Color(0xFFE7EBF1),muted=Color(0xFF788596),green=Color(0xFF16845B),red=Color(0xFFD95454);
class BharatSaathiApp extends StatelessWidget{final bool supabaseAvailable;const BharatSaathiApp({super.key,this.supabaseAvailable=false});@override Widget build(BuildContext context)=>MaterialApp(title:'Bharat Saathi',debugShowCheckedModeBanner:false,theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:navy),appBarTheme:const AppBarTheme(backgroundColor:bg,foregroundColor:navy,elevation:0)),home:RetailerHome(supabaseAvailable:supabaseAvailable));}
class Item{String name,detail;int qty;double price;Item(this.name,this.detail,this.qty,this.price);Map<String,dynamic> toJson()=>{'name':name,'detail':detail,'qty':qty,'price':price};factory Item.fromJson(Map<String,dynamic> j)=>Item(j['name'] as String,j['detail'] as String,(j['qty'] as num).toInt(),(j['price'] as num).toDouble());}
class Record{String name,detail;double amount;IconData icon;DateTime? createdAt;Record(this.name,this.detail,this.amount,this.icon,[DateTime? timestamp]):createdAt=timestamp??DateTime.now();Map<String,dynamic> toJson()=>{'name':name,'detail':detail,'amount':amount,'icon':icon.codePoint,'createdAt':createdAt?.toIso8601String()};factory Record.fromJson(Map<String,dynamic> j){final timestamp=j['createdAt'] is String?DateTime.tryParse(j['createdAt'] as String):null;return Record(j['name'] as String,j['detail'] as String,(j['amount'] as num).toDouble(),Icons.receipt_long,timestamp)..createdAt=timestamp;}}
class RetailerHome extends StatefulWidget{final bool supabaseAvailable;const RetailerHome({super.key,this.supabaseAvailable=false});@override State<RetailerHome> createState()=>_RetailerHomeState();}
class _RetailerHomeState extends State<RetailerHome>{
 int tab=0;double cash=0,expenses=0,personalBudget=0;String personalBudgetName='व्यक्तिगत खर्च सीमा';bool loaded=false,english=false;
 final _prefs=SharedPreferencesAsync();
 final products=<Item>[];
 final sales=<Record>[];
 final expensesList=<Record>[];
 final personalTransactions=<Record>[];
 final personalKhata=<Record>[];
 final khata=<Record>[];
 final purchases=<Record>[];
 final supplierLedger=<Record>[];
 final salesReturns=<Record>[];
 final stockAdjustments=<Record>[];
 @override void initState(){super.initState();_restore();}
 Future<void> _restore()async{if(mounted)setState(()=>loaded=false);cash=0;expenses=0;personalBudget=0;personalBudgetName='व्यक्तिगत खर्च सीमा';products.clear();sales.clear();expensesList.clear();khata.clear();personalTransactions.clear();purchases.clear();supplierLedger.clear();salesReturns.clear();stockAdjustments.clear();try{var raw=await LocalStore.read().timeout(const Duration(seconds:2));if(raw==null){raw=await _prefs.getString('bharat_saathi_store_v1').timeout(const Duration(seconds:2));if(raw!=null){await LocalStore.write(raw);}}if(raw!=null){final d=jsonDecode(raw) as Map<String,dynamic>;cash=(d['cash'] as num?)?.toDouble()??0;expenses=(d['expenses'] as num?)?.toDouble()??0;personalBudget=(d['personalBudget'] as num?)?.toDouble()??0;personalBudgetName=(d['personalBudgetName'] as String?)??'व्यक्तिगत खर्च सीमा';english=(d['language'] as String?)=='en';personalKhata.addAll((d['personalKhata'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));products.addAll((d['products'] as List? ?? []).map((e)=>Item.fromJson(Map<String,dynamic>.from(e as Map))));sales.addAll((d['sales'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));expensesList.addAll((d['expensesList'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));khata.addAll((d['khata'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));personalTransactions.addAll((d['personalTransactions'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));purchases.addAll((d['purchases'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));supplierLedger.addAll((d['supplierLedger'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));salesReturns.addAll((d['salesReturns'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));stockAdjustments.addAll((d['stockAdjustments'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));}}catch(_){}if(mounted)setState(()=>loaded=true);}
 Future<void> _persist()async{try{await LocalStore.write(jsonEncode({'cash':cash,'expenses':expenses,'personalBudget':personalBudget,'personalBudgetName':personalBudgetName,'products':products.map((e)=>e.toJson()).toList(),'sales':sales.map((e)=>e.toJson()).toList(),'expensesList':expensesList.map((e)=>e.toJson()).toList(),'khata':khata.map((e)=>e.toJson()).toList(),'personalTransactions':personalTransactions.map((e)=>e.toJson()).toList(),'personalKhata':personalKhata.map((e)=>e.toJson()).toList(),'language':english?'en':'hi','purchases':purchases.map((e)=>e.toJson()).toList(),'supplierLedger':supplierLedger.map((e)=>e.toJson()).toList(),'salesReturns':salesReturns.map((e)=>e.toJson()).toList(),'stockAdjustments':stockAdjustments.map((e)=>e.toJson()).toList()}));}catch(_){if(mounted)msg('डेटा इस डिवाइस पर डेटाबेस में सेव नहीं हो पाया');}}
 void msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),behavior:SnackBarBehavior.floating));
 Future<void> form(String title,String label,String valueLabel,void Function(String,double) save)async{
 final n=TextEditingController(),v=TextEditingController();
 await showModalBottomSheet<void>(context:context,isScrollControlled:true,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),builder:(c)=>Padding(padding:EdgeInsets.fromLTRB(20,22,20,20+MediaQuery.of(c).viewInsets.bottom),child:Column(mainAxisSize:MainAxisSize.min,children:[
 Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:16),
 TextField(controller:n,decoration:InputDecoration(labelText:label,prefixIcon:const Icon(Icons.edit_outlined))),
 const SizedBox(height:10),TextField(controller:v,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:valueLabel,prefixIcon:const Icon(Icons.currency_rupee))),
 const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton(style:FilledButton.styleFrom(backgroundColor:navy,padding:const EdgeInsets.all(15)),onPressed:(){final a=double.tryParse(v.text);if(n.text.trim().isEmpty||a==null||a<=0){msg('सही जानकारी भरें');return;}save(n.text.trim(),a);Navigator.pop(c);},child:const Text('सेव करें')))
 ])));
 }
 Future<void> sale()async{
 if(products.isEmpty){msg('बिक्री से पहले स्टॉक टैब में प्रोडक्ट जोड़ें');return;}
 final customer=TextEditingController(text:'Walk-in Customer');
 final quantity=TextEditingController(text:'1');
 Item selected=products.first;String paymentMode='नकद';
 await showModalBottomSheet<void>(context:context,isScrollControlled:true,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),builder:(sheetContext)=>StatefulBuilder(builder:(context,refresh)=>Padding(padding:EdgeInsets.fromLTRB(20,22,20,20+MediaQuery.of(context).viewInsets.bottom),child:Column(mainAxisSize:MainAxisSize.min,children:[
 const Text('नई बिक्री / बिल',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:15),
 TextField(controller:customer,decoration:const InputDecoration(labelText:'ग्राहक का नाम')),
 const SizedBox(height:10),
 DropdownButtonFormField<Item>(initialValue:selected,decoration:const InputDecoration(labelText:'प्रोडक्ट'),items:products.map((p)=>DropdownMenuItem<Item>(value:p,child:Text('${p.name} • स्टॉक ${p.qty}'))).toList(),onChanged:(p){if(p!=null)refresh(()=>selected=p);}),
 const SizedBox(height:10),TextField(controller:quantity,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'मात्रा')),
 const SizedBox(height:10),DropdownButtonFormField<String>(initialValue:paymentMode,decoration:const InputDecoration(labelText:'भुगतान प्रकार'),items:const[DropdownMenuItem(value:'नकद',child:Text('नकद / बैंक भुगतान')),DropdownMenuItem(value:'उधार',child:Text('ग्राहक उधार'))],onChanged:(v){if(v!=null)refresh(()=>paymentMode=v);}),
 const SizedBox(height:12),Align(alignment:Alignment.centerLeft,child:Text('बिक्री मूल्य: ₹${money(selected.price)} प्रति यूनिट',style:const TextStyle(color:muted,fontSize:12))),
 const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton(onPressed:(){final q=int.tryParse(quantity.text);if(customer.text.trim().isEmpty||q==null||q<1){msg('ग्राहक और सही मात्रा भरें');return;}if(q>selected.qty){msg('उपलब्ध स्टॉक से अधिक मात्रा नहीं बेच सकते');return;}if(selected.price<=0){msg('इस प्रोडक्ट का बिक्री मूल्य पहले सेट करें');return;}final total=selected.price*q;setState((){selected.qty-=q;sales.insert(0,Record(customer.text.trim(),'${selected.name} × $q • $paymentMode',total,Icons.receipt_long));if(paymentMode=='नकद'){cash+=total;}else{khata.insert(0,Record(customer.text.trim(),'बिक्री उधार • अभी',total,Icons.person));}});_persist();Navigator.pop(sheetContext);msg('बिक्री सेव हुई और स्टॉक अपडेट हुआ');},child:const Text('बिक्री सेव करें')))
 ]))));
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
 void restock(Item item)=>form('स्टॉक जोड़ें','प्रोडक्ट का नाम','जोड़ने की मात्रा',(n,a){setState((){final q=a.round();item.qty+=q;stockAdjustments.insert(0,Record(item.name,'मैनुअल स्टॉक वृद्धि • $q यूनिट',q.toDouble(),Icons.add_box_outlined));});_persist();msg('स्टॉक अपडेट हुआ');});

 Future<void> purchase()async{
 if(products.isEmpty){msg('खरीद दर्ज करने से पहले स्टॉक में प्रोडक्ट जोड़ें');return;}
 final supplier=TextEditingController(),quantity=TextEditingController(text:'1'),cost=TextEditingController(text:products.first.price.toStringAsFixed(2));
 Item selected=products.first;String paymentMode='नकद';
 await showModalBottomSheet<void>(context:context,isScrollControlled:true,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),builder:(sheetContext)=>StatefulBuilder(builder:(context,refresh)=>Padding(padding:EdgeInsets.fromLTRB(20,22,20,20+MediaQuery.of(context).viewInsets.bottom),child:Column(mainAxisSize:MainAxisSize.min,children:[
 const Text('नई खरीद / स्टॉक प्राप्ति',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:15),
 TextField(controller:supplier,decoration:const InputDecoration(labelText:'सप्लायर / विक्रेता का नाम')),
 const SizedBox(height:10),DropdownButtonFormField<Item>(initialValue:selected,decoration:const InputDecoration(labelText:'प्रोडक्ट'),items:products.map((p)=>DropdownMenuItem<Item>(value:p,child:Text(p.name))).toList(),onChanged:(p){if(p!=null)refresh(()=>selected=p);}),
 const SizedBox(height:10),TextField(controller:quantity,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'प्राप्त मात्रा (यूनिट)')),
 const SizedBox(height:10),TextField(controller:cost,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'प्रति यूनिट खरीद लागत (₹)')),
 const SizedBox(height:10),DropdownButtonFormField<String>(initialValue:paymentMode,decoration:const InputDecoration(labelText:'भुगतान प्रकार'),items:const[DropdownMenuItem(value:'नकद',child:Text('भुगतान कर दिया')),DropdownMenuItem(value:'उधार',child:Text('सप्लायर से उधार'))],onChanged:(v){if(v!=null)refresh(()=>paymentMode=v);}),
 const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton(onPressed:(){final q=int.tryParse(quantity.text);final unitCost=double.tryParse(cost.text);if(supplier.text.trim().isEmpty||q==null||q<1||unitCost==null||unitCost<=0){msg('सप्लायर, मात्रा और सही खरीद लागत भरें');return;}final total=q*unitCost;setState((){selected.qty+=q;purchases.insert(0,Record(supplier.text.trim(),'${selected.name} × $q • खरीद लागत ₹${money(unitCost)} प्रति यूनिट • $paymentMode',total,Icons.shopping_cart_outlined));if(paymentMode=='नकद'){cash-=total;}else{supplierLedger.insert(0,Record(supplier.text.trim(),'खरीद बकाया',total,Icons.storefront));}});_persist();Navigator.pop(sheetContext);msg('खरीद दर्ज हुई और स्टॉक बढ़ गया');},child:const Text('खरीद सेव करें')))
 ]))));
}
 Future<void> salesReturn()async{
 if(products.isEmpty||sales.isEmpty){msg('बिक्री वापसी के लिए पहले बिक्री रिकॉर्ड होना चाहिए');return;}
 final customer=TextEditingController();final quantity=TextEditingController(text:'1');Item selected=products.first;String refundMode='नकद वापसी';
 await showModalBottomSheet<void>(context:context,isScrollControlled:true,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),builder:(c)=>StatefulBuilder(builder:(context,refresh)=>Padding(padding:EdgeInsets.fromLTRB(20,22,20,20+MediaQuery.of(context).viewInsets.bottom),child:Column(mainAxisSize:MainAxisSize.min,children:[
 const Text('बिक्री वापसी / रिफंड',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:14),
 TextField(controller:customer,decoration:const InputDecoration(labelText:'ग्राहक का नाम')),
 const SizedBox(height:10),DropdownButtonFormField<Item>(initialValue:selected,decoration:const InputDecoration(labelText:'वापस आया प्रोडक्ट'),items:products.map((p)=>DropdownMenuItem<Item>(value:p,child:Text(p.name))).toList(),onChanged:(v){if(v!=null)refresh(()=>selected=v);}),
 const SizedBox(height:10),TextField(controller:quantity,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'वापसी मात्रा')),
 const SizedBox(height:10),DropdownButtonFormField<String>(initialValue:refundMode,decoration:const InputDecoration(labelText:'रिफंड का तरीका'),items:const[DropdownMenuItem(value:'नकद वापसी',child:Text('नकद / बैंक रिफंड')),DropdownMenuItem(value:'उधार समायोजन',child:Text('ग्राहक बकाया में समायोजन'))],onChanged:(v){if(v!=null)refresh(()=>refundMode=v);}),
 const SizedBox(height:15),SizedBox(width:double.infinity,child:FilledButton(onPressed:(){
 final q=int.tryParse(quantity.text);final client=customer.text.trim();if(client.isEmpty||q==null||q<1){msg('ग्राहक और सही मात्रा भरें');return;}
 final matching=sales.where((e)=>e.name.toLowerCase()==client.toLowerCase()&&e.detail.startsWith('${selected.name} × ')).toList();int soldQty=0;double soldValue=0;
 for(final e in matching){final match=RegExp(r'×\s*(\d+)').firstMatch(e.detail);if(match!=null){soldQty+=int.parse(match.group(1)!);soldValue+=e.amount;}}
 int returnedQty=0;for(final e in salesReturns.where((e)=>e.name.toLowerCase()==client.toLowerCase()&&e.detail.startsWith('${selected.name} × '))){final match=RegExp(r'×\s*(\d+)').firstMatch(e.detail);if(match!=null)returnedQty+=int.parse(match.group(1)!);}
 if(soldQty==0||q>soldQty-returnedQty){msg('इस ग्राहक की उपलब्ध बिक्री मात्रा से अधिक वापसी दर्ज नहीं हो सकती');return;}
 final refund=(soldValue/soldQty)*q;
 if(refundMode=='उधार समायोजन'){final due=khata.where((e)=>e.name.toLowerCase()==client.toLowerCase()).fold<double>(0,(sum,e)=>sum+e.amount);if(due<refund){msg('ग्राहक का बकाया रिफंड समायोजन के लिए पर्याप्त नहीं है');return;}}
 setState((){selected.qty+=q;salesReturns.insert(0,Record(client,'${selected.name} × $q • $refundMode',refund,Icons.assignment_return));if(refundMode=='नकद वापसी'){cash-=refund;}else{khata.insert(0,Record(client,'बिक्री वापसी समायोजन',-refund,Icons.assignment_return));}});
 _persist();Navigator.pop(c);msg('बिक्री वापसी दर्ज हुई और स्टॉक वापस जुड़ गया');
 },child:const Text('वापसी सेव करें')))
 ]))));
 }
 Future<void> supplierPayment()async{
 final name=TextEditingController(),amount=TextEditingController();
 await showModalBottomSheet<void>(context:context,isScrollControlled:true,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),builder:(c)=>Padding(padding:EdgeInsets.fromLTRB(20,22,20,20+MediaQuery.of(c).viewInsets.bottom),child:Column(mainAxisSize:MainAxisSize.min,children:[
 const Text('सप्लायर भुगतान',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:14),
 TextField(controller:name,decoration:const InputDecoration(labelText:'सप्लायर का नाम')),
 const SizedBox(height:10),TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'भुगतान राशि (₹)')),
 const SizedBox(height:15),SizedBox(width:double.infinity,child:FilledButton(onPressed:(){final a=double.tryParse(amount.text);final due=supplierLedger.where((e)=>e.name.toLowerCase()==name.text.trim().toLowerCase()).fold<double>(0,(sum,e)=>sum+e.amount);if(name.text.trim().isEmpty||a==null||a<=0||a>due){msg(due<=0?'इस सप्लायर का बकाया नहीं मिला':'भुगतान बकाया से अधिक नहीं हो सकता');return;}setState((){supplierLedger.insert(0,Record(name.text.trim(),'सप्लायर भुगतान',-a,Icons.payments_outlined));cash-=a;});_persist();Navigator.pop(c);msg('सप्लायर भुगतान दर्ज हुआ');},child:const Text('भुगतान सेव करें')))
 ])));
 }
 Future<void> product()async{
 final name=TextEditingController(),stock=TextEditingController(text:'0'),price=TextEditingController();
 await showModalBottomSheet<void>(context:context,isScrollControlled:true,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),builder:(sheetContext)=>Padding(padding:EdgeInsets.fromLTRB(20,22,20,20+MediaQuery.of(sheetContext).viewInsets.bottom),child:Column(mainAxisSize:MainAxisSize.min,children:[
 const Text('नया प्रोडक्ट',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:15),
 TextField(controller:name,decoration:const InputDecoration(labelText:'प्रोडक्ट का नाम')),
 const SizedBox(height:10),TextField(controller:stock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'शुरुआती स्टॉक (यूनिट)')),
 const SizedBox(height:10),TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'बिक्री मूल्य (₹)')),
 const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton(onPressed:(){final q=int.tryParse(stock.text);final p=double.tryParse(price.text);if(name.text.trim().isEmpty||q==null||q<0||p==null||p<=0){msg('नाम, सही स्टॉक और बिक्री मूल्य भरें');return;}setState(()=>products.add(Item(name.text.trim(),'प्रोडक्ट',q,p)));_persist();Navigator.pop(sheetContext);msg('प्रोडक्ट सेव हुआ');},child:const Text('प्रोडक्ट सेव करें')))
 ])));
}
 @override Widget build(BuildContext context){
 final pages=<Widget>[
  Dashboard(english:english,shopDue:khata.fold<double>(0,(s,e)=>s+e.amount),personalDue:personalKhata.fold<double>(0,(s,e)=>s+e.amount),monthExpense:expensesList.where((e)=>e.createdAt!=null&&e.createdAt!.year==DateTime.now().year&&e.createdAt!.month==DateTime.now().month).fold<double>(0,(s,e)=>s+e.amount),onKhata:()=>setState(()=>tab=1),onExpense:()=>setState(()=>tab=2),onRecharge:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ServiceCategoryPage(kind:'recharge',english:english))),onBills:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ServiceCategoryPage(kind:'bills',english:english))),onChallan:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ServiceCategoryPage(kind:'challan',english:english)))),
  KhataHubPage(shop:khata,personal:personalKhata,onShop:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LocalLedgerPage(title:'दुकानदार का खाता',items:khata,onCredit:()=>entry(),onPayment:()=>entry(true)))),onPersonal:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LocalLedgerPage(title:'पर्सनल उधार',items:personalKhata,onCredit:()=>personalLoanEntry(),onPayment:()=>personalLoanEntry(true)))),onLinked:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LinkedKhataPage(supabaseAvailable:widget.supabaseAvailable)))),
  ExpenseOnlyPage(items:expensesList,onAdd:expense),
  ProfilePage(supabaseAvailable:widget.supabaseAvailable,onRestore:_restore,english:english,onLanguage:(v){setState(()=>english=v);_persist();},sales:sales,expensesList:expensesList,khata:khata,personalTransactions:personalTransactions,products:products,purchases:purchases,supplierLedger:supplierLedger,salesReturns:salesReturns,stockAdjustments:stockAdjustments)
 ];
 return Scaffold(appBar:AppBar(titleSpacing:17,title:Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.account_balance_wallet,color:gold)),const SizedBox(width:10),const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('भारत साथी',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text('सरल खाता और खर्च',style:TextStyle(fontSize:10,color:muted))])]),actions:[IconButton(onPressed:()=>setState(()=>tab=3),icon:const Icon(Icons.person_outline))]),body:SafeArea(child:loaded?IndexedStack(index:tab,children:pages):const Center(child:CircularProgressIndicator())),bottomNavigationBar:NavigationBar(height:68,selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:[NavigationDestination(icon:const Icon(Icons.home_outlined),label:english?'Home':'होम'),NavigationDestination(icon:const Icon(Icons.menu_book_outlined),label:english?'Khata':'खाता'),NavigationDestination(icon:const Icon(Icons.payments_outlined),label:english?'Expenses':'खर्च'),NavigationDestination(icon:const Icon(Icons.person_outline),label:english?'Profile':'प्रोफाइल')]));
 }
 Widget fab(String s,VoidCallback f)=>FloatingActionButton.extended(onPressed:f,backgroundColor:navy,foregroundColor:Colors.white,icon:const Icon(Icons.add),label:Text(s));
}

class Dashboard extends StatelessWidget{
 final bool english;final double shopDue,personalDue,monthExpense;final VoidCallback onKhata,onExpense,onRecharge,onBills,onChallan;
 const Dashboard({super.key,required this.english,required this.shopDue,required this.personalDue,required this.monthExpense,required this.onKhata,required this.onExpense,required this.onRecharge,required this.onBills,required this.onChallan});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(17),children:[
 Text(english?'Your accounts, in one place':'आपका हिसाब, एक ही जगह',style:const TextStyle(color:navy,fontSize:21,fontWeight:FontWeight.w900)),
 Container(margin:const EdgeInsets.only(top:12,bottom:14),padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(english?'This month’s expenses':'इस महीने का खर्च',style:const TextStyle(color:Colors.white70)),Text('₹'+money(monthExpense),style:const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900)),Text('दुकान लेना: ₹'+money(shopDue)+'  •  पर्सनल लेना: ₹'+money(personalDue),style:const TextStyle(color:Colors.white70,fontSize:11))])),
 Text(english?'Main services':'मुख्य सुविधाएँ',style:const TextStyle(color:navy,fontSize:17,fontWeight:FontWeight.w900)),
 GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:3.0,children:[
 _tile(english?'Khata Book':'खाता बुक',Icons.menu_book,onKhata),_tile(english?'Mobile Recharge':'मोबाइल रिचार्ज',Icons.phone_android,onRecharge),_tile(english?'Bill Payment':'बिल पेमेंट',Icons.receipt_long,onBills),_tile(english?'Challan Payment':'चालान पेमेंट',Icons.local_police,onChallan)]),
 ListTile(tileColor:Colors.white,leading:const Icon(Icons.payments,color:red),title:Text(english?'Monthly expenses':'महीने का खर्च'),trailing:Text('₹'+money(monthExpense)),onTap:onExpense),
 Text(english?'Recharge, bill and challan services are Coming Soon.':'रिचार्ज, बिल और चालान के विकल्प Coming Soon हैं।',style:TextStyle(color:muted,fontSize:11))
 ]);
 Widget _tile(String title,IconData icon,VoidCallback tap)=>InkWell(onTap:tap,borderRadius:BorderRadius.circular(14),child:Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:blue,size:30),const SizedBox(height:8),Text(title,style:const TextStyle(color:navy,fontWeight:FontWeight.w900))])));
}
class KhataHubPage extends StatelessWidget{
 final List<Record> shop,personal;final VoidCallback onShop,onPersonal,onLinked;
 const KhataHubPage({super.key,required this.shop,required this.personal,required this.onShop,required this.onPersonal,required this.onLinked});
 double _sum(List<Record> a)=>a.fold<double>(0,(s,e)=>s+e.amount);
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(17),children:[heading('खाता बुक','दुकान और पर्सनल उधार'),_card('दुकानदार का खाता','ग्राहक को कितना उधार दिया और कितना वापस मिला','₹'+money(_sum(shop)),onShop),_card('पर्सनल उधार','दोस्तों और रिश्तेदारों का हिसाब','₹'+money(_sum(personal)),onPersonal),_card('ऐप वाले ग्राहक से जोड़ें','मोबाइल नंबर से साझा खाता लिंक करें','',onLinked),const Text('यह डिजिटल खाता है; बैंक या UPI से अपने-आप पैसे नहीं कटते।',style:TextStyle(color:muted,fontSize:11))]);
 Widget _card(String a,String b,String c,VoidCallback f)=>Card(color:Colors.white,child:ListTile(title:Text(a,style:const TextStyle(color:navy,fontWeight:FontWeight.w900)),subtitle:Text(b),trailing:c.isEmpty?const Icon(Icons.chevron_right):Text(c),onTap:f));
}
class LocalLedgerPage extends StatefulWidget{
 final String title;final List<Record> items;final Future<void> Function() onCredit,onPayment;
 const LocalLedgerPage({super.key,required this.title,required this.items,required this.onCredit,required this.onPayment});
 @override State<LocalLedgerPage> createState()=>_LocalLedgerPageState();
}
class _LocalLedgerPageState extends State<LocalLedgerPage>{
 @override Widget build(BuildContext context){final people=<String,double>{};for(final e in widget.items){people[e.name]=(people[e.name]??0)+e.amount;}return Scaffold(appBar:AppBar(title:Text(widget.title)),body:ListView(padding:const EdgeInsets.all(16),children:[Text('कुल बकाया: ₹'+money(widget.items.fold<double>(0,(s,e)=>s+e.amount)),style:const TextStyle(color:navy,fontWeight:FontWeight.w900,fontSize:21)),Row(children:[Expanded(child:FilledButton(onPressed:()async{await widget.onCredit();if(mounted)setState((){});},child:const Text('उधार दें'))),const SizedBox(width:8),Expanded(child:OutlinedButton(onPressed:()async{await widget.onPayment();if(mounted)setState((){});},child:const Text('वापसी दर्ज करें')))]),...people.entries.map((e)=>ListTile(title:Text(e.key),trailing:Text('₹'+money(e.value),style:const TextStyle(color:navy,fontWeight:FontWeight.w900))))]));}
}
class ExpenseOnlyPage extends StatefulWidget{
 final List<Record> items;final Future<void> Function() onAdd;
 const ExpenseOnlyPage({super.key,required this.items,required this.onAdd});
 @override State<ExpenseOnlyPage> createState()=>_ExpenseOnlyPageState();
}
class _ExpenseOnlyPageState extends State<ExpenseOnlyPage>{
 @override Widget build(BuildContext context){final now=DateTime.now();final rows=widget.items.where((e)=>e.createdAt!=null&&e.createdAt!.year==now.year&&e.createdAt!.month==now.month).toList();final total=rows.fold<double>(0,(s,e)=>s+e.amount);return Scaffold(appBar:AppBar(title:const Text('महीने का खर्च')),body:ListView(padding:const EdgeInsets.all(16),children:[Text('इस महीने का खर्च: ₹'+money(total),style:const TextStyle(color:navy,fontSize:22,fontWeight:FontWeight.w900)),FilledButton.icon(onPressed:()async{await widget.onAdd();if(mounted)setState((){});},icon:const Icon(Icons.add),label:const Text('खर्च जोड़ें')),...rows.map((e)=>ListTile(title:Text(e.name),subtitle:Text(e.detail),trailing:Text('₹'+money(e.amount))))]));}
}
class ServiceCategoryPage extends StatelessWidget{final String kind;final bool english;const ServiceCategoryPage({super.key,required this.kind,required this.english});@override Widget build(BuildContext context){final opts=kind=='recharge'?(english?['Prepaid mobile recharge','Postpaid mobile bill']:['प्रीपेड मोबाइल रिचार्ज','पोस्टपेड मोबाइल बिल']):kind=='bills'?(english?['Electricity bill','Water bill','Gas bill','DTH recharge','Broadband / internet bill','Landline bill']:['बिजली बिल','पानी बिल','गैस बिल','DTH रिचार्ज','ब्रॉडबैंड / इंटरनेट बिल','लैंडलाइन बिल']):(english?['Traffic challan','Vehicle challan status']:['ट्रैफिक चालान','वाहन चालान की स्थिति']);return Scaffold(appBar:AppBar(title:Text(kind=='recharge'?(english?'Mobile Recharge':'मोबाइल रिचार्ज'):kind=='bills'?(english?'Bill Payment':'बिल पेमेंट'):(english?'Challan Payment':'चालान पेमेंट'))),body:ListView(padding:const EdgeInsets.all(16),children:opts.map((x)=>Card(color:Colors.white,child:ListTile(title:Text(x),trailing:const Chip(label:Text('COMING SOON')),onTap:()=>openComingSoon(context,x)))).toList()));}
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
 @override Widget build(BuildContext context){final u=c.auth.currentUser;if(!widget.supabaseAvailable||u==null)return Scaffold(appBar:AppBar(title:const Text('लिंक किया हुआ खाता')),body:const Center(child:Text('पहले ईमेल और पासवर्ड से लॉगिन करें।')));return Scaffold(appBar:AppBar(title:const Text('लिंक किया हुआ खाता'),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),body:ListView(padding:const EdgeInsets.all(16),children:[const Text('ग्राहक का रजिस्टर्ड मोबाइल नंबर डालें। ग्राहक की स्वीकृति के बाद दोनों तरफ एक ही खाता दिखेगा।'),FilledButton(onPressed:request,child:const Text('ग्राहक को जोड़ें')),if(busy)const LinearProgressIndicator(),...rows.map((r){final retailer=r['retailer_id']==u.id;final pending=r['status']=='pending';final name=retailer?(r['customer_name']??'ग्राहक'):(r['retailer_name']??'दुकानदार');return Card(color:Colors.white,child:ListTile(title:Text(name.toString()),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r['status'].toString()),if(r['status']=='accepted')_LinkedDetails(link:r,retailer:retailer,onCredit:()=>addEntry(r,'credit'),onPayment:()=>addEntry(r,'payment'))]),trailing:pending&&!retailer?TextButton(onPressed:()=>respond(r['id'],true),child:const Text('स्वीकार करें')):null));})]));}
}
class Chart extends StatelessWidget {
  const Chart({super.key});

  @override
  Widget build(BuildContext context) {
    const values = [0.42, 0.68, 0.50, 0.88, 0.62, 1.0, 0.76];
    const days = ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('₹24,860', style: TextStyle(color: navy, fontSize: 20, fontWeight: FontWeight.w900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFE8F5EE), borderRadius: BorderRadius.circular(20)),
                child: const Text('+12.8%', style: TextStyle(color: green, fontSize: 10, fontWeight: FontWeight.w800)),
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
                                color: i == 5 ? gold : const Color(0xFFDCE5EF),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(days[i], style: const TextStyle(fontSize: 9, color: muted)),
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
Widget mini(String a,String b,IconData i)=>Row(children:[Icon(i,color:gold,size:14),const SizedBox(width:4),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(color:Colors.white60,fontSize:9)),Text(b,style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w800))])]);
Widget metric(String a,String b,IconData i,Color c)=>Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Expanded(child:Text(a,style:const TextStyle(color:muted,fontSize:10))),Icon(i,color:c,size:18)]),const SizedBox(height:7),FittedBox(alignment:Alignment.centerLeft,child:Text(b,style:const TextStyle(color:navy,fontSize:18,fontWeight:FontWeight.w900)))]));
Widget section(String a,String b)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(color:navy,fontSize:16,fontWeight:FontWeight.w900)),Text(b,style:const TextStyle(color:muted,fontSize:10))]);
Widget quick(String a,IconData i,Color bgc,Color fg,VoidCallback f)=>InkWell(onTap:f,borderRadius:BorderRadius.circular(16),child:Container(padding:const EdgeInsets.symmetric(vertical:14,horizontal:3),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),child:Column(children:[Container(width:42,height:42,decoration:BoxDecoration(color:bgc,borderRadius:BorderRadius.circular(13)),child:Icon(i,color:fg)),const SizedBox(height:8),Text(a,style:const TextStyle(color:navy,fontSize:10,fontWeight:FontWeight.w800))])));
Widget activity(Record r)=>Container(margin:const EdgeInsets.only(top:7),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:Row(children:[CircleAvatar(backgroundColor:const Color(0xFFEAF0F6),child:Icon(r.icon,color:blue,size:18)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r.name,style:const TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:12)),Text(r.detail,style:const TextStyle(color:muted,fontSize:10))])),Text('₹${money(r.amount)}',style:const TextStyle(color:green,fontWeight:FontWeight.w900,fontSize:12))]));
class PersonalFinancePage extends StatelessWidget{
 final List<Record> items;final double budget;final String budgetName;final VoidCallback onSetBudget,onIncome,onExpense;
 const PersonalFinancePage({super.key,required this.items,required this.budget,required this.budgetName,required this.onSetBudget,required this.onIncome,required this.onExpense});
 @override Widget build(BuildContext context){
 final income=items.where((e)=>e.amount>0).fold<double>(0,(s,e)=>s+e.amount);
 final now=DateTime.now();final spent=items.where((e){final d=e.createdAt;return e.amount<0&&d!=null&&d.year==now.year&&d.month==now.month;}).fold<double>(0,(s,e)=>s+e.amount.abs());
 return ListView(padding:const EdgeInsets.all(17),children:[
 heading('पर्सनल फाइनेंस','अपनी आय और मासिक खर्च का हिसाब रखें'),const SizedBox(height:14),
 Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 const Text('कुल बचत / शेष',style:TextStyle(color:Colors.white70,fontSize:11)),
 Text('₹${money(income-spent)}',style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.w900)),
 const SizedBox(height:12),Row(children:[Expanded(child:mini('कुल आय','₹${money(income)}',Icons.trending_up)),Expanded(child:mini('कुल खर्च','₹${money(spent)}',Icons.payments_outlined))])
 ])),const SizedBox(height:14),
 Row(children:[Expanded(child:FilledButton.icon(onPressed:onIncome,icon:const Icon(Icons.add),label:const Text('आय जोड़ें'),style:FilledButton.styleFrom(backgroundColor:green))),const SizedBox(width:9),Expanded(child:FilledButton.icon(onPressed:onExpense,icon:const Icon(Icons.remove),label:const Text('खर्च जोड़ें'),style:FilledButton.styleFrom(backgroundColor:red)))]),
 const SizedBox(height:20),section('मासिक खर्च सीमा',budgetName),const SizedBox(height:8),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(budget>0?'₹${money(spent)} / ₹${money(budget)}':'सीमा तय नहीं है',style:const TextStyle(color:navy,fontWeight:FontWeight.w800)),TextButton(onPressed:onSetBudget,child:Text(budget>0?'बदलें':'सेट करें'))]),if(budget>0)LinearProgressIndicator(value:(spent/budget).clamp(0.0,1.0).toDouble(),backgroundColor:bg,color:spent>budget?red:green),if(budget>0)Padding(padding:const EdgeInsets.only(top:7),child:Text(spent>budget?'खर्च तय सीमा से अधिक है।':'सीमा में शेष ₹${money((budget-spent).clamp(0.0,double.infinity))}',style:TextStyle(color:spent>budget?red:muted,fontSize:11)))])),const SizedBox(height:20),section('लेन-देन','इस डिवाइस पर सेव रिकॉर्ड'),
 if(items.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Center(child:Text('अभी कोई व्यक्तिगत लेन-देन नहीं है।',style:TextStyle(color:muted))))
 else ...items.map((e)=>Container(margin:const EdgeInsets.only(top:8),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:Row(children:[CircleAvatar(backgroundColor:e.amount>=0?const Color(0xFFE3F4EC):const Color(0xFFFFE8E8),child:Icon(e.icon,color:e.amount>=0?green:red)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e.name,style:const TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:12)),Text(e.detail,style:const TextStyle(color:muted,fontSize:10))])),Text('${e.amount>=0?'+':'−'} ₹${money(e.amount.abs())}',style:TextStyle(color:e.amount>=0?green:red,fontWeight:FontWeight.w900))])))
 ]);
 }
}
class ProductPage extends StatelessWidget{final List<Item> items;final List<Record> purchases,supplierLedger,stockAdjustments;final void Function(Item) onRestock;final VoidCallback onPurchase,onSupplierPayment;const ProductPage({super.key,required this.items,required this.purchases,required this.supplierLedger,required this.stockAdjustments,required this.onRestock,required this.onPurchase,required this.onSupplierPayment});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(17),children:[heading('प्रोडक्ट और स्टॉक','इन्वेंट्री और खरीद प्रबंधन'),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:onPurchase,icon:const Icon(Icons.add_shopping_cart),label:const Text('खरीद दर्ज करें'))),const SizedBox(height:8),OutlinedButton.icon(onPressed:onSupplierPayment,icon:const Icon(Icons.payments_outlined),label:const Text('सप्लायर भुगतान दर्ज करें')),const SizedBox(height:12),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Text('कुल प्रोडक्ट: ${items.length}     •     कम स्टॉक: ${items.where((e)=>e.qty<15).length}',style:const TextStyle(color:navy,fontWeight:FontWeight.w800))),...items.map((p)=>Container(margin:const EdgeInsets.only(top:9),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Row(children:[const Icon(Icons.inventory_2_outlined,color:blue,size:25),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.name,style:const TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:12)),Text(p.detail,style:const TextStyle(color:muted,fontSize:10)),Text('₹${money(p.price)} बिक्री मूल्य',style:const TextStyle(color:muted,fontSize:10))])),Column(children:[Text('${p.qty}',style:TextStyle(color:p.qty<15?red:green,fontWeight:FontWeight.w900,fontSize:17)),const Text('यूनिट',style:TextStyle(color:muted,fontSize:9)),IconButton(tooltip:'स्टॉक जोड़ें',onPressed:()=>onRestock(p),icon:const Icon(Icons.add_circle_outline,color:blue,size:20))])]))),if(purchases.isNotEmpty) ...[const SizedBox(height:20),section('सप्लायर हिस्ट्री','सप्लायर के नाम और हाल की खरीद'),...purchases.take(10).map(activity)],if(supplierLedger.isNotEmpty) ...[const SizedBox(height:14),section('सप्लायर बकाया हिस्ट्री','खरीद उधार और किए गए भुगतान'),...supplierLedger.take(20).map(activity)],if(stockAdjustments.isNotEmpty) ...[const SizedBox(height:14),section('स्टॉक बदलाव हिस्ट्री','मैनुअल स्टॉक वृद्धि'),...stockAdjustments.take(20).map(activity)]]);}
class SalesPage extends StatelessWidget{final List<Record> items,expenses,returns;final VoidCallback onReturn;const SalesPage({super.key,required this.items,required this.expenses,required this.returns,required this.onReturn});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(17),children:[heading('बिक्री और खर्च','कारोबार के सभी रिकॉर्ड'),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:onReturn,icon:const Icon(Icons.assignment_return),label:const Text('बिक्री वापसी दर्ज करें'))),const SizedBox(height:12),section('बिक्री','दर्ज की गई बिक्री'),if(items.isEmpty)const Text('अभी कोई बिक्री नहीं।',style:TextStyle(color:muted)) else ...items.map(activity),const SizedBox(height:20),section('खर्च','दर्ज किए गए खर्च'),if(expenses.isEmpty)const Text('अभी कोई खर्च नहीं।',style:TextStyle(color:muted)) else ...expenses.map(activity),const SizedBox(height:20),section('बिक्री वापसी','दर्ज किए गए रिफंड और स्टॉक वापसी'),if(returns.isEmpty)const Text('अभी कोई बिक्री वापसी नहीं।',style:TextStyle(color:muted)) else ...returns.map(activity)]); }
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
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:onPayment,icon:const Icon(Icons.payments_outlined),label:const Text('ग्राहक से भुगतान दर्ज करें'),style:FilledButton.styleFrom(backgroundColor:green))),
        const SizedBox(height:8),
        ...items.map((entry) {
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFEAF0F6),
                  child: Text(entry.name[0], style: const TextStyle(color: navy, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name, style: const TextStyle(color: navy, fontWeight: FontWeight.w800, fontSize: 12)),
                      Text(entry.detail, style: const TextStyle(color: muted, fontSize: 10)),
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
String _uuidV4(){final random=Random.secure();final bytes=List<int>.generate(16,(_)=>random.nextInt(256));bytes[6]=(bytes[6]&0x0f)|0x40;bytes[8]=(bytes[8]&0x3f)|0x80;final h=bytes.map((b)=>b.toRadixString(16).padLeft(2,'0')).join();return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';}
class AuthPage extends StatefulWidget{final bool supabaseAvailable;const AuthPage({super.key,required this.supabaseAvailable});@override State<AuthPage> createState()=>_AuthPageState();}
class _AuthPageState extends State<AuthPage>{
 final email=TextEditingController(),password=TextEditingController(),fullName=TextEditingController(),phone=TextEditingController();bool signUp=false,busy=false,showPassword=false;String? notice;bool errorNotice=false;
 SupabaseClient get client=>Supabase.instance.client;
 void message(String text,{bool error=false}){if(!mounted)return;setState((){notice=text;errorNotice=error;});}
 Future<void> _ensureProfileAndAccounts()async{
 final user=client.auth.currentUser;if(user==null)throw const AuthException('लॉगिन सत्र उपलब्ध नहीं है');
 final name=fullName.text.trim().isNotEmpty?fullName.text.trim():(user.email??'Bharat Saathi').split('@').first;
 await client.from('profiles').upsert({'id':user.id,'full_name':name,'phone':phone.text.trim().isNotEmpty?phone.text.trim():(user.userMetadata?['phone'] as String? ?? ''),'preferred_language':'hi'});
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
 if(!widget.supabaseAvailable){message('Supabase अभी उपलब्ध नहीं है।',error:true);return;}
 final mail=email.text.trim();
 if(!mail.contains('@')||password.text.length<8||(signUp&&(fullName.text.trim().isEmpty||phone.text.replaceAll(RegExp(r'[^0-9]'),'').length!=10))){message('नाम, सही ईमेल, 10 अंकों का मोबाइल और कम-से-कम 8 अक्षर का पासवर्ड भरें।',error:true);return;}
 setState(()=>busy=true);
 try{
 if(signUp){
 final response=await client.auth.signUp(email:mail,password:password.text,data:{'full_name':fullName.text.trim(),'phone':phone.text.trim()});
 if(response.session==null){message('रजिस्ट्रेशन अनुरोध स्वीकार हुआ। ईमेल सत्यापन पूरा करके फिर लॉगिन करें।');}
 else{await _ensureProfileAndAccounts();message('अकाउंट बन गया। व्यक्तिगत और रिटेलर खाते तैयार हैं।');}
 }else{
 await client.auth.signInWithPassword(email:mail,password:password.text);
 await _ensureProfileAndAccounts();
 message('लॉगिन सफल। व्यक्तिगत और रिटेलर खाते तैयार हैं।');
 }
 }on AuthException catch(e){message(e.message,error:true);}on PostgrestException catch(e){message('डेटाबेस सेटअप त्रुटि: ${e.message}',error:true);}catch(e){message('कनेक्शन या अकाउंट सेटअप पूरा नहीं हुआ। दोबारा प्रयास करें।',error:true);}
 if(mounted)setState(()=>busy=false);
 }
 Future<void> resetPassword()async{
 if(!widget.supabaseAvailable){message('Supabase कनेक्शन उपलब्ध नहीं है।',error:true);return;}
 final mail=email.text.trim();if(!mail.contains('@')){message('पहले सही ईमेल पता भरें।',error:true);return;}
 setState(()=>busy=true);
 try{await client.auth.resetPasswordForEmail(mail);message('पासवर्ड रीसेट ईमेल भेजने का अनुरोध सफल हुआ। ईमेल में दिए लिंक का उपयोग करें।');}
 on AuthException catch(e){message(e.message,error:true);}catch(_){message('रीसेट ईमेल नहीं भेजा जा सका। ईमेल और Supabase SMTP सेटिंग जाँचें।',error:true);}
 if(mounted)setState(()=>busy=false);
 }
 Future<void> signOut()async{setState(()=>busy=true);try{await client.auth.signOut();message('लॉगआउट हो गया।');}catch(_){message('लॉगआउट पूरा नहीं हुआ।',error:true);}if(mounted)setState(()=>busy=false);}
 @override void dispose(){email.dispose();password.dispose();fullName.dispose();phone.dispose();super.dispose();}
 @override Widget build(BuildContext context){
 final user=widget.supabaseAvailable?client.auth.currentUser:null;
 return Scaffold(appBar:AppBar(title:const Text('अकाउंट और सुरक्षा')),body:ListView(padding:const EdgeInsets.all(20),children:[
 Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(18)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Bharat Saathi अकाउंट',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),SizedBox(height:6),Text('ईमेल से सुरक्षित लॉगिन। SMS OTP अभी Coming Soon है।',style:TextStyle(color:Colors.white70,fontSize:12))])),
 const SizedBox(height:18),
 if(!widget.supabaseAvailable)const Text('Supabase कनेक्शन शुरू नहीं हो पाया। अभी स्थानीय ऑफलाइन सुविधाएँ उपयोग करें।',style:TextStyle(color:red))
 else if(user!=null)...[
 const Text('लॉगिन सक्रिय',style:TextStyle(color:green,fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:6),Text(user.email??'',style:const TextStyle(color:navy)),const SizedBox(height:12),const Text('आपके लिए व्यक्तिगत और रिटेलर खाते डेटाबेस में तैयार किए जाते हैं। मौजूदा ऑफलाइन रिकॉर्ड अभी क्लाउड से सिंक नहीं होते।',style:TextStyle(color:muted,fontSize:12)),const SizedBox(height:18),FilledButton(onPressed:busy?null:signOut,child:Text(busy?'कृपया प्रतीक्षा करें':'लॉगआउट करें'))
 ]else...[
 if(signUp)TextField(controller:fullName,decoration:const InputDecoration(labelText:'पूरा नाम',prefixIcon:Icon(Icons.person_outline))),
 if(signUp)const SizedBox(height:10),
 if(signUp)TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'मोबाइल नंबर (10 अंक)',prefixIcon:Icon(Icons.phone_android))),
  if(signUp)const SizedBox(height:10),
  TextField(controller:email,keyboardType:TextInputType.emailAddress,autocorrect:false,decoration:const InputDecoration(labelText:'ईमेल',prefixIcon:Icon(Icons.email_outlined))),
 const SizedBox(height:10),TextField(controller:password,obscureText:!showPassword,decoration:InputDecoration(labelText:'पासवर्ड (कम-से-कम 8 अक्षर)',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(onPressed:()=>setState(()=>showPassword=!showPassword),icon:Icon(showPassword?Icons.visibility_off:Icons.visibility)))),
 const SizedBox(height:16),FilledButton(onPressed:busy?null:submit,style:FilledButton.styleFrom(backgroundColor:navy,padding:const EdgeInsets.all(15)),child:Text(busy?'कृपया प्रतीक्षा करें':signUp?'अकाउंट बनाएं':'लॉगिन करें')),
 if(!signUp)TextButton(onPressed:busy?null:resetPassword,child:const Text('पासवर्ड भूल गए? रीसेट ईमेल भेजें')),
 TextButton(onPressed:busy?null:()=>setState(()=>signUp=!signUp),child:Text(signUp?'पहले से अकाउंट है? लॉगिन करें':'नया अकाउंट बनाना है? रजिस्टर करें'))
 ],
 if(notice!=null)Padding(padding:const EdgeInsets.only(top:14),child:Text(notice!,style:TextStyle(color:errorNotice?red:green,fontSize:12,fontWeight:FontWeight.w700)))
 ]));
 }
}
class CloudBackupPage extends StatefulWidget{final bool supabaseAvailable;final Future<void> Function() onRestore;const CloudBackupPage({super.key,required this.supabaseAvailable,required this.onRestore});@override State<CloudBackupPage> createState()=>_CloudBackupPageState();}
class _CloudBackupPageState extends State<CloudBackupPage>{
 bool busy=false;String? notice;bool noticeError=false;SupabaseClient get client=>Supabase.instance.client;
 void showMessage(String text,{bool error=false}){if(mounted)setState((){notice=text;noticeError=error;});}
 Future<void> _login()async{await Navigator.push<void>(context,MaterialPageRoute<void>(builder:(_)=>AuthPage(supabaseAvailable:widget.supabaseAvailable)));if(mounted)setState(()=>notice=null);}
 Future<void> backup()async{
 if(!widget.supabaseAvailable){showMessage('Supabase कनेक्शन उपलब्ध नहीं है।',error:true);return;}
 final user=client.auth.currentUser;if(user==null){showMessage('पहले लॉगिन करें।',error:true);return;}
 setState(()=>busy=true);
 try{final raw=await LocalStore.read();if(raw==null){showMessage('अभी इस डिवाइस पर बैकअप करने के लिए कोई रिकॉर्ड नहीं है।');}else{final payload=jsonDecode(raw);if(payload is! Map<String,dynamic>){showMessage('स्थानीय डेटा का प्रारूप सही नहीं है।',error:true);}else{await client.from('user_backups').upsert({'user_id':user.id,'payload':payload,'schema_version':1,'updated_at':DateTime.now().toUtc().toIso8601String()});showMessage('क्लाउड बैकअप सफलतापूर्वक सेव हुआ।');}}}
 on PostgrestException catch(e){showMessage('क्लाउड बैकअप त्रुटि: ${e.message}',error:true);}catch(_){showMessage('बैकअप पूरा नहीं हुआ। इंटरनेट और लॉगिन जाँचें।',error:true);}
 if(mounted)setState(()=>busy=false);
 }
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
 final confirmed=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('क्लाउड बैकअप रीस्टोर करें?'),content:const Text('यह इस फोन के मौजूदा स्थानीय रिकॉर्ड को क्लाउड बैकअप से बदल देगा। पहले स्थानीय बैकअप कर लें।'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('रद्द करें')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('रीस्टोर करें'))]));
 if(confirmed==true){await LocalStore.write(jsonEncode(row['payload']));await widget.onRestore();showMessage('क्लाउड बैकअप इस डिवाइस पर रीस्टोर हो गया।');}
 }
 }on PostgrestException catch(e){showMessage('रीस्टोर त्रुटि: ${e.message}',error:true);}catch(_){showMessage('रीस्टोर पूरा नहीं हुआ। इंटरनेट और लॉगिन जाँचें।',error:true);}
 if(mounted)setState(()=>busy=false);
 }
 @override Widget build(BuildContext context){
 final user=widget.supabaseAvailable?client.auth.currentUser:null;
 return Scaffold(appBar:AppBar(title:const Text('डेटा बैकअप')),body:ListView(padding:const EdgeInsets.all(20),children:[
 Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(18)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('आपके रिकॉर्ड का सुरक्षित बैकअप',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),SizedBox(height:7),Text('यह मैनुअल स्नैपशॉट है। अपने अकाउंट से किसी दूसरे डिवाइस पर रिकॉर्ड वापस ला सकते हैं। यह लाइव सिंक नहीं है।',style:TextStyle(color:Colors.white70,fontSize:12))])),
 const SizedBox(height:18),
 if(!widget.supabaseAvailable)const Text('Supabase कनेक्शन उपलब्ध नहीं है।',style:TextStyle(color:red))
 else if(user==null)...[const Text('क्लाउड बैकअप के लिए पहले लॉगिन करें।',style:TextStyle(color:navy,fontWeight:FontWeight.w700)),const SizedBox(height:10),FilledButton(onPressed:busy?null:_login,child:const Text('लॉगिन करें'))]
 else ...[Text('लॉगिन अकाउंट: ${user.email??'ईमेल उपलब्ध नहीं'}',style:const TextStyle(color:navy,fontWeight:FontWeight.w700)),const SizedBox(height:14),FilledButton.icon(onPressed:busy?null:backup,icon:const Icon(Icons.cloud_upload_outlined),label:const Text('अभी बैकअप सेव करें')),const SizedBox(height:10),OutlinedButton.icon(onPressed:busy?null:restore,icon:const Icon(Icons.cloud_download_outlined),label:const Text('क्लाउड बैकअप रीस्टोर करें'))],
 if(busy)const Padding(padding:EdgeInsets.all(18),child:Center(child:CircularProgressIndicator())),
 if(notice!=null)Padding(padding:const EdgeInsets.only(top:14),child:Text(notice!,style:TextStyle(color:noticeError?red:green,fontSize:12,fontWeight:FontWeight.w700)))
 ]));
 }
}
class ProfilePage extends StatelessWidget{
 final bool supabaseAvailable,english;final Future<void> Function() onRestore;final ValueChanged<bool> onLanguage;
 final List<Record> sales,expensesList,khata,personalTransactions;final List<Item> products;final List<Record> purchases,supplierLedger,salesReturns,stockAdjustments;
 const ProfilePage({super.key,required this.supabaseAvailable,required this.onRestore,required this.sales,required this.expensesList,required this.khata,required this.personalTransactions,required this.products,required this.purchases,required this.supplierLedger,required this.salesReturns,required this.stockAdjustments,required this.english,required this.onLanguage});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(17),children:[heading(english?'Profile & Settings':'प्रोफाइल और सेटिंग',english?'Manage your account':'अपने अकाउंट को मैनेज करें'),Card(color:Colors.white,child:ListTile(leading:const Icon(Icons.language),title:const Text('भाषा / Language'),trailing:DropdownButton<bool>(value:english,items:const[DropdownMenuItem(value:false,child:Text('हिंदी')),DropdownMenuItem(value:true,child:Text('English'))],onChanged:(v){if(v!=null)onLanguage(v);}))),setting(Icons.lock_outline,english?'Account & Security':'अकाउंट और सुरक्षा',english?'Email/password login; phone collected at registration':'ईमेल और पासवर्ड लॉगिन; रजिस्ट्रेशन में मोबाइल नंबर',()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>AuthPage(supabaseAvailable:supabaseAvailable)))),setting(Icons.sync,english?'Connected Khata':'लिंक किया हुआ खाता',english?'Shared shopkeeper and customer ledger':'दुकानदार और ग्राहक का साझा खाता',()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LinkedKhataPage(supabaseAvailable:supabaseAvailable)))),setting(Icons.help_outline,english?'Help Centre':'सहायता केंद्र','WhatsApp: 6283398317',()=>launchUrl(Uri.parse('https://wa.me/916283398317?text='+Uri.encodeComponent('नमस्ते Bharat Saathi सहायता केंद्र')),mode:LaunchMode.externalApplication)),setting(Icons.cloud_upload_outlined,english?'Data backup':'डेटा बैकअप',english?'Manual cloud backup':'मैनुअल क्लाउड बैकअप',()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CloudBackupPage(supabaseAvailable:supabaseAvailable,onRestore:onRestore)))),Text(english?'Your mobile number is saved at registration. Login uses email and password. OTP is not enabled. SMS and email alerts need provider setup.':'मोबाइल नंबर रजिस्ट्रेशन में सेव होगा। लॉगिन ईमेल और पासवर्ड से होगा। OTP अभी नहीं है। SMS और ईमेल अलर्ट के लिए सेवा सेटअप बाकी है.',style:TextStyle(color:muted,fontSize:11)),const Text('UPI ट्रांसफर, स्टॉक, खरीदारी और बिक्री के फंक्शन नहीं रखे गए हैं।',style:TextStyle(color:muted,fontSize:11))]);
}
class ReportsPage extends StatefulWidget{
 final List<Record> sales,expensesList,khata,personalTransactions;
 final List<Item> products;final List<Record> purchases,supplierLedger,salesReturns,stockAdjustments;
 const ReportsPage({super.key,required this.sales,required this.expensesList,required this.khata,required this.personalTransactions,required this.products,required this.purchases,required this.supplierLedger,required this.salesReturns,required this.stockAdjustments});
 @override State<ReportsPage> createState()=>_ReportsPageState();
}
class _ReportsPageState extends State<ReportsPage>{
 DateTimeRange? range;
 List<Record> _filter(List<Record> rows)=>range==null?rows:rows.where((e){final d=e.createdAt;if(d==null)return false;final day=DateTime(d.year,d.month,d.day);final from=DateTime(range!.start.year,range!.start.month,range!.start.day);final to=DateTime(range!.end.year,range!.end.month,range!.end.day);return !day.isBefore(from)&&!day.isAfter(to);}).toList();
 List<Record> get sales=>_filter(widget.sales);
 List<Record> get purchases=>_filter(widget.purchases);
 List<Record> get supplierLedger=>_filter(widget.supplierLedger);
 List<Record> get salesReturns=>_filter(widget.salesReturns);
 List<Record> get stockAdjustments=>_filter(widget.stockAdjustments);
 List<Record> get expensesList=>_filter(widget.expensesList);
 List<Record> get khata=>_filter(widget.khata);
 List<Record> get personalTransactions=>_filter(widget.personalTransactions);
 List<Item> get products=>widget.products;
 Future<void> _chooseRange()async{
  final now=DateTime.now();
  final selected=await showDateRangePicker(context:context,firstDate:DateTime(2000),lastDate:DateTime(now.year+2),initialDateRange:range??DateTimeRange(start:DateTime(now.year,now.month,1),end:now));
  if(selected!=null)setState(()=>range=selected);
 }
 double get salesTotal=>sales.fold<double>(0,(s,e)=>s+e.amount);
 double get purchaseTotal=>purchases.fold<double>(0,(s,e)=>s+e.amount);
 double get supplierDue=>supplierLedger.fold<double>(0,(s,e)=>s+e.amount);
 double get expenseTotal=>expensesList.fold<double>(0,(s,e)=>s+e.amount);
 double get dueTotal=>khata.fold<double>(0,(s,e)=>s+e.amount);
 double get personalIncome=>personalTransactions.where((e)=>e.amount>0).fold<double>(0,(s,e)=>s+e.amount);
 double get personalExpense=>-personalTransactions.where((e)=>e.amount<0).fold<double>(0,(s,e)=>s+e.amount);
 String _cell(String value)=>"\"${value.replaceAll('"','""')}\"";
 String _csv(){
 final rows=<List<String>>[['श्रेणी','नाम','विवरण','राशि (INR)','तारीख़ / समय','मात्रा','बिक्री मूल्य']];
 for(final e in sales){rows.add(['बिक्री',e.name,e.detail,e.amount.toStringAsFixed(2),e.createdAt?.toLocal().toIso8601String()??'','','']);}
 for(final e in purchases){rows.add(['खरीद',e.name,e.detail,e.amount.toStringAsFixed(2),e.createdAt?.toLocal().toIso8601String()??'','','']);}
 for(final e in supplierLedger){rows.add(['सप्लायर खाता',e.name,e.detail,e.amount.toStringAsFixed(2),e.createdAt?.toLocal().toIso8601String()??'','','']);}
 for(final e in salesReturns){rows.add(['बिक्री वापसी',e.name,e.detail,e.amount.toStringAsFixed(2),e.createdAt?.toLocal().toIso8601String()??'','','']);}
 for(final e in stockAdjustments){rows.add(['स्टॉक बदलाव',e.name,e.detail,e.amount.toStringAsFixed(2),e.createdAt?.toLocal().toIso8601String()??'','','']);}
 for(final e in expensesList){rows.add(['कारोबारी खर्च',e.name,e.detail,e.amount.toStringAsFixed(2),e.createdAt?.toLocal().toIso8601String()??'','','']);}
 for(final e in khata){rows.add(['ग्राहक खाता',e.name,e.detail,e.amount.toStringAsFixed(2),e.createdAt?.toLocal().toIso8601String()??'','','']);}
 for(final e in personalTransactions){rows.add(['व्यक्तिगत',e.name,e.detail,e.amount.toStringAsFixed(2),e.createdAt?.toLocal().toIso8601String()??'','','']);}
 for(final e in products){rows.add(['स्टॉक',e.name,e.detail,'','','${e.qty}',e.price.toStringAsFixed(2)]);}
 return rows.map((r)=>r.map(_cell).join(',')).join('\r\n');
 }
 Future<void> _export(BuildContext context)async{
 final bytes=Uint8List.fromList(utf8.encode(_csv()));
 try{
 await Share.shareXFiles([XFile.fromData(bytes,mimeType:'text/csv',name:'bharat-saathi-report.csv')],text:'भारत साथी रिपोर्ट');
 }catch(_){
 await Clipboard.setData(ClipboardData(text:_csv()));
 if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('शेयर विंडो उपलब्ध नहीं हुई। CSV क्लिपबोर्ड में कॉपी कर दी गई।')));
 }
 }
 Widget _metric(String title,String value,IconData icon)=>Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Row(children:[Icon(icon,color:blue),const SizedBox(width:12),Expanded(child:Text(title,style:const TextStyle(color:muted,fontSize:12))),Text(value,style:const TextStyle(color:navy,fontWeight:FontWeight.w900))]));
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('रिपोर्ट और एक्सपोर्ट')),body:ListView(padding:const EdgeInsets.all(17),children:[
 heading('कारोबार का सारांश','इस डिवाइस पर उपलब्ध रिकॉर्ड का कुल योग'),const SizedBox(height:12),
 OutlinedButton.icon(onPressed:_chooseRange,icon:const Icon(Icons.date_range),label:Text(range==null?'तारीख़ के अनुसार फ़िल्टर करें':'${range!.start.day}/${range!.start.month}/${range!.start.year} – ${range!.end.day}/${range!.end.month}/${range!.end.year}')),
 if(range!=null)Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>setState(()=>range=null),child:const Text('फ़िल्टर हटाएँ'))),
 _metric('कुल दर्ज बिक्री','₹${money(salesTotal)}',Icons.trending_up),const SizedBox(height:9),
 _metric('कुल खरीद','₹${money(purchaseTotal)}',Icons.shopping_cart_outlined),const SizedBox(height:9),
 _metric('सप्लायर बकाया','₹${money(supplierDue)}',Icons.storefront),const SizedBox(height:9),
 _metric('बिक्री वापसी','₹${money(salesReturns.fold<double>(0,(sum,e)=>sum+e.amount))}',Icons.assignment_return),const SizedBox(height:9),
 _metric('कारोबारी खर्च','₹${money(expenseTotal)}',Icons.payments_outlined),const SizedBox(height:9),
 _metric('ग्राहक बकाया','₹${money(dueTotal)}',Icons.people_outline),const SizedBox(height:9),
 _metric('व्यक्तिगत आय','₹${money(personalIncome)}',Icons.savings_outlined),const SizedBox(height:9),
 _metric('व्यक्तिगत खर्च','₹${money(personalExpense)}',Icons.shopping_bag_outlined),const SizedBox(height:9),
 _metric('स्टॉक का अनुमानित मूल्य','₹${money(products.fold<double>(0,(s,p)=>s+p.qty*p.price))}',Icons.inventory_2_outlined),
 const SizedBox(height:18),
 FilledButton.icon(onPressed:()=>_export(context),icon:const Icon(Icons.content_copy),label:const Text('CSV रिपोर्ट डाउनलोड / शेयर करें')),
 const SizedBox(height:10),
 const Text('नोट: एक्सपोर्ट में अभी उपलब्ध स्थानीय रिकॉर्ड शामिल हैं। पुराने रिकॉर्ड की तारीखें संग्रहीत नहीं हैं, इसलिए तारीख-वार रिपोर्ट और PDF अभी उपलब्ध नहीं हैं। यह रिपोर्ट क्लाउड सिंक का विकल्प नहीं है।',style:TextStyle(color:muted,fontSize:11))
 ]));
}

Widget heading(String a,String b)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(color:navy,fontSize:22,fontWeight:FontWeight.w900)),Text(b,style:const TextStyle(color:muted,fontSize:11))]);
Widget setting(IconData i,String a,String b,[VoidCallback? onTap])=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(14),child:Container(margin:const EdgeInsets.only(top:9),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:Row(children:[Icon(i,color:blue),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:12)),Text(b,style:const TextStyle(color:muted,fontSize:10))])),const Icon(Icons.chevron_right,color:muted)])));
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
 if(widget.retailer)Row(children:[Expanded(child:FilledButton(onPressed:widget.onCredit,child:const Text('उधार दर्ज करें'))),const SizedBox(width:6),Expanded(child:OutlinedButton(onPressed:widget.onPayment,child:const Text('वापसी दर्ज करें')))])else OutlinedButton(onPressed:widget.onPayment,child:const Text('वापसी दर्ज करें')),
 if(widget.retailer&&phone.isNotEmpty)TextButton.icon(onPressed:()=>launchUrl(Uri.parse('https://wa.me/91'+phone.replaceAll(RegExp(r'[^0-9]'),'')+'?text='+Uri.encodeComponent('नमस्ते, आपके Bharat Saathi खाते का बकाया ₹'+money(due)+' है।')),mode:LaunchMode.externalApplication),icon:const Icon(Icons.chat),label:const Text('WhatsApp संदेश')),
 if(loading)const LinearProgressIndicator()else ...rows.take(8).map((e)=>Text((e['transaction_type']=='credit'?'उधार +₹':'वापसी −₹')+money((e['amount'] as num).toDouble())+' • '+(e['note']??''),style:const TextStyle(color:muted,fontSize:11)))
 ]);}
}
class ComingSoonPage extends StatelessWidget{final String feature;const ComingSoonPage({super.key,required this.feature});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(feature)),body:Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[Container(width:76,height:76,decoration:BoxDecoration(color:const Color(0xFFFFF2D9),borderRadius:BorderRadius.circular(22)),child:const Icon(Icons.hourglass_top_rounded,color:Color(0xFF9A6515),size:38)),const SizedBox(height:18),Text(feature,style:const TextStyle(color:navy,fontSize:21,fontWeight:FontWeight.w900),textAlign:TextAlign.center),const SizedBox(height:9),const Text('यह सुविधा अभी उपलब्ध नहीं है। अधिकृत सेवा प्रदाता, API credentials और आवश्यक सुरक्षा जाँच पूरी होने के बाद ही इसे चालू किया जाएगा।',style:TextStyle(color:muted,fontSize:13),textAlign:TextAlign.center),const SizedBox(height:16),const Chip(label:Text('COMING SOON'))]))));}
String money(num n){final s=n.round().toString();if(s.length<=3)return s;var h=s.substring(0,s.length-3);final t=s.substring(s.length-3);final g=<String>[];while(h.length>2){g.insert(0,h.substring(h.length-2));h=h.substring(0,h.length-2);}if(h.isNotEmpty)g.insert(0,h);return '${g.join(',')},$t';}
