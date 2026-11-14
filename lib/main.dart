import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main()=>runApp(const BharatSaathiApp());
const navy=Color(0xFF14233B),blue=Color(0xFF29496D),gold=Color(0xFFF2A93B),bg=Color(0xFFE7EBF1),muted=Color(0xFF788596),green=Color(0xFF16845B),red=Color(0xFFD95454);
class BharatSaathiApp extends StatelessWidget{const BharatSaathiApp({super.key});@override Widget build(BuildContext context)=>MaterialApp(title:'Bharat Saathi',debugShowCheckedModeBanner:false,theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:navy),appBarTheme:const AppBarTheme(backgroundColor:bg,foregroundColor:navy,elevation:0)),home:const RetailerHome());}
class Item{String name,detail;int qty;double price;Item(this.name,this.detail,this.qty,this.price);Map<String,dynamic> toJson()=>{'name':name,'detail':detail,'qty':qty,'price':price};factory Item.fromJson(Map<String,dynamic> j)=>Item(j['name'] as String,j['detail'] as String,(j['qty'] as num).toInt(),(j['price'] as num).toDouble());}
class Record{String name,detail;double amount;IconData icon;Record(this.name,this.detail,this.amount,this.icon);Map<String,dynamic> toJson()=>{'name':name,'detail':detail,'amount':amount,'icon':icon.codePoint};factory Record.fromJson(Map<String,dynamic> j)=>Record(j['name'] as String,j['detail'] as String,(j['amount'] as num).toDouble(),IconData((j['icon'] as num).toInt(),fontFamily:'MaterialIcons'));}
class RetailerHome extends StatefulWidget{const RetailerHome({super.key});@override State<RetailerHome> createState()=>_RetailerHomeState();}
class _RetailerHomeState extends State<RetailerHome>{
 int tab=0;double cash=0,expenses=0,personalBudget=0;String personalBudgetName='व्यक्तिगत खर्च सीमा';bool loaded=false;
 final _prefs=SharedPreferencesAsync();
 final products=<Item>[];
 final sales=<Record>[];
 final expensesList=<Record>[];
 final personalTransactions=<Record>[];
 final khata=<Record>[];
 @override void initState(){super.initState();_restore();}
 Future<void> _restore()async{try{final p=await _prefs.getString('bharat_saathi_store_v1');if(p!=null){final d=jsonDecode(p) as Map<String,dynamic>;cash=(d['cash'] as num?)?.toDouble()??0;expenses=(d['expenses'] as num?)?.toDouble()??0;personalBudget=(d['personalBudget'] as num?)?.toDouble()??0;personalBudgetName=(d['personalBudgetName'] as String?)??'व्यक्तिगत खर्च सीमा';products.addAll((d['products'] as List? ?? []).map((e)=>Item.fromJson(Map<String,dynamic>.from(e as Map))));sales.addAll((d['sales'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));expensesList.addAll((d['expensesList'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));khata.addAll((d['khata'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));personalTransactions.addAll((d['personalTransactions'] as List? ?? []).map((e)=>Record.fromJson(Map<String,dynamic>.from(e as Map))));}}catch(_){}if(mounted)setState(()=>loaded=true);}
 Future<void> _persist()async{try{await _prefs.setString('bharat_saathi_store_v1',jsonEncode({'cash':cash,'expenses':expenses,'personalBudget':personalBudget,'personalBudgetName':personalBudgetName,'products':products.map((e)=>e.toJson()).toList(),'sales':sales.map((e)=>e.toJson()).toList(),'expensesList':expensesList.map((e)=>e.toJson()).toList(),'khata':khata.map((e)=>e.toJson()).toList(),'personalTransactions':personalTransactions.map((e)=>e.toJson()).toList()}));}catch(_){if(mounted)msg('डेटा इस डिवाइस पर सेव नहीं हो पाया');}}
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
 DropdownButtonFormField<Item>(value:selected,decoration:const InputDecoration(labelText:'प्रोडक्ट'),items:products.map((p)=>DropdownMenuItem<Item>(value:p,child:Text('${p.name} • स्टॉक ${p.qty}'))).toList(),onChanged:(p){if(p!=null)refresh(()=>selected=p);}),
 const SizedBox(height:10),TextField(controller:quantity,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'मात्रा')),
 const SizedBox(height:10),DropdownButtonFormField<String>(value:paymentMode,decoration:const InputDecoration(labelText:'भुगतान प्रकार'),items:const[DropdownMenuItem(value:'नकद',child:Text('नकद / बैंक भुगतान')),DropdownMenuItem(value:'उधार',child:Text('ग्राहक उधार'))],onChanged:(v){if(v!=null)refresh(()=>paymentMode=v);}),
 const SizedBox(height:12),Align(alignment:Alignment.centerLeft,child:Text('बिक्री मूल्य: ₹${money(selected.price)} प्रति यूनिट',style:const TextStyle(color:muted,fontSize:12))),
 const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton(onPressed:(){final q=int.tryParse(quantity.text);if(customer.text.trim().isEmpty||q==null||q<1){msg('ग्राहक और सही मात्रा भरें');return;}if(q>selected.qty){msg('उपलब्ध स्टॉक से अधिक मात्रा नहीं बेच सकते');return;}if(selected.price<=0){msg('इस प्रोडक्ट का बिक्री मूल्य पहले सेट करें');return;}final total=selected.price*q;setState((){selected.qty-=q;sales.insert(0,Record(customer.text.trim(),'${selected.name} × $q • $paymentMode',total,Icons.receipt_long));if(paymentMode=='नकद'){cash+=total;}else{khata.insert(0,Record(customer.text.trim(),'बिक्री उधार • अभी',total,Icons.person));}});_persist();Navigator.pop(sheetContext);msg('बिक्री सेव हुई और स्टॉक अपडेट हुआ');},child:const Text('बिक्री सेव करें')))
 ]))));
}
 void expense()=>form('खर्च दर्ज करें','खर्च का विवरण','खर्च राशि (₹)',(n,a){setState((){expenses+=a;cash-=a;expensesList.insert(0,Record(n,'खर्च • अभी',a,Icons.payments_outlined));});_persist();msg('खर्च इस डिवाइस पर सेव हुआ');});
 void entry([bool payment=false])=>form(payment?'भुगतान दर्ज करें':'खाता एंट्री','ग्राहक का नाम',payment?'भुगतान राशि (₹)':'उधार राशि (₹)',(n,a){final outstanding=khata.where((e)=>e.name.toLowerCase()==n.toLowerCase()).fold<double>(0,(sum,e)=>sum+e.amount);if(payment&&(outstanding<=0||a>outstanding)){msg(outstanding<=0?'इस ग्राहक का बकाया उपलब्ध नहीं है':'भुगतान बकाया राशि से अधिक नहीं हो सकता');return;}setState((){khata.insert(0,Record(n,payment?'भुगतान • अभी':'उधार • अभी',payment?-a:a,payment?Icons.payments_outlined:Icons.person));if(payment)cash+=a;});_persist();msg('खाता रिकॉर्ड इस डिवाइस पर सेव हुआ');});
 void setPersonalBudget()=>form('खर्च सीमा सेट करें','सीमा का नाम','अधिकतम राशि (₹)',(n,a){setState((){personalBudget=a;personalBudgetName=n;});_persist();msg('खर्च सीमा सेव हुई');});
 void personalEntry(bool income)=>form(income?'व्यक्तिगत आय दर्ज करें':'व्यक्तिगत खर्च दर्ज करें',income?'आय का स्रोत':'खर्च का विवरण',income?'आय राशि (₹)':'खर्च राशि (₹)',(n,a){setState(()=>personalTransactions.insert(0,Record(n,income?'आय • अभी':'खर्च • अभी',income?a:-a,income?Icons.trending_up:Icons.payments_outlined)));_persist();msg('व्यक्तिगत रिकॉर्ड इस डिवाइस पर सेव हुआ');});
 void restock(Item item)=>form('स्टॉक जोड़ें','प्रोडक्ट का नाम','जोड़ने की मात्रा',(n,a){setState(()=>item.qty+=a.round());_persist();msg('स्टॉक अपडेट हुआ');});
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
 final pages=<Widget>[Dashboard(cash:cash,expenses:expenses,sales:sales,khata:khata,products:products,onSale:sale,onExpense:expense,onKhata:entry),PersonalFinancePage(items:personalTransactions,budget:personalBudget,budgetName:personalBudgetName,onSetBudget:setPersonalBudget,onIncome:()=>personalEntry(true),onExpense:()=>personalEntry(false)),ProductPage(items:products,onRestock:restock),SalesPage(items:sales,expenses:expensesList),KhataPage(items:khata,onPayment:()=>entry(true)),const ProfilePage()];
 return Scaffold(appBar:AppBar(titleSpacing:17,title:Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.account_balance_wallet,color:gold)),const SizedBox(width:10),const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('भारत साथी',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text('आपका कारोबार, आपका हिसाब',style:TextStyle(fontSize:10,color:muted))])]),actions:[IconButton(onPressed:()=>msg('नोटिफिकेशन अगला चरण है'),icon:const Icon(Icons.notifications_none))]),body:SafeArea(child:loaded?IndexedStack(index:tab,children:pages):const Center(child:CircularProgressIndicator())),floatingActionButton:tab==2?fab('प्रोडक्ट',product):tab==3?fab('बिक्री',sale):tab==4?fab('खाता एंट्री',entry):null,bottomNavigationBar:NavigationBar(height:68,backgroundColor:const Color(0xFFEEF1F5),indicatorColor:const Color(0xFFDCE3EC),selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[NavigationDestination(icon:Icon(Icons.space_dashboard_outlined),selectedIcon:Icon(Icons.space_dashboard),label:'होम'),NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),label:'पर्सनल'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'स्टॉक'),NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'बिक्री'),NavigationDestination(icon:Icon(Icons.menu_book_outlined),label:'खाता'),NavigationDestination(icon:Icon(Icons.person_outline),label:'प्रोफाइल')]));
 }
 Widget fab(String s,VoidCallback f)=>FloatingActionButton.extended(onPressed:f,backgroundColor:navy,foregroundColor:Colors.white,icon:const Icon(Icons.add),label:Text(s));
}
class Dashboard extends StatelessWidget{
 final double cash,expenses;final List<Record> sales,khata;final List<Item> products;final VoidCallback onSale,onExpense,onKhata;
 const Dashboard({super.key,required this.cash,required this.expenses,required this.sales,required this.khata,required this.products,required this.onSale,required this.onExpense,required this.onKhata});
 @override Widget build(BuildContext context){
 final total=sales.fold<double>(0,(s,e)=>s+e.amount),due=khata.fold<double>(0,(s,e)=>s+e.amount);
 return ListView(padding:const EdgeInsets.fromLTRB(17,8,17,28),children:[
 Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('नमस्ते 👋',style:TextStyle(color:muted,fontSize:12)),SizedBox(height:3),Text('आपका बिजनेस डैशबोर्ड',style:TextStyle(color:navy,fontSize:20,fontWeight:FontWeight.w900))]),Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:const Color(0xFFFFF2D9),borderRadius:BorderRadius.circular(20)),child:const Text('● ऑफलाइन',style:TextStyle(color:Color(0xFF9A6515),fontSize:9,fontWeight:FontWeight.w900)))]),
 const SizedBox(height:17),
 Container(padding:const EdgeInsets.all(19),decoration:BoxDecoration(gradient:const LinearGradient(colors:[navy,blue],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(23),boxShadow:[BoxShadow(color:navy.withValues(alpha: .15),blurRadius:16,offset:const Offset(0,8))]),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('रिकॉर्डेड नेट कैश फ्लो',style:TextStyle(color:Colors.white70,fontSize:12)),Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.white12,borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.account_balance_wallet_outlined,color:gold))]),
 const SizedBox(height:7),Text('₹${money(cash)}',style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w900)),
 const SizedBox(height:16),Container(height:1,color:Colors.white24),const SizedBox(height:13),
 Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[mini('बिक्री दर्ज','₹${money(total)}',Icons.trending_up),mini('ग्राहक खाते','${khata.length} ग्राहक',Icons.people_outline),mini('स्टेटस','इस डिवाइस पर',Icons.phone_android)])
 ])),
 const SizedBox(height:13),Row(children:[Expanded(child:metric('कुल बिक्री','₹${money(total)}',Icons.trending_up,green)),const SizedBox(width:10),Expanded(child:metric('कुल खर्च','₹${money(expenses)}',Icons.payments_outlined,red))]),
 const SizedBox(height:10),Row(children:[Expanded(child:metric('ग्राहक बकाया','₹${money(due)}',Icons.people_alt_outlined,const Color(0xFF875BB5))),const SizedBox(width:10),Expanded(child:metric('स्टॉक आइटम','${products.length}',Icons.inventory_2_outlined,const Color(0xFF247D9B)))]),
 const SizedBox(height:22),section('त्वरित काम','रोज़ के काम आसान बनाएं'),const SizedBox(height:11),
 Row(children:[Expanded(child:quick('नई बिक्री',Icons.point_of_sale,const Color(0xFFFFF0D7),const Color(0xFFB87510),onSale)),const SizedBox(width:9),Expanded(child:quick('खर्च जोड़ें',Icons.add_card,const Color(0xFFE3F4EC),green,onExpense)),const SizedBox(width:9),Expanded(child:quick('खाता एंट्री',Icons.menu_book,const Color(0xFFECE8F8),const Color(0xFF7653A8),onKhata))]),
 const SizedBox(height:22),section('साप्ताहिक बिक्री','रिकॉर्ड उपलब्ध होने पर रिपोर्ट दिखेगी'),const SizedBox(height:11),Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:Text(sales.isEmpty?'अभी बिक्री दर्ज नहीं हुई है। पहली बिक्री जोड़ें।':'${sales.length} बिक्री रिकॉर्ड सेव हैं। विस्तृत चार्ट अगली रिपोर्टिंग रिलीज़ में आएगा।',style:const TextStyle(color:muted,fontSize:12))),
 const SizedBox(height:22),section('हाल की बिक्री','नवीनतम बिल और भुगतान'),if(sales.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:14),child:Text('कोई बिक्री रिकॉर्ड नहीं है。',style:TextStyle(color:muted,fontSize:12))) else ...sales.take(3).map(activity),
 const SizedBox(height:15),const Center(child:Text('भारत साथी • सरल हिसाब, बेहतर कारोबार',style:TextStyle(color:muted,fontSize:10)))
 ]);
 }
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
 final spent=items.where((e)=>e.amount<0).fold<double>(0,(s,e)=>s+e.amount.abs());
 return ListView(padding:const EdgeInsets.all(17),children:[
 heading('पर्सनल फाइनेंस','अपनी आय और खर्च का हिसाब रखें'),const SizedBox(height:14),
 Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 const Text('कुल बचत / शेष',style:TextStyle(color:Colors.white70,fontSize:11)),
 Text('₹${money(income-spent)}',style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.w900)),
 const SizedBox(height:12),Row(children:[Expanded(child:mini('कुल आय','₹${money(income)}',Icons.trending_up)),Expanded(child:mini('कुल खर्च','₹${money(spent)}',Icons.payments_outlined))])
 ])),const SizedBox(height:14),
 Row(children:[Expanded(child:FilledButton.icon(onPressed:onIncome,icon:const Icon(Icons.add),label:const Text('आय जोड़ें'),style:FilledButton.styleFrom(backgroundColor:green))),const SizedBox(width:9),Expanded(child:FilledButton.icon(onPressed:onExpense,icon:const Icon(Icons.remove),label:const Text('खर्च जोड़ें'),style:FilledButton.styleFrom(backgroundColor:red)))]),
 const SizedBox(height:20),section('खर्च सीमा',budgetName),const SizedBox(height:8),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(budget>0?'₹${money(spent)} / ₹${money(budget)}':'सीमा तय नहीं है',style:const TextStyle(color:navy,fontWeight:FontWeight.w800)),TextButton(onPressed:onSetBudget,child:Text(budget>0?'बदलें':'सेट करें'))]),if(budget>0)LinearProgressIndicator(value:(spent/budget).clamp(0.0,1.0).toDouble(),backgroundColor:bg,color:spent>budget?red:green),if(budget>0)Padding(padding:const EdgeInsets.only(top:7),child:Text(spent>budget?'खर्च तय सीमा से अधिक है।':'सीमा में शेष ₹${money((budget-spent).clamp(0.0,double.infinity))}',style:TextStyle(color:spent>budget?red:muted,fontSize:11)))])),const SizedBox(height:20),section('लेन-देन','इस डिवाइस पर सेव रिकॉर्ड'),
 if(items.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Center(child:Text('अभी कोई व्यक्तिगत लेन-देन नहीं है।',style:TextStyle(color:muted))))
 else ...items.map((e)=>Container(margin:const EdgeInsets.only(top:8),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:Row(children:[CircleAvatar(backgroundColor:e.amount>=0?const Color(0xFFE3F4EC):const Color(0xFFFFE8E8),child:Icon(e.icon,color:e.amount>=0?green:red)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e.name,style:const TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:12)),Text(e.detail,style:const TextStyle(color:muted,fontSize:10))])),Text('${e.amount>=0?'+':'−'} ₹${money(e.amount.abs())}',style:TextStyle(color:e.amount>=0?green:red,fontWeight:FontWeight.w900))])))
 ]);
 }
}
class ProductPage extends StatelessWidget{final List<Item> items;final void Function(Item) onRestock;const ProductPage({super.key,required this.items,required this.onRestock});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(17),children:[heading('प्रोडक्ट और स्टॉक','इन्वेंट्री का पूरा कंट्रोल'),const SizedBox(height:14),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Text('कुल प्रोडक्ट: ${items.length}     •     कम स्टॉक: ${items.where((e)=>e.qty<15).length}',style:const TextStyle(color:navy,fontWeight:FontWeight.w800))),...items.map((p)=>Container(margin:const EdgeInsets.only(top:9),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Row(children:[const Icon(Icons.inventory_2_outlined,color:blue,size:25),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.name,style:const TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:12)),Text(p.detail,style:const TextStyle(color:muted,fontSize:10)),Text('₹${money(p.price)} बिक्री मूल्य',style:const TextStyle(color:muted,fontSize:10))])),Column(children:[Text('${p.qty}',style:TextStyle(color:p.qty<15?red:green,fontWeight:FontWeight.w900,fontSize:17)),const Text('यूनिट',style:TextStyle(color:muted,fontSize:9)),IconButton(tooltip:'स्टॉक जोड़ें',onPressed:()=>onRestock(p),icon:const Icon(Icons.add_circle_outline,color:blue,size:20))])])))]);}
class SalesPage extends StatelessWidget{final List<Record> items,expenses;const SalesPage({super.key,required this.items,required this.expenses});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(17),children:[heading('बिक्री और खर्च','कारोबार के सभी रिकॉर्ड'),const SizedBox(height:15),section('बिक्री','दर्ज की गई बिक्री'),if(items.isEmpty)const Text('अभी कोई बिक्री नहीं।',style:TextStyle(color:muted)) else ...items.map(activity),const SizedBox(height:20),section('खर्च','दर्ज किए गए खर्च'),if(expenses.isEmpty)const Text('अभी कोई खर्च नहीं।',style:TextStyle(color:muted)) else ...expenses.map(activity)]);}
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
              const Text('कुल बकाया • डेमो डेटा', style: TextStyle(color: Colors.white70, fontSize: 11)),
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
class ProfilePage extends StatelessWidget{const ProfilePage({super.key});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(17),children:[heading('प्रोफाइल और सेटिंग','अपने अकाउंट को मैनेज करें'),const SizedBox(height:18),Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:const Column(children:[CircleAvatar(radius:34,backgroundColor:navy,child:Icon(Icons.storefront,color:gold,size:31)),SizedBox(height:10),Text('मेरा रिटेल स्टोर',style:TextStyle(color:navy,fontWeight:FontWeight.w900,fontSize:17)),Text('ऑफ़लाइन प्रोफ़ाइल • क्लाउड लॉगिन अगला चरण',style:TextStyle(color:muted,fontSize:10))])),setting(Icons.lock_outline,'अकाउंट और सुरक्षा','Coming Soon • Supabase Auth सेटअप बाकी',()=>openComingSoon(context,'अकाउंट और सुरक्षा')),setting(Icons.cloud_upload_outlined,'डेटा बैकअप','Coming Soon • सुरक्षित क्लाउड बैकअप',()=>openComingSoon(context,'डेटा बैकअप')),setting(Icons.language,'भाषा','हिन्दी'),setting(Icons.help_outline,'सहायता केंद्र','सपोर्ट और संपर्क'),setting(Icons.phone_android,'मोबाइल / DTH / FASTag रिचार्ज','Coming Soon • स्वीकृत प्रदाता API आवश्यक',()=>openComingSoon(context,'रिचार्ज सेवाएँ')),setting(Icons.receipt_long,'BBPS बिल भुगतान','Coming Soon • BBPS पार्टनर आवश्यक',()=>openComingSoon(context,'BBPS बिल भुगतान')),setting(Icons.local_police_outlined,'ट्रैफिक चालान भुगतान','Coming Soon • सरकारी / अधिकृत API आवश्यक',()=>openComingSoon(context,'चालान भुगतान')),setting(Icons.account_balance,'UPI / मनी ट्रांसफर','Coming Soon • बैंकिंग पार्टनर और अनुपालन आवश्यक',()=>openComingSoon(context,'UPI और मनी ट्रांसफर'))]);}
Widget heading(String a,String b)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(color:navy,fontSize:22,fontWeight:FontWeight.w900)),Text(b,style:const TextStyle(color:muted,fontSize:11))]);
Widget setting(IconData i,String a,String b,[VoidCallback? onTap])=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(14),child:Container(margin:const EdgeInsets.only(top:9),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:Row(children:[Icon(i,color:blue),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:12)),Text(b,style:const TextStyle(color:muted,fontSize:10))])),const Icon(Icons.chevron_right,color:muted)])));
void openComingSoon(BuildContext context,String feature)=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>ComingSoonPage(feature:feature)));
class ComingSoonPage extends StatelessWidget{final String feature;const ComingSoonPage({super.key,required this.feature});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(feature)),body:Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[Container(width:76,height:76,decoration:BoxDecoration(color:const Color(0xFFFFF2D9),borderRadius:BorderRadius.circular(22)),child:const Icon(Icons.hourglass_top_rounded,color:Color(0xFF9A6515),size:38)),const SizedBox(height:18),Text(feature,style:const TextStyle(color:navy,fontSize:21,fontWeight:FontWeight.w900),textAlign:TextAlign.center),const SizedBox(height:9),const Text('यह सुविधा अभी उपलब्ध नहीं है। अधिकृत सेवा प्रदाता, API credentials और आवश्यक सुरक्षा जाँच पूरी होने के बाद ही इसे चालू किया जाएगा।',style:TextStyle(color:muted,fontSize:13),textAlign:TextAlign.center),const SizedBox(height:16),const Chip(label:Text('COMING SOON'))]))));}
String money(num n){final s=n.round().toString();if(s.length<=3)return s;var h=s.substring(0,s.length-3);final t=s.substring(s.length-3);final g=<String>[];while(h.length>2){g.insert(0,h.substring(h.length-2));h=h.substring(0,h.length-2);}if(h.isNotEmpty)g.insert(0,h);return '${g.join(',')},$t';}
