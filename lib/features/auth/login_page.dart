import 'package:flutter/material.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/google_sign_in_service.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/router/app_routes.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loginFailedGeneric)),
        );
      }
      return;
    }
    setState(() => loading = true);
    try {
      await context
          .read<AuthController>()
          .loginWithGoogle(google);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(error, fallback: l10n.loginFailedGeneric),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    final l10n = AppLocalizations.of(context);
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.emailPasswordRequired)),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await context
          .read<AuthController>()
          .login(email.text.trim(), password.text);

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  apiErrorMessage(error, fallback: l10n.loginFailedGeneric))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(
                      Localizations.localeOf(context).languageCode == 'en'
                          ? Icons.arrow_back_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    tooltip: l10n.backButtonTooltip,
                  ),
                  const Spacer(),
                  const HopeMark(size: 38),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.loginWelcomeBack,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.loginWelcomeBackSubtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AnimatedEntrance(
                child: PremiumPanel(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (context.read<GoogleSignInService?>()?.isConfigured ?? false) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: loading ? null : submitGoogle,
                            icon: const Icon(Icons.account_circle_outlined),
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
                      Text(
                        Localizations.localeOf(context).languageCode == 'en'
                            ? 'Account email'
                            : 'ایمیل حساب',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 9),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: l10n.emailLabel,
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: obscure,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: l10n.passwordLabel,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
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
                      FilledButton(
                        onPressed: loading ? null : submit,
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.loginButton),
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
                icon: const Icon(Icons.travel_explore_rounded),
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
    );
  }
}
