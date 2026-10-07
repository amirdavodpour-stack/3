import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin/admin_repository.dart';
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
  bool _busy = false;

  @override void dispose() { _name.dispose(); _username.dispose(); super.dispose(); }
  String _t(String fa, String en) => Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  Future<void> _unlock() async {
    final name = _name.text.trim(); final username = _username.text.trim();
    if (name.isEmpty || username.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AdminRepository>().verifyPanelAccess(name, username);
      if (!mounted) return;
      Navigator.pushReplacement(context, HopeRoutes.admin());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, fallback: _t('اطلاعات ورود پنل مدیریت صحیح نیست.', 'Admin panel identity verification failed.')))));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override Widget build(BuildContext context) => Directionality(
    textDirection: Localizations.localeOf(context).languageCode == 'en' ? TextDirection.ltr : TextDirection.rtl,
    child: Scaffold(
      body: PremiumPageFrame(maxWidth: 620, padding: const EdgeInsets.all(22), child: ListView(
        children: [
          PremiumHeader(
            page: HopePageId.adminAccess,
            domain: HopeProductDomain.control,
            eyebrow: _t('دسترسی محدود', 'Restricted access'), title: _t('ورود به مرکز مدیریت', 'Enter admin control center'), subtitle: _t('نام حساب و نام کاربری مدیریتی باید دقیقاً با هویت مجاز سامانه منطبق باشد.', 'Your account name and configured admin username must match exactly.'), trailing: const HopeIconTile(HopeV2Icons.secure, size: 52, filled: true)),
          const SizedBox(height: 20),
          TextField(controller: _name, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: _t('نام مدیر', 'Admin name'), prefixIcon: const Icon(Icons.badge_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _username, onSubmitted: (_) => _unlock(), decoration: InputDecoration(labelText: _t('نام کاربری مدیریتی', 'Admin username'), prefixIcon: const Icon(Icons.alternate_email))),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: _busy ? null : _unlock, icon: _busy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.lock_open), label: Text(_t('باز کردن پنل', 'Unlock admin panel'))),
          const SizedBox(height: 12),
          Text(_t('این احراز هویت کوتاه‌مدت است و برای اجرای عملیات حساس، نقش ADMIN و نشست معتبر همچنان الزامی است.', 'Verification is short-lived; a valid ADMIN role and authenticated session remain required for sensitive operations.'), style: Theme.of(context).textTheme.bodySmall),
        ],
      )),
    ),
  );
}