import 'package:flutter/material.dart';
import '../../core/ui/hope_l10n.dart';
import '../../core/application/application_registry.dart';
import '../../core/application/application_registry_context.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../../core/ui/hope_feedback.dart';
import '../../core/theme/hope_v2_design.dart';


ApplicationRegistry _applicationRegistry(BuildContext context) => applicationRegistryOf(context);

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});
  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final email = TextEditingController();
  bool loading = false;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty) {
      HopeFeedback.show(context, HopeCopy.of(context).copy_enter_your_email_2562106, tone: HopeFeedbackTone.warning);
      return;
    }
    setState(() => loading = true);
    try {
      await _applicationRegistry(context).requestPasswordReset(email.text.trim());
      if (mounted) {
        HopeFeedback.show(context, HopeCopy.of(context).copy_if_the_account_exists_a_reset_request_has__b974d8e, tone: HopeFeedbackTone.success);
      }
    } catch (error) {
      if (mounted) {
        HopeFeedback.show(context, apiErrorMessage(error, fallback: HopeCopy.of(context).copy_the_reset_request_could_not_be_submitted_475bdfd), tone: HopeFeedbackTone.error);
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
              page: HopePageId.passwordReset,
              maxWidth: 640,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                  const SizedBox(height: 8),
                  PremiumHero(
                    page: HopePageId.passwordReset,
                    domain: HopeProductDomain.account,
                    eyebrow: HopeCopy.of(context).copy_reset_password_18b5d1c,
                    title: HopeCopy.of(context).copy_reset_password_18b5d1c,
                    message: HopeCopy.of(context).copy_enter_your_account_email_and_we_will_start_16caa6e,
                    icon: HopeV2Icons.mail,
                    height: 128,
                    compactHero: true,
                  ),
                  const SizedBox(height: 8),
                  PremiumPanel(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: HopeCopy.of(context).copy_email_0cc870e,
                            prefixIcon: const Icon(HopeV2Icons.mail, size: 18, key: ValueKey('auth-email-field-icon')),
                          ),
                        ),
                        const SizedBox(height: 14),
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
                                : Text(HopeCopy.of(context).copy_send_request_0480e80),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  PremiumPanel(
                    key: const ValueKey('password-reset-privacy-note'),
                    quiet: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HopeIcon(
                          HopeV2Icons.secure,
                          size: 20,
                          color: HopeV2SemanticColors.info(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                HopeCopy.of(context).copy_you_are_covered_1bbe449,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                HopeCopy.of(context).copy_for_security_the_response_is_intentionally_6574fa6,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      height: 1.3,
                                    ),
                              ),
                            ],
                          ),
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
