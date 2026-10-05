import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/google_sign_in_service.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/router/app_routes.dart';
import '../../core/recommendation/recommendation_profile_repository.dart';
import '../../core/router/auth_return_intent.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../../core/ui/hope_feedback.dart';
import '../../core/theme/hope_v2_design.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.returnIntent});

  final AuthReturnIntent? returnIntent;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submitGoogle() async {
    final l10n = AppLocalizations.of(context);
    final google = context.read<GoogleSignInService?>();
    if (google == null || !google.isConfigured) {
      if (mounted) {
        HopeFeedback.show(context, l10n.loginFailedGeneric, tone: HopeFeedbackTone.error);
      }
      return;
    }
    setState(() => loading = true);
    try {
      await context
          .read<AuthController>()
          .loginWithGoogle(google);
      if (mounted) await _ensureRecommendationProfile();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(widget.returnIntent);
      }
    } catch (error) {
      if (mounted) {
        HopeFeedback.show(context, apiErrorMessage(error, fallback: l10n.loginFailedGeneric), tone: HopeFeedbackTone.error);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    final l10n = AppLocalizations.of(context);
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      HopeFeedback.show(context, l10n.emailPasswordRequired, tone: HopeFeedbackTone.warning);
      return;
    }

    setState(() => loading = true);

    try {
      await context
          .read<AuthController>()
          .login(email.text.trim(), password.text);

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(widget.returnIntent);
      }
    } catch (error) {
      if (mounted) {
        HopeFeedback.show(context, apiErrorMessage(error, fallback: l10n.loginFailedGeneric), tone: HopeFeedbackTone.error);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _ensureRecommendationProfile() async {
    try {
      final profile = await context.read<RecommendationProfileRepository>().get();
      if (!profile.onboardingCompleted && mounted) {
        await Navigator.of(context).push(HopeRoutes.recommendationOnboarding());
      }
    } catch (_) {
      // Existing login must not fail because personalization is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'en'
          ? TextDirection.ltr
          : TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: PremiumPageFrame(
            page: HopePageId.login,
            maxWidth: 640,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
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
                    tooltip: l10n.backButtonTooltip,
                  ),
                  const Spacer(),
                  const HopeMark(size: 34),
                ],
              ),
              const SizedBox(height: 12),
              PremiumHero(
                page: HopePageId.login,
                domain: HopeProductDomain.account,
                eyebrow: l10n.copy_hope_account_4ba3966,
                title: l10n.loginWelcomeBack,
                message: l10n.loginWelcomeBackSubtitle,
                icon: HopeV2Icons.login,
                height: 164,
              ),
              const SizedBox(height: 10),
              AnimatedEntrance(
                child: PremiumPanel(
                  // Auth is a dense primary surface; avoid a nested GPU blur
                  // here so the first Android frame remains deterministic.
                  glass: false,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (context.read<GoogleSignInService?>()?.isConfigured ?? false) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: loading ? null : submitGoogle,
                            icon: const HugeIcon(icon: HopeV2Icons.userAdd, size: 19),
                            label: Text(l10n.signInWithGoogle),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(l10n.orDivider),
                            ),
                            Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                          ],
                        ),
                        const SizedBox(height: 9),
                      ],
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: l10n.emailLabel,
                          prefixIcon: const HopeIcon(HopeV2Icons.mail, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: obscure,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: l10n.passwordLabel,
                          prefixIcon: const HopeIcon(HopeV2Icons.password, size: 20),
                          suffixIcon: IconButton(
                            icon: HugeIcon(
                              icon: obscure
                                  ? HopeV2Icons.viewOff
                                  : HopeV2Icons.view,
                              size: 20,
                            ),
                            tooltip: obscure
                                ? l10n.showPasswordTooltip
                                : l10n.hidePasswordTooltip,
                            onPressed: () => setState(() => obscure = !obscure),
                          ),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                              context, HopeRoutes.passwordReset()),
                          child: Text(l10n.forgotPassword),
                        ),
                      ),
                      const SizedBox(height: 6),
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
                              : Text(l10n.loginButton),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () {
                        context.read<AuthController>().continueAsGuest();
                        Navigator.maybePop(context);
                      },
                icon: const HugeIcon(icon: HopeV2Icons.workshop, size: 19),
                label: Text(l10n.continueAsGuest),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(l10n.orDivider),
                  ),
                  Expanded(
                    child: Divider(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.push(context, HopeRoutes.register()),
                child: Text(l10n.noAccountSignUp),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.loginTermsNotice,
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
}
