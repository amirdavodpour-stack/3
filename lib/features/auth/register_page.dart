import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import '../../core/ui/hope_l10n.dart';
import 'package:provider/provider.dart';
import '../../core/config/backend_capabilities.dart';
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
  bool _capabilitiesLookupAttempted = false;
  BackendCapabilities? _backendCapabilities;

  bool get _canUseGoogleSignIn =>
      (context.read<GoogleSignInService?>()?.isConfigured ?? false) &&
      _backendCapabilities?.googleSignIn == true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_capabilitiesLookupAttempted) return;
    _capabilitiesLookupAttempted = true;
    try {
      final repository = context.read<BackendCapabilitiesRepository>();
      unawaited(_loadBackendCapabilities(repository));
    } on ProviderNotFoundException {
      _backendCapabilities = null;
    }
  }

  Future<void> _loadBackendCapabilities(
    BackendCapabilitiesRepository repository,
  ) async {
    try {
      final capabilities = await repository.load();
      if (!mounted) return;
      setState(() => _backendCapabilities = capabilities);
    } catch (_) {
      if (!mounted) return;
      setState(() => _backendCapabilities = null);
    }
  }

  Future<void> submitGoogle() async {
    final google = context.read<GoogleSignInService?>();
    if (google == null ||
        !google.isConfigured ||
        _backendCapabilities?.googleSignIn != true) return;
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
        if (widget.returnIntent != null) {
          Navigator.of(context).pop(widget.returnIntent);
        } else {
          await Navigator.of(context).push(HopeRoutes.recommendationOnboarding());
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop(widget.returnIntent);
          }
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
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final denseAuth =
        (mediaQuery.size.height < 760 || mediaQuery.viewInsets.bottom > 0) &&
        mediaQuery.textScaler.scale(1) <= 1.2;
    return Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(
            child: PremiumPageFrame(
              page: HopePageId.register,
              maxWidth: 640,
              padding: EdgeInsets.fromLTRB(
                16,
                denseAuth ? 4 : 8,
                16,
                denseAuth ? 10 : 24,
              ),
              child: ListView(
                padding: HopeV2Navigation.scrollEndPadding(context),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: HopeIcon( Localizations.localeOf(context).languageCode == 'en'
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
                  SizedBox(height: denseAuth ? 4 : 8),
                  PremiumHero(
                    page: HopePageId.register,
                    domain: HopeProductDomain.account,
                    eyebrow: HopeCopy.of(context).copy_start_a_good_collaboration_9df52cf,
                    title: HopeCopy.of(context).copy_start_a_good_collaboration_9df52cf,
                    message: HopeCopy.of(context).copy_create_a_hope_account_and_take_the_first_s_9ccd119,
                    icon: HopeV2Icons.userAdd,
                    height: denseAuth ? 100 : 112,
                    compactHero: true,
                  ),
                  SizedBox(height: denseAuth ? 6 : 8),
                  PremiumPanel(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      children: [
                        if (_canUseGoogleSignIn) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                               key: const ValueKey('auth-google-sign-in'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1F1F1F),
                                side: const BorderSide(color: Color(0xFFDADCE0)),
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: loading ? null : submitGoogle,
                              icon: Image.asset(
                                'assets/branding/google_g.png',
                                width: 20,
                                height: 20,
                                excludeFromSemantics: true,
                              ),
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
                            prefixIcon: const Icon(HopeV2Icons.userAdd, size: 18, key: ValueKey('auth-name-field-icon')),
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
                            prefixIcon: const Icon(HopeV2Icons.mail, size: 18, key: ValueKey('auth-email-field-icon')),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: obscure,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: HopeCopy.of(context).copy_password_656eabe,
                            prefixIcon: const Icon(HopeV2Icons.password, size: 18, key: ValueKey('auth-password-field-icon')),
                            suffixIcon: IconButton(
                              icon: HopeIcon( obscure ? HopeV2Icons.viewOff : HopeV2Icons.view,
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
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: HopeV2ButtonStyles.auditedGreenPrimaryCta(context),
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
}
