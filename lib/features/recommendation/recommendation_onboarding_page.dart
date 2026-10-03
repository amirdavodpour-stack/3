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
        history: _messages.length <= 1
            ? const []
            : _messages.sublist(0, _messages.length - 1).cast<Map<String, String>>(),
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
        body: SafeArea(
          child: PremiumPageFrame(
            maxWidth: 820,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                PremiumHeader(
                  eyebrow: 'HOPE AI',
                  title: isEn
                      ? 'Let HOPE learn your work preferences'
                      : 'بگذارید HOPE سلیقه کاری شما را بشناسد',
                  subtitle: isEn
                      ? 'One question at a time. Your answers shape future opportunity recommendations.'
                      : 'هر بار یک سؤال کوتاه؛ پاسخ‌های شما پایه پیشنهادهای شغلی بعدی می‌شوند.',
                  trailing: PremiumIconButton(
                    icon: HopeV2Icons.close,
                    tooltip: isEn ? 'Skip' : 'بعداً',
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(height: HopeV2Spacing.lg),
                if (_loading) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: HopeV2Spacing.sm),
                ],
                Expanded(
                  child: PremiumPanel(
                    glass: true,
                    padding: const EdgeInsets.all(HopeV2Spacing.md),
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                        HopeV2Spacing.sm,
                        HopeV2Spacing.xs,
                        HopeV2Spacing.sm,
                        HopeV2Spacing.md,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final item = _messages[index];
                        final user = item['role'] == 'user';
                        return Align(
                          alignment: user
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: PremiumPanel(
                                highlight: user,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                child: Text(item['content'] ?? ''),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: HopeV2Spacing.md),
                SafeArea(
                  top: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          enabled:
                              !_loading && !_sending && !_saving && !_complete,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: isEn
                                ? 'Write your answer…'
                                : 'پاسخ خود را بنویسید…',
                            prefixIcon: const HopeIcon(
                              HopeV2Icons.message,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: HopeV2Spacing.sm),
                      PremiumIconButton(
                        icon: HopeV2Icons.arrowRight,
                        tooltip: isEn ? 'Send' : 'ارسال',
                        onPressed: (_loading ||
                                _sending ||
                                _saving ||
                                _complete)
                            ? null
                            : _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}