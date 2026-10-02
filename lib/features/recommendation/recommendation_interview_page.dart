import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_error_presenter.dart';
import '../../core/recommendation/recommendation_profile_repository.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/ui/hope_feedback.dart';
import '../../core/ui/premium_components.dart';

class RecommendationInterviewPage extends StatefulWidget {
  const RecommendationInterviewPage({super.key});
  @override
  State<RecommendationInterviewPage> createState() => _RecommendationInterviewPageState();
}

class _RecommendationInterviewPageState extends State<RecommendationInterviewPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _history = [];
  final List<Map<String, String>> _messages = [];
  final Map<String, dynamic> _profile = <String, dynamic>{
    'resumeText': '', 'skills': <String>[], 'interests': <String>[],
    'preferredCategories': <String>[], 'preferredCities': <String>[],
    'desiredKinds': <String>[], 'workMode': null, 'availability': null,
    'salaryMin': null, 'salaryMax': null, 'experienceLevel': null, 'goals': '',
  };
  bool _loading = true;
  bool _sending = false;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    _askNextQuestion();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _askNextQuestion() async {
    try {
      final reply = await context.read<RecommendationProfileRepository>().interview(history: _history, message: '');
      _appendAssistant(reply);
    } catch (error) {
      if (mounted) HopeFeedback.show(context, apiErrorMessage(error, fallback: 'مصاحبه هوشمند در دسترس نیست.'), tone: HopeFeedbackTone.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _appendAssistant(RecommendationInterviewReply reply) {
    _messages.add({'role': 'assistant', 'content': reply.reply});
    _history.add({'role': 'assistant', 'content': reply.reply});
    _merge(reply.profilePatch);
    _complete = reply.complete;
    _jumpToEnd();
  }

  void _merge(HopeRecommendationProfile patch) {
    List<String> mergeList(String key, List<String> incoming) {
      final current = List<String>.from((_profile[key] as List?) ?? const []);
      for (final item in incoming) if (!current.contains(item)) current.add(item);
      return current;
    }
    _profile['resumeText'] = patch.resumeText.isNotEmpty ? patch.resumeText : _profile['resumeText'];
    _profile['skills'] = mergeList('skills', patch.skills);
    _profile['interests'] = mergeList('interests', patch.interests);
    _profile['preferredCategories'] = mergeList('preferredCategories', patch.preferredCategories);
    _profile['preferredCities'] = mergeList('preferredCities', patch.preferredCities);
    _profile['desiredKinds'] = mergeList('desiredKinds', patch.desiredKinds);
    _profile['workMode'] ??= patch.workMode;
    _profile['availability'] ??= patch.availability;
    _profile['salaryMin'] ??= patch.salaryMin;
    _profile['salaryMax'] ??= patch.salaryMax;
    _profile['experienceLevel'] ??= patch.experienceLevel;
    _profile['goals'] = patch.goals.isNotEmpty ? patch.goals : _profile['goals'];
  }

  Future<void> _send() async {
    final message = _input.text.trim();
    if (message.isEmpty || _sending || _complete) return;
    _input.clear();
    setState(() {
      _sending = true;
      _messages.add({'role': 'user', 'content': message});
      _history.add({'role': 'user', 'content': message});
    });
    _jumpToEnd();
    try {
      final reply = await context.read<RecommendationProfileRepository>().interview(history: _history, message: message);
      if (!mounted) return;
      _appendAssistant(reply);
      if (reply.complete) await _saveProfile();
    } catch (error) {
      if (mounted) HopeFeedback.show(context, apiErrorMessage(error, fallback: 'پاسخ ثبت نشد. دوباره تلاش کنید.'), tone: HopeFeedbackTone.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveProfile() async {
    final profile = HopeRecommendationProfile(
      resumeText: '${_profile['resumeText'] ?? ''}',
      skills: List<String>.from(_profile['skills'] as List),
      interests: List<String>.from(_profile['interests'] as List),
      preferredCategories: List<String>.from(_profile['preferredCategories'] as List),
      preferredCities: List<String>.from(_profile['preferredCities'] as List),
      desiredKinds: List<String>.from(_profile['desiredKinds'] as List),
      workMode: _profile['workMode'] as String?,
      availability: _profile['availability'] as String?,
      salaryMin: _profile['salaryMin'] as String?,
      salaryMax: _profile['salaryMax'] as String?,
      experienceLevel: _profile['experienceLevel'] as String?,
      goals: '${_profile['goals'] ?? ''}',
      onboardingCompleted: true,
    );
    await context.read<RecommendationProfileRepository>().save(profile);
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final en = Localizations.localeOf(context).languageCode == 'en';
    return Directionality(
      textDirection: en ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(en ? 'HOPE AI work profile' : 'پروفایل کاری با HOPE AI')),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: _messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return PremiumHero(
                          eyebrow: 'HOPE AI',
                          title: en ? 'A short work interview' : 'یک گفت‌وگوی کوتاه درباره مسیر کاری شما',
                          message: en ? 'Answer naturally. HOPE uses what you tell it, plus your activity and work history, to personalize opportunities.' : 'طبیعی جواب بدهید. HOPE پاسخ‌های شما را همراه با جست‌وجو، رفتار و سابقه کاری برای پیشنهاد فرصت‌های مناسب استفاده می‌کند.',
                          icon: Icons.auto_awesome,
                          height: 220,
                        );
                        final message = _messages[index - 1];
                        final mine = message['role'] == 'user';
                        return Align(
                          alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 680),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: mine ? HopeV2Colors.secondary.withValues(alpha: .18) : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(HopeV2Radii.md),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Text(message['content'] ?? ''),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(hintText: en ? 'Tell HOPE about your work...' : 'درباره مسیر کاری‌تان به HOPE بگویید...'),
                )),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _sending || _complete ? null : _send, icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_upward)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}