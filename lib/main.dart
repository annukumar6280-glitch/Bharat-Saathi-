import 'package:flutter/material.dart';

void main() => runApp(const BharatSaathiApp());
const navy = Color(0xFF14213D), orange = Color(0xFFFF9F1C), bg = Color(0xFFF5F7FA), green = Color(0xFF16845B), red = Color(0xFFD94B4B);

class BharatSaathiApp extends StatelessWidget {
  const BharatSaathiApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Bharat Saathi', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: navy),
      appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: navy, elevation: 0)),
    home: const RetailerShell());
}

class RetailerShell extends StatefulWidget {
  const RetailerShell({super.key});
  @override State<RetailerShell> createState() => _RetailerShellState();
}
class _RetailerShellState extends State<RetailerShell> {
  int tab = 0;
  double cash = 18450, expenses = 6320;
  final products = <String>['Aashirvaad Atta 5kg','Tata Salt 1kg','Parle-G Family Pack','Amul Gold Milk'];
  final stock = <int>[18,32,12,24];
  final sales = <Map<String,dynamic>>[
    {'name':'बिक्री #1042','detail':'आज • 10:42 AM','amount':2450.0},
    {'name':'बिक्री #1041','detail':'आज • 09:18 AM','amount':780.0},
    {'name':'बिक्री #1040','detail':'कल','amount':1320.0}];
  final khata = <Map<String,dynamic>>[
    {'name':'Ramesh Kumar','detail':'उधार • 12 Nov','amount':1250.0},
    {'name':'Sita General Store','detail':'भुगतान • 10 Nov','amount':-800.0},
    {'name':'Mohan Lal','detail':'उधार • 09 Nov','amount':640.0}];

  void message(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Future<void> addRecord(String title, String label, void Function(String,double) save) async {
    final name = TextEditingController(), amount = TextEditingController();
    await showModalBottomSheet<void>(context:context, isScrollControlled:true,
      shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
      builder:(ctx)=>Padding(padding:EdgeInsets.fromLTRB(20,22,20,20+MediaQuery.of(ctx).viewInsets.bottom),
        child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:navy)),
          const SizedBox(height:16),TextField(controller:name,decoration:InputDecoration(labelText:label)),
          const SizedBox(height:12),TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'राशि / मात्रा')),
          const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton(onPressed:(){
            final n=double.tryParse(amount.text.trim());
            if(name.text.trim().isEmpty || n==null || n<=0){message('नाम और सही संख्या भरें');return;}
            save(name.text.trim(),n);Navigator.pop(ctx);
          },child:const Text('सेव करें')))
        ])));
  }
  void newSale()=>addRecord('नई बिक्री','ग्राहक / विवरण',(n,v){setState((){sales.insert(0,{'name':n,'detail':'अभी • नई बिक्री','amount':v});cash+=v;});message('बिक्री डेमो में सेव हुई');});
  void newKhata()=>addRecord('खाता एंट्री','ग्राहक का नाम',(n,v){setState(()=>khata.insert(0,{'name':n,'detail':'उधार • अभी','amount':v}));message('खाता डेमो में सेव हुआ');});
  void newProduct()=>addRecord('नया प्रोडक्ट','प्रोडक्ट का नाम',(n,v){setState((){products.add(n);stock.add(v.round());});message('प्रोडक्ट डेमो में जुड़ा');});
  void newExpense()=>addRecord('नया खर्च','खर्च का विवरण',(n,v){setState(()=>expenses+=v);message('खर्च डेमो में सेव हुआ');});

  @override Widget build(BuildContext context) {
    final pages=<Widget>[
      Dashboard(cash:cash,expenses:expenses,sales:sales,khata:khata,onSale:newSale,onExpense:newExpense,onKhata:newKhata),
      ProductScreen(products:products,stock:stock), SalesScreen(sales:sales), KhataScreen(entries:khata), const ProfileScreen()];
    return Scaffold(
      appBar:AppBar(title:Row(children:[
        Container(width:38,height:38,decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.account_balance_wallet,color:orange)),
        const SizedBox(width:10),const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('भारत साथी',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
          Text('आपका कारोबार, आपका हिसाब',style:TextStyle(fontSize:10,color:Colors.black54))])]),
        actions:[IconButton(onPressed:()=>message('नोटिफिकेशन अगला चरण है'),icon:const Icon(Icons.notifications_none))]),
      body:SafeArea(child:pages[tab]),
      floatingActionButton:tab==1?FloatingActionButton.extended(onPressed:newProduct,icon:const Icon(Icons.add),label:const Text('प्रोडक्ट')):
        tab==2?FloatingActionButton.extended(onPressed:newSale,icon:const Icon(Icons.add),label:const Text('बिक्री')):
        tab==3?FloatingActionButton.extended(onPressed:newKhata,icon:const Icon(Icons.add),label:const Text('एंट्री')):null,
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
        NavigationDestination(icon:Icon(Icons.grid_view_rounded),label:'होम'),
        NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'स्टॉक'),
        NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'बिक्री'),
        NavigationDestination(icon:Icon(Icons.menu_book),label:'खाता'),
        NavigationDestination(icon:Icon(Icons.person_outline),label:'प्रोफाइल')]));
  }
}

