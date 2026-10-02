import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_error_presenter.dart';
import '../../core/recommendation/recommendation_profile_repository.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/hope_feedback.dart';
import '../../core/ui/premium_components.dart';

class RecommendationOnboardingPage extends StatefulWidget {
  const RecommendationOnboardingPage({super.key});
  @override
  State<RecommendationOnboardingPage> createState() => _RecommendationOnboardingPageState();
}

class _RecommendationOnboardingPageState extends State<RecommendationOnboardingPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _messages = [];
  HopeRecommendationProfile _profile = const HopeRecommendationProfile();
  bool _loading = true;
  bool _sending = false;
  bool _saving = false;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    _startInterview();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _startInterview() async {
    try {
      final response = await context.read<RecommendationProfileRepository>().interview(history: const [], message: '');
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'assistant', 'content': response.reply});
        _profile = _merge(_profile, response.profilePatch);
        _complete = response.complete;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      HopeFeedback.show(context, apiErrorMessage(error, fallback: 'مصاحبه هوشمند موقتاً در دسترس نیست.'), tone: HopeFeedbackTone.error);
    }
  }

  HopeRecommendationProfile _merge(HopeRecommendationProfile base, HopeRecommendationProfile patch) {
    List<String> mergeList(List<String> a, List<String> b) => [
      ...{...a, ...b},
    ];
    return HopeRecommendationProfile(
      resumeText: patch.resumeText.isNotEmpty ? patch.resumeText : base.resumeText,
      skills: mergeList(base.skills, patch.skills),
      interests: mergeList(base.interests, patch.interests),
      preferredCategories: mergeList(base.preferredCategories, patch.preferredCategories),
      preferredCities: mergeList(base.preferredCities, patch.preferredCities),
      desiredKinds: mergeList(base.desiredKinds, patch.desiredKinds),
      workMode: patch.workMode ?? base.workMode,
      availability: patch.availability ?? base.availability,
      salaryMin: patch.salaryMin ?? base.salaryMin,
      salaryMax: patch.salaryMax ?? base.salaryMax,
      experienceLevel: patch.experienceLevel ?? base.experienceLevel,
      goals: patch.goals.isNotEmpty ? patch.goals : base.goals,
      onboardingCompleted: true,
    );
  }

  Future<void> _send() async {
    final message = _input.text.trim();
    if (message.isEmpty || _sending || _saving) return;
    _input.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': message});
      _sending = true;
    });
    _jumpToEnd();
    try {
      final response = await context.read<RecommendationProfileRepository>().interview(
        history: List<Map<String, String>>.from(_messages),
        message: message,
      );
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'assistant', 'content': response.reply});
        _profile = _merge(_profile, response.profilePatch);
        _complete = response.complete;
      });
      _jumpToEnd();
      if (response.complete) await _save();
    } catch (error) {
      if (mounted) HopeFeedback.show(context, apiErrorMessage(error, fallback: 'پاسخ هوش مصنوعی دریافت نشد.'), tone: HopeFeedbackTone.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<RecommendationProfileRepository>().save(_profile);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) HopeFeedback.show(context, apiErrorMessage(error, fallback: 'پروفایل ذخیره نشد.'), tone: HopeFeedbackTone.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEn ? 'HOPE AI work profile' : 'پروفایل کاری با هوش مصنوعی'),
          actions: [
            IconButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
              tooltip: isEn ? 'Skip' : 'بعداً',
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PremiumHero(
                        eyebrow: 'HOPE AI',
                        title: isEn ? 'Let HOPE learn your work preferences' : 'بگذارید HOPE سلیقه کاری شما را بشناسد',
                        message: isEn ? 'One question at a time. Your answers shape future opportunity recommendations.' : 'هر بار یک سؤال کوتاه؛ پاسخ‌های شما پایه پیشنهادهای شغلی بعدی می‌شوند.',
                        icon: Icons.auto_awesome,
                        height: 210,
                      ),
                    );
                  }
                  final item = _messages[index - 1];
                  final user = item['role'] == 'user';
                  return Align(
                    alignment: user ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 680),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: user ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(HopeV2Radii.md),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Text(item['content'] ?? ''),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !_loading && !_sending && !_saving && !_complete,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: isEn ? 'Write your answer…' : 'پاسخ خود را بنویسید…',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(HopeV2Radii.md)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: (_loading || _sending || _saving || _complete) ? null : _send,
                      icon: _sending || _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_upward),
                      tooltip: isEn ? 'Send' : 'ارسال',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}