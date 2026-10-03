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
  void _load() {
    final repository = context.read<AdminRepository>();
    _future = repository.listDisputes();
    repository.getPanelAccess().then((access) {
      if (!mounted) return;
      _permissions = (access['permissions'] is List) ? (access['permissions'] as List).whereType<String>().toSet() : <String>{};
      setState(() {});
    }).catchError((_) {});
    if (mounted) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        body: PremiumPageFrame(
          maxWidth: 1200,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 48),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  children: [
                    PremiumHeader(
                      domain: HopeProductDomain.control,
                      eyebrow: _t('کنترل اختلاف', 'DISPUTE CONTROL'),
                      title: _t('پرونده‌های اختلاف', 'Dispute cases'),
                      subtitle: _t(
                        'وضعیت و شواهد پرونده‌های نیازمند رسیدگی.',
                        'Status and evidence for cases that require review.',
                      ),
                      trailing: PremiumIconButton(
                        icon: HopeV2Icons.refresh,
                        tooltip: _t('بازخوانی', 'Refresh'),
                        onPressed: _load,
                      ),
                    ),
                    const SizedBox(height: 18),
                    EmptyState(
                      icon: HopeV2Icons.error,
                      title: _t('بارگذاری پرونده‌ها ناموفق بود', 'Could not load dispute cases'),
                      message: apiErrorMessage(snapshot.error ?? Object()),
                      action: FilledButton(
                        onPressed: _load,
                        child: Text(_t('تلاش دوباره', 'Retry')),
                      ),
                    ),
                  ],
                );
              }
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              return RefreshIndicator(
                onRefresh: () async => _load(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    PremiumHeader(
                      domain: HopeProductDomain.control,
                      eyebrow: _t('کنترل اختلاف', 'DISPUTE CONTROL'),
                      title: _t('پرونده‌های اختلاف همکاری', 'Work dispute cases'),
                      subtitle: _t(
                        'گزارش AI، مبنای حقوقی، شواهد و اقدام مجاز ادمین را جدا از سایر عملیات کنترل کنید.',
                        'Review AI findings, legal basis, evidence, and permitted admin actions as a dedicated operational surface.',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          PremiumIconButton(
                            icon: isEn ? HopeV2Icons.arrowLeft : HopeV2Icons.arrowRight,
                            tooltip: _t('بازگشت', 'Back'),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                          PremiumIconButton(
                            icon: HopeV2Icons.refresh,
                            tooltip: _t('بازخوانی', 'Refresh'),
                            onPressed: _busy ? null : _load,
                          ),
                          const HopeIconTile(
                            HopeV2Icons.secure,
                            size: 50,
                            filled: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (rows.isEmpty)
                      EmptyState(
                        icon: HopeV2Icons.completed,
                        title: _t('پرونده‌ای نیازمند رسیدگی نیست', 'No dispute cases need attention'),
                        message: _t(
                          'در حال حاضر پروندهٔ فعالی برای بررسی وجود ندارد.',
                          'There are no active dispute cases to review.',
                        ),
                      )
                    else
                      ...rows.map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _open(row),
                            borderRadius: BorderRadius.circular(HopeV2Radii.lg),
                            child: PremiumPanel(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const HopeIconTile(
                                        Icons.gavel_outlined,
                                        size: 44,
                                        filled: true,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${row['jobTitle'] ?? _t('اختلاف همکاری', 'Work dispute')}',
                                              style: HopeV2Type.section(context),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${row['workerName'] ?? '—'} • ${row['ownerName'] ?? '—'}',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusPill(
                                        '${row['aiDecision'] ?? 'HOLD'}',
                                        color: _decisionColor('${row['aiDecision'] ?? 'HOLD'}'),
                                        icon: _decisionIcon('${row['aiDecision'] ?? 'HOLD'}'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _caseMeta(
                                          context,
                                          HopeV2Icons.secure,
                                          _t('وضعیت پرونده', 'Case status'),
                                          '${row['status'] ?? '—'}',
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _caseMeta(
                                          context,
                                          HopeV2Icons.payments,
                                          _t('وضعیت پرداخت', 'Payment'),
                                          '${row['paymentStatus'] ?? '—'}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _decisionColor(String value) {
    switch (value.trim().toUpperCase()) {
      case 'RELEASE':
        return HopeV2Colors.success;
      case 'REFUND':
        return HopeV2Colors.warning;
      default:
        return HopeV2Colors.danger;
    }
  }

  Object _decisionIcon(String value) {
    switch (value.trim().toUpperCase()) {
      case 'RELEASE':
        return HopeV2Icons.completed;
      case 'REFUND':
        return HopeV2Icons.transferOut;
      default:
        return HopeV2Icons.pending;
    }
  }

  Widget _caseMeta(
    BuildContext context,
    Object icon,
    String label,
    String value,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: HopeV2Surfaces.panelSoft(context),
        borderRadius: BorderRadius.circular(HopeV2Radii.md),
        border: Border.all(color: HopeV2Surfaces.border(context)),
      ),
      child: Row(
        children: [
          HopeIcon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
