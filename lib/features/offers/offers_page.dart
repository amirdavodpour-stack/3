import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/marketplace/application.dart';
import '../../core/marketplace/offer_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../../core/theme/app_theme.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key, this.jobId});
  final String? jobId;
  @override State<OffersPage> createState()=>_OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  late Future<List<HopeOffer>> _future;
  String _filter='ALL';

  @override void initState(){super.initState(); _reload();}
  void _reload(){ final r=context.read<OfferRepository>(); _future=widget.jobId==null?r.listMine():r.listForJob(widget.jobId!); if(mounted)setState((){}); }
  String _t(String fa,String en)=>Localizations.localeOf(context).languageCode=='en'?en:fa;

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title:Text(widget.jobId==null?_t('پیشنهادهای من','My offers'):_t('پیشنهادهای این فرصت','Job offers')),
        actions:[IconButton(onPressed:_reload,icon:const Icon(Icons.refresh_rounded),tooltip:_t('بازخوانی','Refresh'))],
      ),
      body:FutureBuilder<List<HopeOffer>>(future:_future,builder:(context,s){
        if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
        if(s.hasError) {
          return Center(child:Padding(padding:const EdgeInsets.all(24),child:EmptyState(
          icon:Icons.cloud_off_rounded,title:_t('پیشنهادها در دسترس نیستند','Offers unavailable'),
          message:apiErrorMessage(s.error ?? Object()),action:FilledButton(onPressed:_reload,child:Text(_t('تلاش دوباره','Retry'))))));
        }
        final all=s.data??const <HopeOffer>[];
        final rows=_filter=='ALL'?all:all.where((x)=>x.status==_filter).toList();
        return RefreshIndicator(onRefresh:()async=>_reload(),child:ListView(
          padding:const EdgeInsets.fromLTRB(18,16,18,110),
          children:[
            PremiumPanel(padding:const EdgeInsets.all(16),highlight:true,child:Row(children:[
              const HopeIconTile(Icons.local_offer_outlined,filled:true,size:46),const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(_t('مرکز پیشنهادها','Offer center'),style:Theme.of(context).textTheme.titleLarge),
                const SizedBox(height:4),Text(_t('پیشنهادها را ببینید و در صورت مجاز بودن، همان‌جا اقدام کنید.','Review offers and take the allowed action in context.'))
              ]))
            ])),
            const SizedBox(height:12),
            SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
              for(final x in const ['ALL','PENDING','ACCEPTED','REJECTED'])
                Padding(padding:const EdgeInsetsDirectional.only(end:8),child:ChoiceChip(
                  label:Text(x=='ALL'?_t('همه','All'):x),selected:_filter==x,onSelected:(_)=>setState(()=>_filter=x)))
            ])),
            const SizedBox(height:12),
            if(rows.isEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:55),child:EmptyState(
              icon:Icons.inbox_outlined,title:_t('پیشنهادی وجود ندارد','No offers'),message:_t('در این وضعیت پیشنهادی برای نمایش وجود ندارد.','There are no offers in this state.')))
            else ...rows.map(_card),
          ],
        ));
      }),
    );
  }

  Widget _card(HopeOffer o)=>Padding(
    padding:const EdgeInsets.only(bottom:10),
    child:Semantics(
      button:true,
      label:_t('جزئیات پیشنهاد ${o.id}','Offer ${o.id} details'),
      child:InkWell(
        borderRadius:BorderRadius.circular(18),
        onTap:()=>_showDetails(o),
        child:PremiumPanel(
          padding:const EdgeInsets.all(15),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              const HopeIconTile(Icons.sell_outlined,filled:true),
              const SizedBox(width:10),
              Expanded(child:Text('${_t('مبلغ','Amount')}: ${o.price}',style:Theme.of(context).textTheme.titleMedium)),
              StatusPill(o.status,color:o.isPending?AppColors.warning:Theme.of(context).colorScheme.primary),
            ]),
            if(o.message.trim().isNotEmpty)Padding(padding:const EdgeInsets.only(top:10),child:Text(o.message,maxLines:3,overflow:TextOverflow.ellipsis)),
            const SizedBox(height:8),
            Text('${_t('شناسه فرصت','Job')}: ${o.jobId}',style:Theme.of(context).textTheme.bodySmall),
            if(o.createdAt!=null)Text('${_t('ایجاد','Created')}: ${o.createdAt}',style:Theme.of(context).textTheme.bodySmall),
            if(widget.jobId!=null && o.isPending)Padding(
              padding:const EdgeInsets.only(top:12),
              child:FilledButton.icon(
                onPressed:()=>_accept(o),
                icon:const Icon(Icons.check_rounded),
                label:Text(_t('پذیرش پیشنهاد','Accept offer')),
              ),
            ),
            const SizedBox(height:4),
            Align(
              alignment:AlignmentDirectional.centerEnd,
              child:Text(_t('برای جزئیات لمس کنید','Tap for details'),style:Theme.of(context).textTheme.labelMedium),
            ),
          ]),
        ),
      ),
    ),
  );

  Future<void> _showDetails(HopeOffer summary) async {
    try {
      final detail = await context.read<OfferRepository>().get(summary.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_t('جزئیات پیشنهاد','Offer details'), style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(_t('مبلغ','Amount')),
                  subtitle: Text(detail.price),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(_t('وضعیت','Status')),
                  subtitle: Text(detail.status),
                ),
                if (detail.message.trim().isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notes_outlined),
                    title: Text(_t('پیام','Message')),
                    subtitle: Text(detail.message),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.work_outline_rounded),
                  title: Text(_t('فرصت','Opportunity')),
                  subtitle: Text(detail.jobId),
                ),
                if (detail.createdAt != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(_t('ایجاد شده','Created')),
                    subtitle: Text(detail.createdAt!),
                  ),
                if (widget.jobId != null && detail.isPending)
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _accept(detail);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(_t('پذیرش پیشنهاد','Accept offer')),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> _accept(HopeOffer o)async{
    final repository = context.read<OfferRepository>();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(_t('پذیرش پیشنهاد؟','Accept this offer?')),
      content:Text(_t('پذیرش پیشنهاد یک اقدام مالی/قراردادی است. قبل از تأیید مبلغ و شرایط را بررسی کنید.','Accepting an offer is a contractual/financial action. Review the amount and terms before confirming.')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(_t('لغو','Cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(_t('تأیید','Confirm')))]
    ));
    if(ok!=true)return;
    if (!mounted) return;
    try{await repository.accept(o.id);if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_t('پیشنهاد پذیرفته شد','Offer accepted'))));_reload();}}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(apiErrorMessage(e))));}
  }
}
