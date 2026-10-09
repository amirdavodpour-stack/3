import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/jobs/job_satisfaction_repository.dart';
import '../../core/ui/components.dart';
import '../../core/ui/hope_async_state.dart';
import '../../core/ui/premium_components.dart';
import '../../core/theme/hope_v2_design.dart';

class JobSatisfactionPage extends StatefulWidget {
  const JobSatisfactionPage({super.key, required this.jobId});
  final String jobId;

  @override
  State<JobSatisfactionPage> createState() => _JobSatisfactionPageState();
}

class _JobSatisfactionPageState extends State<JobSatisfactionPage> {
  late Future<JobSatisfactionState> _future;
  int _overallRating = 5;
  int _communicationRating = 5;
  bool _completedAsAgreed = true;
  final _report = TextEditingController();
  bool _busy = false;

  bool get _en => Localizations.localeOf(context).languageCode == 'en';
  String _t(String fa, String en) => _en ? en : fa;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _report.dispose();
    super.dispose();
  }

  Future<JobSatisfactionState> _load() =>
      context.read<JobSatisfactionRepository>().getState(widget.jobId);

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await context.read<JobSatisfactionRepository>().submit(
        jobId: widget.jobId,
        overallRating: _overallRating,
        completedAsAgreed: _completedAsAgreed,
        communicationRating: _communicationRating,
        report: _report.text,
      );
      if (!mounted) return;
      final rawSettlement = result['settlement'];
      final settlement = rawSettlement is Map
          ? Map<String, dynamic>.from(rawSettlement)
          : const <String, dynamic>{};
      final released = settlement['autoReleased'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            released
                ? _t(
                    'پس از تأیید رضایت هر دو طرف، پرداخت تسویه شد.',
                    'Payment was settled after both sides confirmed satisfaction.',
                  )
                : _t(
                    'گزارش رضایت ثبت شد؛ گزارش طرف مقابل نیز برای ادامه فرایند لازم است.',
                    'Satisfaction was recorded; the other side must complete its report to continue the flow.',
                  ),
          ),
        ),
      );
      setState(() => _future = _load());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            'ثبت گزارش انجام نشد.',
            'Could not submit the report.',
          )),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: PremiumPageFrame(
            maxWidth: 820,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumHeader(
                  page: HopePageId.satisfaction,
                  domain: HopeProductDomain.trust,
                  eyebrow: _t('اعتماد', 'TRUST'),
                  title: _t('گزارش رضایت همکاری', 'Work satisfaction report'),
                  subtitle: _t(
                    'رضایت، کیفیت اجرا و ارتباط این همکاری را ثبت کنید تا چرخه کار کامل شود.',
                    'Record satisfaction, execution quality, and communication so this collaboration can close cleanly.',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PremiumIconButton(
                        icon: _en
                            ? HopeV2Icons.arrowLeft
                            : HopeV2Icons.arrowRight,
                        tooltip: _t('بازگشت', 'Back'),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: 8),
                      const HopeIconTile(
                        HopeV2Icons.completed,
                        size: 52,
                        filled: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: HopeV2Spacing.lg),
                Expanded(
                  child: FutureBuilder<JobSatisfactionState>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HopeAsyncState(
                kind: HopeStateKind.loading,
                title: _t(
                  'در حال آماده‌سازی گزارش',
                  'Preparing report',
                ),
                message: _t(
                  'فرم محدود رضایت این همکاری در حال بارگذاری است.',
                  'The scoped satisfaction form is loading.',
                ),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return HopeAsyncState(
                kind: HopeStateKind.error,
                title: _t(
                  'گزارش رضایت در دسترس نیست',
                  'Satisfaction report unavailable',
                ),
                message: _t(
                  'اطلاعات اعتماد این همکاری فعلاً قابل دریافت نیست.',
                  'Trust information for this collaboration is temporarily unavailable.',
                ),
                action: OutlinedButton.icon(
                  onPressed: () => setState(() => _future = _load()),
                  icon: const HopeIcon(HopeV2Icons.refresh, size: 19),
                  label: Text(_t('تلاش دوباره', 'Try again')),
                ),
              );
            }

            final state = snapshot.data!;
            if (state.submitted && state.feedback != null) {
              final feedback = state.feedback!;
              final dispute = state.dispute;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  PremiumPanel(
                    highlight: true,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('گزارش ثبت شده', 'Report submitted'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(_t(
                          'امتیاز رضایت هوشمند',
                          'AI satisfaction score',
                        )),
                        const SizedBox(height: 3),
                        Text(
                          '${feedback.aiSatisfactionScore}%',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        if (feedback.aiSummary.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(feedback.aiSummary),
                        ],
                        const SizedBox(height: 10),
                        Text(_t(
                          'این نتیجه در سابقه این همکاری و پروفایل عملکردی شما ثبت شده است.',
                          'This result is stored in the collaboration and performance history.',
                        )),
                      ],
                    ),
                  ),
                  if (dispute != null) ...[
                    const SizedBox(height: 12),
                    PremiumPanel(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('پرونده اختلاف ایجاد شد', 'Dispute case opened'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text(_t(
                            'به دلیل اختلاف در گزارش‌های دو طرف، پرداخت تا تعیین تکلیف متوقف می‌ماند. ارزیابی AI داخلی به همراه مبنای حقوقی برای ادمین ارسال شده است.',
                            'Because the two reports conflict, payment remains on hold until it is resolved. The internal AI assessment and legal basis have been sent to the administrator.',
                          )),
                          if ('${dispute['aiDecision'] ?? ''}'.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('${_t('تصمیم پیشنهادی AI: ', 'AI suggested action: ')}${dispute['aiDecision'] ?? 'HOLD'}'),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 64),
              children: [
                PremiumPanel(
                  glass: true,
                  padding: const EdgeInsets.all(18),
                  child: Text(_t(
                    'این فرم فقط برای همین همکاری است. هیچ چت عمومی یا درخواست آزاد از هوش مصنوعی در اختیار شما نیست.',
                    'This form is scoped to this work only. There is no general AI chat or free-form AI request.',
                  )),
                ),
                const SizedBox(height: 14),
                _RatingField(
                  label: _t('رضایت کلی', 'Overall satisfaction'),
                  value: _overallRating,
                  onChanged: (value) => setState(() => _overallRating = value),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  title: Text(_t(
                    'کار مطابق توافق انجام شد',
                    'Work was completed as agreed',
                  )),
                  value: _completedAsAgreed,
                  onChanged: (value) =>
                      setState(() => _completedAsAgreed = value),
                ),
                const SizedBox(height: 8),
                _RatingField(
                  label: _t(
                    'ارتباط و هماهنگی',
                    'Communication and coordination',
                  ),
                  value: _communicationRating,
                  onChanged: (value) =>
                      setState(() => _communicationRating = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _report,
                  maxLength: 2000,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: _t('گزارش کوتاه', 'Short report'),
                    hintText: _t(
                      'نتیجه همکاری، کیفیت و نکته مهمی که باید در سابقه بماند.',
                      'Outcome, quality, and anything important to retain in the history.',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const HopeIcon(
                          HopeV2Icons.completed,
                          size: 19,
                        ),
                  label: Text(
                    _busy
                        ? _t('در حال ثبت...', 'Submitting...')
                        : _t('ثبت گزارش', 'Submit report'),
                  ),
                ),
              ],
            );
          },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _RatingField extends StatelessWidget {
  const _RatingField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => PremiumPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 9),
            SegmentedButton<int>(
              segments: List.generate(
                5,
                (index) {
                  final number = index + 1;
                  return ButtonSegment<int>(
                    value: number,
                    label: Text(number.toString()),
                  );
                },
              ),
              selected: <int>{value},
              onSelectionChanged: (selected) =>
                  onChanged(selected.first),
            ),
          ],
        ),
      );
}
