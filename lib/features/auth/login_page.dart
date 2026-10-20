import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/config/backend_capabilities.dart';
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

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submitGoogle() async {
    final l10n = AppLocalizations.of(context);
    final google = context.read<GoogleSignInService?>();
    if (google == null ||
        !google.isConfigured ||
        _backendCapabilities?.googleSignIn != true) {
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
    final denseAuth =
        (MediaQuery.sizeOf(context).height < 760 ||
            MediaQuery.viewInsetsOf(context).bottom > 0) &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.2;
    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'en'
          ? TextDirection.ltr
          : TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: PremiumPageFrame(
            page: HopePageId.login,
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
                    tooltip: l10n.backButtonTooltip,
                  ),
                  const Spacer(),
                  const HopeMark(size: 34),
                ],
              ),
              SizedBox(height: denseAuth ? 4 : 8),
              PremiumHero(
                page: HopePageId.login,
                domain: HopeProductDomain.account,
                eyebrow: l10n.copy_hope_account_4ba3966,
                title: l10n.loginWelcomeBack,
                message: l10n.loginWelcomeBackSubtitle,
                icon: HopeV2Icons.login,
                // Keep the compact auth hero tall enough for 1.5x text. Its
                // title and subtitle can each wrap to two lines in fa-RTL.
                height: MediaQuery.textScalerOf(context).scale(1) > 1.2
                    ? 156
                    : (denseAuth ? 92 : 104),
                compactHero: true,
              ),
              SizedBox(height: denseAuth ? 4 : 8),
              AnimatedEntrance(
                child: PremiumPanel(
                  // Auth is a dense primary surface; avoid a nested GPU blur
                  // here so the first Android frame remains deterministic.
                  glass: false,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_canUseGoogleSignIn) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const ValueKey('auth-google-sign-in'),
                            style: HopeV2ButtonStyles.googleSignIn(),
                            onPressed: loading ? null : submitGoogle,
                            icon: Image.asset(
                              'assets/branding/google_g.png',
                              width: 20,
                              height: 20,
                              excludeFromSemantics: true,
                            ),
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
                          prefixIcon: const Icon(HopeV2Icons.mail, size: 18, key: ValueKey('auth-email-field-icon')),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: obscure,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: l10n.passwordLabel,
                          prefixIcon: const Icon(HopeV2Icons.password, size: 18, key: ValueKey('auth-password-field-icon')),
                          suffixIcon: IconButton(
                            icon: HopeIcon( obscure
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
                          style: HopeV2ButtonStyles.auditedGreenPrimaryCta(context),
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
              SizedBox(height: denseAuth ? 6 : 10),
              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () {
                        context.read<AuthController>().continueAsGuest();
                        Navigator.maybePop(context);
                      },
                icon: const HopeIcon( HopeV2Icons.workshop, size: 19),
                label: Text(l10n.continueAsGuest),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.push(context, HopeRoutes.register()),
                child: Text(l10n.noAccountSignUp),
              ),
              const SizedBox(height: 12),
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