class Dashboard extends StatelessWidget {
 final double cash,expenses; final List<Map<String,dynamic>> sales,khata; final VoidCallback onSale,onExpense,onKhata;
 const Dashboard({super.key,required this.cash,required this.expenses,required this.sales,required this.khata,required this.onSale,required this.onExpense,required this.onKhata});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
  Container(padding:const EdgeInsets.all(19),decoration:BoxDecoration(gradient:const LinearGradient(colors:[navy,Color(0xFF29466F)]),borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('GOOD AFTERNOON',style:TextStyle(color:Colors.white70,fontSize:10,letterSpacing:1.3)),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(20)),child:const Text('RETAILER DEMO',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.bold)))]),
   const SizedBox(height:15),const Text('आज का कारोबार',style:TextStyle(color:Colors.white70)),Text('₹'+(cash+expenses).toStringAsFixed(0),style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w900)),
   const SizedBox(height:18),Row(children:[Expanded(child:_metric('बिक्री','₹'+_salesTotal(sales),Icons.trending_up)),Container(width:1,height:38,color:Colors.white24),Expanded(child:_metric('खर्च','₹'+expenses.toStringAsFixed(0),Icons.payments_outlined))]) ])),
  const SizedBox(height:20),const Text('त्वरित काम',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:navy)),const SizedBox(height:10),
  Row(children:[Expanded(child:_quick('नई बिक्री',Icons.point_of_sale,orange,onSale)),const SizedBox(width:9),Expanded(child:_quick('खर्च जोड़ें',Icons.add_card,green,onExpense)),const SizedBox(width:9),Expanded(child:_quick('खाता एंट्री',Icons.menu_book,navy,onKhata))]),
  const SizedBox(height:20),const Text('बिजनेस सारांश',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:navy)),const SizedBox(height:10),
  Row(children:[Expanded(child:_stat('कैश / बैंक','₹'+cash.toStringAsFixed(0),Icons.account_balance_wallet,green)),const SizedBox(width:9),Expanded(child:_stat('कुल खर्च','₹'+expenses.toStringAsFixed(0),Icons.receipt,red))]),
  const SizedBox(height:9),Row(children:[Expanded(child:_stat('कुल खाता',khata.length.toString()+' एंट्री',Icons.people,navy)),const SizedBox(width:9),Expanded(child:_stat('बिक्री बिल',sales.length.toString()+' बिल',Icons.shopping_bag,orange))]),
  const SizedBox(height:20),const Text('हाल की बिक्री',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:navy)),
  ...sales.take(3).map((e)=>_row(e['name'],e['detail'],'₹'+(e['amount'] as double).toStringAsFixed(0),Icons.receipt_long,green)),
  const SizedBox(height:18),const Text('Bharat Saathi • सरल हिसाब, बेहतर कारोबार',textAlign:TextAlign.center,style:TextStyle(color:Colors.black45,fontSize:11))]);
}
String _salesTotal(List<Map<String,dynamic>> rows)=>rows.fold<double>(0,(p,e)=>p+(e['amount'] as double)).toStringAsFixed(0);
Widget _metric(String label,String value,IconData icon)=>Row(children:[Icon(icon,color:orange),const SizedBox(width:8),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:Colors.white70,fontSize:11)),Text(value,style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.bold))])]);
Widget _quick(String label,IconData icon,Color color,VoidCallback action)=>InkWell(onTap:action,borderRadius:BorderRadius.circular(15),child:Container(padding:const EdgeInsets.symmetric(vertical:15,horizontal:4),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Column(children:[CircleAvatar(backgroundColor:color.withOpacity(.12),child:Icon(icon,color:color)),const SizedBox(height:8),Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700),textAlign:TextAlign.center)])));
Widget _stat(String label,String value,IconData icon,Color color)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15)),child:Row(children:[CircleAvatar(radius:17,backgroundColor:color.withOpacity(.1),child:Icon(icon,color:color,size:18)),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:10,color:Colors.black54)),Text(value,style:const TextStyle(fontWeight:FontWeight.w800,color:navy,fontSize:14),overflow:TextOverflow.ellipsis)]))]));
Widget _row(String title,String subtitle,String amount,IconData icon,Color color)=>Container(margin:const EdgeInsets.only(top:8),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:Row(children:[CircleAvatar(backgroundColor:color.withOpacity(.1),child:Icon(icon,color:color,size:19)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),Text(subtitle,style:const TextStyle(color:Colors.black54,fontSize:10))])),Text(amount,style:TextStyle(color:color,fontWeight:FontWeight.w800))]));
Widget _heading(String title,String subtitle)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:navy)),Text(subtitle,style:const TextStyle(color:Colors.black54,fontSize:12))]);
class ProductScreen extends StatelessWidget{final List<String> products;final List<int> stock;const ProductScreen({super.key,required this.products,required this.stock});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[_heading('प्रोडक्ट और स्टॉक','सामान और उपलब्ध मात्रा'),const SizedBox(height:12),...List.generate(products.length,(i)=>_row(products[i],'SKU-'+(1001+i).toString(),' '+stock[i].toString()+' यूनिट',Icons.inventory_2,stock[i]<15?red:green)),const SizedBox(height:70)]);}
class SalesScreen extends StatelessWidget{final List<Map<String,dynamic>> sales;const SalesScreen({super.key,required this.sales});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[_heading('बिक्री और बिल','बिक्री का रिकॉर्ड'),const SizedBox(height:12),...sales.map((e)=>_row(e['name'],e['detail'],'₹'+(e['amount'] as double).toStringAsFixed(0),Icons.receipt_long,green)),const SizedBox(height:70)]);}
class KhataScreen extends StatelessWidget{final List<Map<String,dynamic>> entries;const KhataScreen({super.key,required this.entries});@override Widget build(BuildContext context){final due=entries.fold<double>(0,(p,e)=>p+(e['amount'] as double));return ListView(padding:const EdgeInsets.all(16),children:[_heading('ग्राहक खाता','उधार और भुगतान का हिसाब'),const SizedBox(height:12),Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('कुल बकाया (डेमो)',style:TextStyle(color:Colors.white70)),Text('₹'+due.toStringAsFixed(0),style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.w900))])),...entries.map((e)=>_row(e['name'],e['detail'],(e['amount'] as double)<0?'- ₹'+(e['amount'] as double).abs().toStringAsFixed(0):'+ ₹'+(e['amount'] as double).toStringAsFixed(0),Icons.person,(e['amount'] as double)<0?green:red)),const SizedBox(height:70)]);}}
class ProfileScreen extends StatelessWidget{const ProfileScreen({super.key});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[_heading('प्रोफाइल और सेटिंग','Bharat Saathi अकाउंट'),const SizedBox(height:20),const CircleAvatar(radius:35,backgroundColor:navy,child:Icon(Icons.storefront,color:orange,size:32)),const SizedBox(height:10),const Center(child:Text('मेरा रिटेल स्टोर',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18))),const Center(child:Text('डेमो अकाउंट • अभी लॉगिन नहीं',style:TextStyle(color:Colors.black54,fontSize:12))),const SizedBox(height:20),_row('अकाउंट और सुरक्षा','लॉगिन सेटअप अगला चरण','›',Icons.lock_outline,navy),_row('डेटा बैकअप','क्लाउड सिंक कनेक्शन बाकी','›',Icons.cloud_upload_outlined,green),_row('भाषा','हिन्दी','›',Icons.language,navy),_row('सहायता','सपोर्ट और संपर्क','›',Icons.help_outline,navy),const SizedBox(height:20),const Text('Version 0.1.0 • Prototype',textAlign:TextAlign.center,style:TextStyle(color:Colors.black45,fontSize:11))]);}
