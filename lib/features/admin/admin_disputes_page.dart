import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin/admin_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';

class AdminDisputesPage extends StatefulWidget {
  const AdminDisputesPage({super.key});
  @override State<AdminDisputesPage> createState() => _AdminDisputesPageState();
}

class _AdminDisputesPageState extends State<AdminDisputesPage> {
  late Future<List<Map<String,dynamic>>> _future;
  bool _busy = false;
  Set<String> _permissions = <String>{};
  bool _hasPermission(String permission) => _permissions.contains(permission);

  @override void initState() { super.initState(); _load(); }
  String _t(String fa, String en) => Localizations.localeOf(context).languageCode == 'en' ? en : fa;
  void _load() async {
    try {
      final access = await context.read<AdminRepository>().getPanelAccess();
      if (!mounted) return;
      _permissions = (access['permissions'] is List) ? (access['permissions'] as List).whereType<String>().toSet() : <String>{};
      _future = context.read<AdminRepository>().listDisputes();
      setState(() {});
    } catch (_) {
      _future = Future<List<Map<String,dynamic>>>.error(Object());
      if (mounted) setState(() {});
    }
  }

  Future<void> _open(Map<String,dynamic> row) async {
    final id='${row['id']??''}'; if(id.isEmpty) return;
    try {
      final detail=await context.read<AdminRepository>().getDispute(id);
      if(!mounted) return;
      await showModalBottomSheet<void>(context: context, isScrollControlled:true, showDragHandle:true, builder: (_) => _detail(detail));
      _load();
    } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(apiErrorMessage(e)))); }
  }

  Widget _detail(Map<String,dynamic> d) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20,10,20,28), child: SingleChildScrollView(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
    Text('${d['jobTitle']??_t('اختلاف همکاری','Work dispute')}', style:Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height:8),
    Text(_t('ارزیابی داخلی اختلاف — رأی قضایی یا رأی داوری الزام‌آور نیست.', 'Internal dispute assessment — not a court judgment or binding arbitral award.'), style:Theme.of(context).textTheme.bodySmall),
    const SizedBox(height:16),
    _kv(_t('وضعیت AI','AI status'),'${d['status']??'—'}'),
    _kv(_t('تصمیم AI','AI decision'),'${d['aiDecision']??'HOLD'}'),
    _kv(_t('اطمینان','Confidence'),'${d['aiConfidence']??'—'}'),
    _kv(_t('نسخه قواعد حقوقی','Legal ruleset'),'${d['legalRulesetVersion']??'—'}'),
    _kv(_t('فرصت','Opportunity'),'${d['jobStatus']??'—'}'),
    _kv(_t('کارفرما','Employer'),'${d['owner']?['name']??d['ownerName']??'—'}'),
    _kv(_t('کارگر','Worker'),'${d['worker']?['name']??d['workerName']??'—'}'),
    _kv(_t('وضعیت پرداخت','Payment status'),'${d['paymentStatus']??d['context']?['payment']?['status']??'—'}'),
    _kv(_t('مبلغ','Amount'),'${d['paymentAmount']??d['context']?['payment']?['amount']??'—'} تومان'),
    _section(_t('گزارش','Report'), '${d['aiReport']?['summary']??''}'),
    _section(_t('مبنای پرداخت','Payment rationale'), '${d['aiReport']?['paymentRationale']??''}'),
    _section(_t('یافته‌های واقعی','Factual findings'), '${(d['aiReport']?['factualFindings'] as List? ?? const []).join('\n• ')}'),
    _section(_t('مدارک ناقص','Missing evidence'), '${(d['aiReport']?['missingEvidence'] as List? ?? const []).join('\n• ')}'),
    _section(_t('مبنای حقوقی','Legal basis'), '${(d['aiReport']?['legalBasis'] as List? ?? const []).map((x)=>'${x['source']} ماده ${x['article']}: ${x['principle']}').join('\n')}'),
    _section(_t('اقدامات پیشنهادی سیستم','System-suggested admin actions'), '${(d['aiReport']?['adminActions'] as List? ?? const []).join('\n• ')}'),
    _section(_t('شواهد ثبت‌شده','Recorded evidence'), '${(d['context']?['evidence'] as List? ?? const []).map((x)=>'${x['action'] ?? '—'} • ${x['createdAt'] ?? '—'}').join('\n')}'),
    const SizedBox(height:10),
    Wrap(spacing:8, runSpacing:8, children:[
      _action(d,'RELEASE',_t('پرداخت','Release'),Icons.payments),
      _action(d,'REFUND',_t('بازپرداخت','Refund'),Icons.undo),
      _action(d,'HOLD',_t('نگه‌داشتن','Hold'),Icons.pause_circle_outline),
    ])
  ]))));

  Widget _kv(String a,String b)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Text('$a: $b',style:const TextStyle(fontWeight:FontWeight.w700)));
  Widget _section(String title,String body)=>Padding(padding:const EdgeInsets.only(top:10),child:PremiumPanel(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(body.isEmpty?'—':body)])));
  Widget _action(Map<String,dynamic> d,String resolution,String label,IconData icon)=>OutlinedButton.icon(onPressed:_busy||!_hasPermission('admin.resolve_disputes')||'${d['status']??''}'=='RESOLVED'?null:()=>_resolve(d,resolution,label),icon:Icon(icon),label:Text(label));

  Future<void> _resolve(Map<String,dynamic> d,String resolution,String label) async {
    final id='${d['id']??''}';
    final reasonController=TextEditingController();
    try {
      final ok=await showDialog<bool>(context:context,builder:(dialogContext)=>AlertDialog(title:Text(_t('تأیید اقدام','Confirm action')),content:Column(mainAxisSize:MainAxisSize.min,children:[Text(_t('اقدام انتخابی: $label. دلیل ادمین را ثبت کنید.','Selected action: $label. Record the admin reason.')),const SizedBox(height:10),TextField(controller:reasonController,maxLines:4,decoration:InputDecoration(labelText:_t('دلیل','Reason')))]),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:Text(_t('انصراف','Cancel'))),FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:Text(_t('اجرا','Execute')))]));
      if(ok!=true) return;
      setState(()=>_busy=true);
      await context.read<AdminRepository>().resolveDispute(id,resolution:resolution,reason:reasonController.text);
      if(mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_t('اقدام ثبت شد.','Action recorded.')))); _load(); }
    } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(apiErrorMessage(e)))); } finally { reasonController.dispose(); if(mounted) setState(()=>_busy=false); }
  }

  @override Widget build(BuildContext context)=>Directionality(textDirection:Localizations.localeOf(context).languageCode=='en'?TextDirection.ltr:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:Text(_t('اختلاف‌ها و داوری عملیاتی','Disputes & adjudication'))),body:PremiumPageFrame(maxWidth:1200,padding:const EdgeInsets.all(18),child:FutureBuilder<List<Map<String,dynamic>>>(future:_future,builder:(context,s)=>s.connectionState==ConnectionState.waiting?const Center(child:CircularProgressIndicator()):s.hasError?Center(child:Text(apiErrorMessage(s.error??Object()))):RefreshIndicator(onRefresh:()async=>_load(),child:ListView(children:[
    PremiumHeader(eyebrow:_t('کنترل اختلاف','Dispute control'),title:_t('پرونده‌های اختلاف همکاری','Work dispute cases'),subtitle:_t('گزارش AI، مبنای حقوقی، شواهد ناقص و اقدامات مجاز ادمین در یک سطح.', 'AI report, legal basis, missing evidence and permitted admin actions in one surface.'),trailing:const HopeIconTile(HopeV2Icons.secure,size:50,filled:true)),
    const SizedBox(height:14),
    if((s.data??const[]).isEmpty) const EmptyState(icon:HopeV2Icons.pending,title:'No dispute cases',message:'No dispute cases require attention yet.') else ...s.data!.map((row)=>InkWell(onTap:()=>_open(row),child:Padding(padding:const EdgeInsets.only(bottom:10),child:PremiumPanel(padding:const EdgeInsets.all(14),child:Row(children:[const HopeIconTile(Icons.gavel,size:42,filled:true),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${row['jobTitle']??'—'}',style:Theme.of(context).textTheme.titleMedium),Text('${row['workerName']??'—'} • ${row['ownerName']??'—'}',style:Theme.of(context).textTheme.bodySmall)])),Text('${row['aiDecision']??'HOLD'}')]))))),
  ]))))));
