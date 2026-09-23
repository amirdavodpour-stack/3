import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/ui/hope_l10n.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/router/auth_return_intent.dart';
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
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(widget.returnIntent);
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
              maxWidth: 640,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
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
                      const HopeMark(size: 38),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PremiumHero(
                    eyebrow: HopeCopy.of(context).copy_start_a_good_collaboration_9df52cf,
                    title: HopeCopy.of(context).copy_start_a_good_collaboration_9df52cf,
                    message: HopeCopy.of(context).copy_create_a_hope_account_and_take_the_first_s_9ccd119,
                    icon: HopeV2Icons.userAdd,
                    height: 300,
                  ),
                  const SizedBox(height: 16),
                  PremiumPanel(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          controller: name,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: HopeCopy.of(context).copy_full_name_c7448f1,
                            prefixIcon: HopeIcon(HopeV2Icons.userAdd, size: 20),
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
                            prefixIcon: HopeIcon(HopeV2Icons.mail, size: 20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: obscure,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: HopeCopy.of(context).copy_password_656eabe,
                            prefixIcon: HopeIcon(HopeV2Icons.password, size: 20),
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
                  const SizedBox(height: 14),
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
