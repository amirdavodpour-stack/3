import 'package:flutter/material.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/ui/hope_l10n.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/google_sign_in_service.dart';
import '../../core/router/auth_return_intent.dart';
import '../../core/router/app_routes.dart';
import '../../core/recommendation/recommendation_profile_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/premium_components.dart';
import '../../core/ui/hope_feedback.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/ui/components.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.returnIntent});

  final AuthReturnIntent? returnIntent;
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool loading = false;

  Future<void> submitGoogle() async {
    final google = context.read<GoogleSignInService?>();
    if (google == null || !google.isConfigured) return;
    setState(() => loading = true);
    try {
      await context.read<AuthController>().loginWithGoogle(google);
      if (mounted) {
        try {
          final profile =
              await context.read<RecommendationProfileRepository>().get();
          if (!profile.onboardingCompleted && mounted) {
            await Navigator.of(context)
                .push(HopeRoutes.recommendationOnboarding());
          }
        } catch (_) {
          // Existing auth must not fail because personalization is unavailable.
        }
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(widget.returnIntent);
        }
      }
    } catch (error) {
      if (mounted) {
        HopeFeedback.show(
          context,
          apiErrorMessage(
            error,
            fallback: AppLocalizations.of(context).loginFailedGeneric,
          ),
          tone: HopeFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.isEmpty) {
      HopeFeedback.show(context, HopeCopy.of(context).copy_please_complete_all_fields_55c07bb, tone: HopeFeedbackTone.warning);
      return;
    }
    if (password.text.length < 8) {
      HopeFeedback.show(context, HopeCopy.of(context).copy_password_must_be_at_least_8_characters_8ad17c6, tone: HopeFeedbackTone.warning);
      return;
    }
    setState(() => loading = true);
    try {
      await context
          .read<AuthController>()
          .register(email.text.trim(), password.text, name.text.trim());
      if (mounted) {
        await Navigator.of(context).push(HopeRoutes.recommendationOnboarding());
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(widget.returnIntent);
        }
      }
    } catch (error) {
      if (mounted) {
        HopeFeedback.show(context, apiErrorMessage(error, fallback: HopeCopy.of(context).copy_registration_failed_please_try_again_bbb72e2), tone: HopeFeedbackTone.error);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(
            child: PremiumPageFrame(
              page: HopePageId.register,
              maxWidth: 640,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: HugeIcon(
                          icon: Localizations.localeOf(context).languageCode == 'en'
                              ? HopeV2Icons.arrowLeft
                              : HopeV2Icons.arrowRight,
                          size: 21,
                        ),
                        tooltip: HopeCopy.of(context).copy_back_6e09f79,
                      ),
                      const Spacer(),
                      const HopeMark(size: 34),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PremiumHero(
                    page: HopePageId.register,
                    domain: HopeProductDomain.account,
                    eyebrow: HopeCopy.of(context).copy_start_a_good_collaboration_9df52cf,
                    title: HopeCopy.of(context).copy_start_a_good_collaboration_9df52cf,
                    message: HopeCopy.of(context).copy_create_a_hope_account_and_take_the_first_s_9ccd119,
                    icon: HopeV2Icons.userAdd,
                    height: 128,
                  ),
                  const SizedBox(height: 12),
                  PremiumPanel(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        if (context.read<GoogleSignInService?>()?.isConfigured ?? false) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: loading ? null : submitGoogle,
                              icon: const HopeIcon(HopeV2Icons.userAdd, size: 19),
                              label: Text(
                                AppLocalizations.of(context).signInWithGoogle,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  AppLocalizations.of(context).orDivider,
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        TextField(
                          controller: name,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: HopeCopy.of(context).copy_full_name_c7448f1,
                            prefixIcon: const HopeIcon(HopeV2Icons.userAdd, size: 20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: HopeCopy.of(context).copy_email_0cc870e,
                            prefixIcon: const HopeIcon(HopeV2Icons.mail, size: 20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: obscure,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: HopeCopy.of(context).copy_password_656eabe,
                            prefixIcon: const HopeIcon(HopeV2Icons.password, size: 20),
                            suffixIcon: IconButton(
                              icon: HugeIcon(
                                icon: obscure ? HopeV2Icons.viewOff : HopeV2Icons.view,
                                size: 20,
                              ),
                              tooltip: obscure
                                  ? HopeCopy.of(context).showPasswordTooltip
                                  : HopeCopy.of(context).hidePasswordTooltip,
                              onPressed: () => setState(() => obscure = !obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            HopeCopy.of(context).copy_at_least_8_characters_eb24592,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: loading ? null : submit,
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(HopeCopy.of(context).copy_create_account_bfa3517),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    HopeCopy.of(context).copy_your_account_data_is_kept_securely_by_hope_b91dd1f,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
