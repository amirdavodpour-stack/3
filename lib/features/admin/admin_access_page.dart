import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin/admin_repository.dart';
import '../../core/auth/google_sign_in_service.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/router/app_routes.dart';
import '../../core/ui/components.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/ui/premium_components.dart';

class AdminAccessPage extends StatefulWidget {
  const AdminAccessPage({super.key});
  @override State<AdminAccessPage> createState() => _AdminAccessPageState();
}

class _AdminAccessPageState extends State<AdminAccessPage> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  Future<void> _unlock({bool useGoogle = false}) async {
    final name = _name.text.trim();
    final username = _username.text.trim();
    final password = _password.text;
    if (name.isEmpty || username.isEmpty || (!useGoogle && password.isEmpty) || _busy) {
      return;
    }

    setState(() => _busy = true);
    try {
      final idToken = useGoogle
          ? await context.read<GoogleSignInService>().authenticate()
          : null;
      await context.read<AdminRepository>().verifyPanelAccess(
            name,
            username,
            password: useGoogle ? null : password,
            idToken: idToken,
          );
      if (!mounted) return;
      Navigator.pushReplacement(context, HopeRoutes.admin());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              e,
              fallback: _t(
                'احراز هویت مجدد انجام نشد؛ گذرواژه یا حساب Google متصل را بررسی کنید.',
                'Reauthentication failed. Check your password or linked Google account.',
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: Scaffold(
          body: PremiumPageFrame(
            maxWidth: 620,
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                PremiumHeader(
                  page: HopePageId.adminAccess,
                  domain: HopeProductDomain.control,
                  eyebrow: _t('دسترسی محدود', 'Restricted access'),
                  title: _t('ورود به مرکز مدیریت', 'Enter admin control center'),
                  subtitle: _t(
                    'برای باز کردن پنل، گذرواژهٔ فعلی یا تأیید تازهٔ حساب Google متصل را ارائه کنید.',
                    'Re-authenticate with your current password or a fresh assertion from the linked Google account.',
                  ),
                  trailing: const HopeIconTile(
                    HopeV2Icons.secure,
                    size: 52,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _t('نام مدیر', 'Admin name'),
                    prefixIcon: const Icon(HopeV2Icons.identity),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _t('نام کاربری مدیریتی', 'Admin username'),
                    prefixIcon: const Icon(HopeV2Icons.at),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _unlock(),
                  decoration: InputDecoration(
                    labelText: _t('گذرواژهٔ فعلی حساب', 'Current account password'),
                    prefixIcon: const Icon(Icons.password),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy ? null : _unlock,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(HopeV2Icons.lockOpen),
                  label: Text(_t('تأیید با گذرواژه', 'Verify with password')),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _unlock(useGoogle: true),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(_t('تأیید با حساب Google متصل', 'Verify with linked Google')),
                ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    'فقط یکی از دو روش احراز لازم است. دسترسی پنل کوتاه‌مدت است و نقش ADMIN و نشست معتبر همچنان الزامی‌اند.',
                    'Use exactly one verification method. Panel access is short-lived; a valid ADMIN role and authenticated session remain required.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
}
