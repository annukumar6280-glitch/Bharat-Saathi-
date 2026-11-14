import 'package:material_ui/material_ui.dart';
void main()=>runApp(const BharatSaathiApp());
const navy=Color(0xFF14233B),blue=Color(0xFF29496D),gold=Color(0xFFF2A93B),bg=Color(0xFFF4F6F9),muted=Color(0xFF788596),green=Color(0xFF16845B),red=Color(0xFFD95454);
class BharatSaathiApp extends StatelessWidget{const BharatSaathiApp({super.key});@override Widget build(BuildContext context)=>MaterialApp(title:'Bharat Saathi',debugShowCheckedModeBanner:false,theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:navy),appBarTheme:const AppBarTheme(backgroundColor:bg,foregroundColor:navy,elevation:0)),home:const RetailerHome());}
class Item{String name,detail;int qty;double price;Item(this.name,this.detail,this.qty,this.price);}
class Record{String name,detail;double amount;IconData icon;Record(this.name,this.detail,this.amount,this.icon);}
class RetailerHome extends StatefulWidget{const RetailerHome({super.key});@override State<RetailerHome> createState()=>_RetailerHomeState();}
class _RetailerHomeState extends State<RetailerHome>{
 int tab=0;double cash=28450,expenses=6320;
 final products=<Item>[Item('Aashirvaad Atta','5 kg pack • Grocery',18,285),Item('Tata Salt','1 kg pack • Grocery',32,28),Item('Parle-G Family Pack','800 g • Snacks',12,95),Item('Amul Gold Milk','500 ml • Dairy',24,35)];
 final sales=<Record>[Record('Walk-in Customer','Invoice #1042 • 10:42 AM',2450,Icons.receipt_long),Record('Ramesh Kumar','Invoice #1041 • 09:18 AM',780,Icons.person_outline),Record('Walk-in Customer','Invoice #1040 • Yesterday',1320,Icons.shopping_bag_outlined)];
 final khata=<Record>[Record('Ramesh Kumar','उधार • 12 Nov',1250,Icons.person),Record('Sita General Store','भुगतान • 10 Nov',-800,Icons.store),Record('Mohan Lal','उधार • 09 Nov',640,Icons.person)];
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
 void sale()=>form('नई बिक्री','ग्राहक / विवरण','बिक्री राशि (₹)',(n,a){setState((){sales.insert(0,Record(n,'नई बिक्री • अभी',a,Icons.receipt_long));cash+=a;});msg('डेमो बिक्री जोड़ी गई');});
 void expense()=>form('खर्च दर्ज करें','खर्च का विवरण','खर्च राशि (₹)',(n,a){setState(()=>expenses+=a);msg('डेमो खर्च दर्ज हुआ');});
 void entry()=>form('खाता एंट्री','ग्राहक का नाम','उधार राशि (₹)',(n,a){setState(()=>khata.insert(0,Record(n,'उधार • अभी',a,Icons.person)));msg('डेमो खाता एंट्री जोड़ी गई');});
 void product()=>form('नया प्रोडक्ट','प्रोडक्ट का नाम','शुरुआती स्टॉक', (n,a){setState(()=>products.add(Item(n,'नया प्रोडक्ट',a.round(),0)));msg('डेमो प्रोडक्ट जोड़ा गया');});
 @override Widget build(BuildContext context){
 final pages=<Widget>[Dashboard(cash:cash,expenses:expenses,sales:sales,khata:khata,onSale:sale,onExpense:expense,onKhata:entry),ProductPage(items:products),SalesPage(items:sales),KhataPage(items:khata),const ProfilePage()];
 return Scaffold(appBar:AppBar(titleSpacing:17,title:Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.account_balance_wallet,color:gold)),const SizedBox(width:10),const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('भारत साथी',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text('आपका कारोबार, आपका हिसाब',style:TextStyle(fontSize:10,color:muted))])]),actions:[IconButton(onPressed:()=>msg('नोटिफिकेशन अगला चरण है'),icon:const Icon(Icons.notifications_none))]),body:SafeArea(child:IndexedStack(index:tab,children:pages)),floatingActionButton:tab==1?fab('प्रोडक्ट',product):tab==2?fab('बिक्री',sale):tab==3?fab('खाता एंट्री',entry):null,bottomNavigationBar:NavigationBar(height:68,backgroundColor:Colors.white,indicatorColor:const Color(0xFFE8EDF4),selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[NavigationDestination(icon:Icon(Icons.space_dashboard_outlined),selectedIcon:Icon(Icons.space_dashboard),label:'होम'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'स्टॉक'),NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'बिक्री'),NavigationDestination(icon:Icon(Icons.menu_book_outlined),label:'खाता'),NavigationDestination(icon:Icon(Icons.person_outline),label:'प्रोफाइल')]));
 }
 Widget fab(String s,VoidCallback f)=>FloatingActionButton.extended(onPressed:f,backgroundColor:navy,foregroundColor:Colors.white,icon:const Icon(Icons.add),label:Text(s));
}
class Dashboard extends StatelessWidget{
 final double cash,expenses;final List<Record> sales,khata;final VoidCallback onSale,onExpense,onKhata;
 const Dashboard({super.key,required this.cash,required this.expenses,required this.sales,required this.khata,required this.onSale,required this.onExpense,required this.onKhata});
 @override Widget build(BuildContext context){
 final total=sales.fold<double>(0,(s,e)=>s+e.amount),due=khata.fold<double>(0,(s,e)=>s+e.amount);
 return ListView(padding:const EdgeInsets.fromLTRB(17,8,17,28),children:[
 Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('नमस्ते 👋',style:TextStyle(color:muted,fontSize:12)),SizedBox(height:3),Text('आपका बिजनेस डैशबोर्ड',style:TextStyle(color:navy,fontSize:20,fontWeight:FontWeight.w900))]),Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:const Color(0xFFFFF2D9),borderRadius:BorderRadius.circular(20)),child:const Text('● DEMO',style:TextStyle(color:Color(0xFF9A6515),fontSize:9,fontWeight:FontWeight.w900)))]),
 const SizedBox(height:17),
 Container(padding:const EdgeInsets.all(19),decoration:BoxDecoration(gradient:const LinearGradient(colors:[navy,blue],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(23),boxShadow:[BoxShadow(color:navy.withValues(alpha: .15),blurRadius:16,offset:const Offset(0,8))]),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('कुल कैश / बैंक बैलेंस',style:TextStyle(color:Colors.white70,fontSize:12)),Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.white12,borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.account_balance_wallet_outlined,color:gold))]),
 const SizedBox(height:7),Text('₹${money(cash)}',style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w900)),
 const SizedBox(height:16),Container(height:1,color:Colors.white24),const SizedBox(height:13),
 Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[mini('बिक्री दर्ज','₹${money(total)}',Icons.trending_up),mini('ग्राहक खाते','${khata.length} ग्राहक',Icons.people_outline),mini('स्टेटस','सक्रिय',Icons.check_circle_outline)])
 ])),
 const SizedBox(height:13),Row(children:[Expanded(child:metric('कुल बिक्री','₹${money(total)}',Icons.trending_up,green)),const SizedBox(width:10),Expanded(child:metric('कुल खर्च','₹${money(expenses)}',Icons.payments_outlined,red))]),
 const SizedBox(height:10),Row(children:[Expanded(child:metric('ग्राहक बकाया','₹${money(due)}',Icons.people_alt_outlined,const Color(0xFF875BB5))),const SizedBox(width:10),Expanded(child:metric('स्टॉक आइटम','${4}',Icons.inventory_2_outlined,const Color(0xFF247D9B)))]),
 const SizedBox(height:22),section('त्वरित काम','रोज़ के काम आसान बनाएं'),const SizedBox(height:11),
 Row(children:[Expanded(child:quick('नई बिक्री',Icons.point_of_sale,const Color(0xFFFFF0D7),const Color(0xFFB87510),onSale)),const SizedBox(width:9),Expanded(child:quick('खर्च जोड़ें',Icons.add_card,const Color(0xFFE3F4EC),green,onExpense)),const SizedBox(width:9),Expanded(child:quick('खाता एंट्री',Icons.menu_book,const Color(0xFFECE8F8),const Color(0xFF7653A8),onKhata))]),
 const SizedBox(height:22),section('साप्ताहिक बिक्री','पिछले 7 दिनों का डेमो ट्रेंड'),const SizedBox(height:11),const Chart(),
 const SizedBox(height:22),section('हाल की बिक्री','नवीनतम बिल और भुगतान'),...sales.take(3).map(activity),
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
class ProductPage extends StatelessWidget{final List<Item> items;const ProductPage({super.key,required this.items});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(17),children:[heading('प्रोडक्ट और स्टॉक','इन्वेंट्री का पूरा कंट्रोल'),const SizedBox(height:14),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Text('कुल प्रोडक्ट: ${items.length}     •     कम स्टॉक: ${items.where((e)=>e.qty<15).length}',style:const TextStyle(color:navy,fontWeight:FontWeight.w800))),...items.map((p)=>Container(margin:const EdgeInsets.only(top:9),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Row(children:[const Icon(Icons.inventory_2_outlined,color:blue,size:25),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.name,style:const TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:12)),Text(p.detail,style:const TextStyle(color:muted,fontSize:10)),Text('₹${money(p.price)} बिक्री मूल्य',style:const TextStyle(color:muted,fontSize:10))])),Column(children:[Text('${p.qty}',style:TextStyle(color:p.qty<15?red:green,fontWeight:FontWeight.w900,fontSize:17)),const Text('यूनिट',style:TextStyle(color:muted,fontSize:9))])])))]);}
class SalesPage extends StatelessWidget{final List<Record> items;const SalesPage({super.key,required this.items});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(17),children:[heading('बिक्री और बिल','आपकी बिक्री का रिकॉर्ड'),const SizedBox(height:15),...items.map(activity)]);}
class KhataPage extends StatelessWidget {
  final List<Record> items;
  const KhataPage({super.key, required this.items});

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
class ProfilePage extends StatelessWidget{const ProfilePage({super.key});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(17),children:[heading('प्रोफाइल और सेटिंग','अपने अकाउंट को मैनेज करें'),const SizedBox(height:18),Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:const Column(children:[CircleAvatar(radius:34,backgroundColor:navy,child:Icon(Icons.storefront,color:gold,size:31)),SizedBox(height:10),Text('मेरा रिटेल स्टोर',style:TextStyle(color:navy,fontWeight:FontWeight.w900,fontSize:17)),Text('डेमो अकाउंट • लॉगिन सेटअप बाकी',style:TextStyle(color:muted,fontSize:10))])),setting(Icons.lock_outline,'अकाउंट और सुरक्षा','लॉगिन और प्रोफाइल सेटिंग'),setting(Icons.cloud_upload_outlined,'डेटा बैकअप','क्लाउड सिंक अगला चरण'),setting(Icons.language,'भाषा','हिन्दी'),setting(Icons.help_outline,'सहायता केंद्र','सपोर्ट और संपर्क')]);}
Widget heading(String a,String b)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(color:navy,fontSize:22,fontWeight:FontWeight.w900)),Text(b,style:const TextStyle(color:muted,fontSize:11))]);
Widget setting(IconData i,String a,String b)=>Container(margin:const EdgeInsets.only(top:9),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:Row(children:[Icon(i,color:blue),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(color:navy,fontWeight:FontWeight.w800,fontSize:12)),Text(b,style:const TextStyle(color:muted,fontSize:10))])),const Icon(Icons.chevron_right,color:muted)]));
String money(num n){final s=n.round().toString();if(s.length<=3)return s;var h=s.substring(0,s.length-3);final t=s.substring(s.length-3);final g=<String>[];while(h.length>2){g.insert(0,h.substring(h.length-2));h=h.substring(0,h.length-2);}if(h.isNotEmpty)g.insert(0,h);return '${g.join(',')},$t';}
