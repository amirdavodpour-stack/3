import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  @override
  State<AdminAccessPage> createState() => _AdminAccessPageState();
}

class _AdminAccessPageState extends State<AdminAccessPage> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _factor = TextEditingController();
  bool _busy = false;
  bool _loading = true;
  bool _recovery = false;
  String _scope = 'WRITE';
  String? _statusError;
  Map<String, dynamic> _status = const {};
  Map<String, dynamic>? _pending;
  List<String> _recoveryCodes = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    _factor.dispose();
    super.dispose();
  }

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  bool get _enabled => _status['enabled'] == true;

  void _notify(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _statusError = null;
    });
    try {
      final status = await context.read<AdminRepository>().getAdminMfaStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusError = apiErrorMessage(error,
            fallback: _t('وضعیت MFA دریافت نشد؛ ورود مدیریت قفل می‌ماند.',
                'MFA status is unavailable. Admin access remains locked.'));
        _loading = false;
      });
    }
  }

  bool _validPrimary({required bool google}) {
    if (_name.text.trim().isEmpty ||
        _username.text.trim().isEmpty ||
        (!google && _password.text.isEmpty)) {
      _notify(_t('نام مدیر، نام کاربری و احراز اصلی را کامل کنید.',
          'Enter the admin name, username and primary proof.'));
      return false;
    }
    return true;
  }

  Future<String?> _googleToken() =>
      context.read<GoogleSignInService>().authenticate();

  Future<void> _setup({bool google = false}) async {
    if (_busy || !_validPrimary(google: google)) return;
    setState(() => _busy = true);
    try {
      final token = google ? await _googleToken() : null;
      final result = await context.read<AdminRepository>().beginAdminMfaEnrollment(
            _name.text.trim(),
            _username.text.trim(),
            password: google ? null : _password.text,
            idToken: token,
          );
      if (!mounted) return;
      setState(() {
        _pending = result;
        _factor.clear();
      });
    } catch (error) {
      _notify(apiErrorMessage(error,
          fallback: _t('شروع ثبت Authenticator ناموفق بود.', 'Authenticator setup failed.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSetup() async {
    final code = _factor.text.trim();
    if (_busy || !RegExp(r'^\d{6}$').hasMatch(code)) {
      _notify(_t('کد شش‌رقمی Authenticator را وارد کنید.', 'Enter the six-digit authenticator code.'));
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await context.read<AdminRepository>().confirmAdminMfaEnrollment(code);
      final raw = result['recoveryCodes'];
      final codes = raw is List
          ? raw.map((item) => item.toString()).toList(growable: false)
          : const <String>[];
      if (codes.length != 10) throw StateError('Expected ten recovery codes.');
      if (!mounted) return;
      setState(() {
        _status = {..._status, 'enabled': true, 'recoveryCodesRemaining': 10};
        _pending = null;
        _recoveryCodes = codes;
        _factor.clear();
      });
    } catch (error) {
      _notify(apiErrorMessage(error,
          fallback: _t('کد تأیید نشد؛ کد فعلی را بررسی کنید.', 'Authenticator code was not accepted.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    _notify(message);
  }

  Future<void> _unlock({bool google = false}) async {
    if (_busy || !_enabled || !_validPrimary(google: google)) return;
    final code = _factor.text.trim();
    final valid = _recovery
        ? RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(code)
        : RegExp(r'^\d{6}$').hasMatch(code);
    if (!valid) {
      _notify(_recovery
          ? _t('کد بازیابی ۳۲رقمی معتبر وارد کنید.', 'Enter a valid 32-character recovery code.')
          : _t('کد شش‌رقمی Authenticator را وارد کنید.', 'Enter the six-digit authenticator code.'));
      return;
    }
    setState(() => _busy = true);
    try {
      final token = google ? await _googleToken() : null;
      await context.read<AdminRepository>().verifyPanelAccess(
            _name.text.trim(),
            _username.text.trim(),
            password: google ? null : _password.text,
            idToken: token,
            totpCode: _recovery ? null : code,
            recoveryCode: _recovery ? code : null,
            scope: _scope,
          );
      if (!mounted) return;
      Navigator.pushReplacement(context, HopeRoutes.admin());
    } catch (error) {
      _factor.clear();
      _notify(apiErrorMessage(error,
          fallback: _t('احراز اصلی یا کد دومرحله‌ای معتبر نیست.', 'Primary proof or second factor is invalid.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _primaryFields() => Column(children: [
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: _t('نام مدیر', 'Admin name')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _username,
          decoration: InputDecoration(labelText: _t('نام کاربری مدیریتی', 'Admin username')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(labelText: _t('گذرواژهٔ فعلی', 'Current password')),
        ),
      ]);

  Widget _mfaEnrollment() {
    final pending = _pending;
    if (pending == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(_t('ابتدا Authenticator را برای حساب مدیر فعال کنید.',
                'Register an authenticator before entering the admin panel.')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _setup,
              child: Text(_t('ثبت با گذرواژه', 'Set up with password')),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _setup(google: true),
              child: Text(_t('ثبت با Google متصل', 'Set up with linked Google')),
            ),
            if (_status['enrollmentPending'] == true)
              Text(_t('ثبت‌نام نیمه‌کاره وجود دارد؛ شروع مجدد راز موقت را جایگزین می‌کند.',
                  'A pending enrollment exists; restarting replaces its temporary secret.')),
          ]),
        ),
      );
    }
    final secret = pending['secret']?.toString() ?? '';
    final uri = pending['otpauthUri']?.toString() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_t('ثبت Authenticator', 'Authenticator setup'),
              style: Theme.of(context).textTheme.titleMedium),
          Text(_t('کلید زیر را در برنامهٔ Authenticator وارد کنید. این کلید فقط یک‌بار نمایش داده می‌شود.',
              'Enter this key in your authenticator app. The secret is shown only once.')),
          const SizedBox(height: 12),
          SelectableText(secret, textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: _busy ? null : () => _copy(secret, _t('کلید کپی شد.', 'Secret copied.')),
            icon: const Icon(Icons.copy),
            label: Text(_t('کپی کلید', 'Copy secret')),
          ),
          ExpansionTile(
            title: Text(_t('لینک راه‌اندازی', 'Setup URI')),
            children: [
              SelectableText(uri),
              TextButton(
                onPressed: _busy ? null : () => _copy(uri, _t('لینک کپی شد.', 'URI copied.')),
                child: Text(_t('کپی لینک', 'Copy URI')),
              ),
            ],
          ),
          TextField(
            controller: _factor,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: _t('کد شش‌رقمی', 'Six-digit code')),
          ),
          FilledButton(
            onPressed: _busy ? null : _confirmSetup,
            child: Text(_t('تأیید و فعال‌سازی', 'Confirm and enable')),
          ),
        ]),
      ),
    );
  }

  Widget _codesCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(_t('کدهای بازیابی — فقط همین‌بار', 'Recovery codes — shown once')),
            const SizedBox(height: 8),
            Text(_t('هر کد یک‌بار مصرف است. در محل امن ذخیره کنید؛ سرور فقط hash آن‌ها را نگه می‌دارد.',
                'Each code works once. Store them securely; the server keeps only hashes.')),
            const SizedBox(height: 8),
            SelectableText(_recoveryCodes.join('\n'), textAlign: TextAlign.center),
            TextButton.icon(
              onPressed: () => _copy(_recoveryCodes.join('\n'), _t('کدها کپی شدند.', 'Codes copied.')),
              icon: const Icon(Icons.copy),
              label: Text(_t('کپی همهٔ کدها', 'Copy all codes')),
            ),
            TextButton(
              onPressed: () => setState(() => _recoveryCodes = const []),
              child: Text(_t('کدها را ذخیره کردم', 'I have stored the codes')),
            ),
          ]),
        ),
      );

  Widget _mfaUnlock() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_t('احراز دومرحله‌ای فعال است', 'Two-factor authentication is enabled'),
                style: Theme.of(context).textTheme.titleMedium),
            TextButton(
              onPressed: () => setState(() {
                _recovery = !_recovery;
                _factor.clear();
              }),
              child: Text(_recovery
                  ? _t('استفاده از Authenticator', 'Use authenticator')
                  : _t('استفاده از کد بازیابی', 'Use recovery code')),
            ),
            TextField(
              controller: _factor,
              keyboardType: _recovery ? TextInputType.text : TextInputType.number,
              maxLength: _recovery ? 32 : 6,
              textCapitalization: _recovery ? TextCapitalization.characters : TextCapitalization.none,
              inputFormatters: _recovery
                  ? [FilteringTextInputFormatter.allow(RegExp('[a-fA-F0-9]'))]
                  : [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _recovery ? _t('کد بازیابی', 'Recovery code') : _t('کد شش‌رقمی', 'Six-digit code'),
              ),
            ),
            const Divider(),
            RadioListTile<String>(
              value: 'READ',
              groupValue: _scope,
              onChanged: _busy ? null : (value) => setState(() => _scope = value ?? 'READ'),
              title: Text(_t('فقط مشاهده — ۱۵ دقیقه', 'Read only — 15 minutes')),
            ),
            RadioListTile<String>(
              value: 'WRITE',
              groupValue: _scope,
              onChanged: _busy ? null : (value) => setState(() => _scope = value ?? 'WRITE'),
              title: Text(_t('عملیات مدیریتی — ۵ دقیقه', 'Admin actions — 5 minutes')),
            ),
            FilledButton(
              onPressed: _busy ? null : _unlock,
              child: Text(_t('تأیید با گذرواژه و عامل دوم', 'Verify password and second factor')),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _unlock(google: true),
              child: Text(_t('تأیید با Google و عامل دوم', 'Verify Google and second factor')),
            ),
            Text(_t('پس از ثبت‌نام، کد چرخهٔ بعدی را وارد کنید؛ کد ثبت‌نام دوباره پذیرفته نمی‌شود.',
                'After enrollment, use a code from the next time step; the enrollment code cannot be replayed.')),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: Scaffold(
          body: PremiumPageFrame(
            maxWidth: 620,
            padding: const EdgeInsets.all(16),
            child: ListView(children: [
              PremiumHeader(
                page: HopePageId.adminAccess,
                domain: HopeProductDomain.control,
                eyebrow: _t('دسترسی محدود', 'Restricted access'),
                title: _t('ورود به مرکز مدیریت', 'Enter admin control center'),
                subtitle: _t('احراز اصلی و عامل دوم برای باز کردن پنل الزامی است.',
                    'Primary authentication and a second factor are required.'),
                trailing: const HopeIconTile(HopeV2Icons.secure, size: 52, filled: true),
              ),
              const SizedBox(height: 20),
              _primaryFields(),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_statusError != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Text(_statusError!, textAlign: TextAlign.center),
                      TextButton(onPressed: _busy ? null : _loadStatus, child: Text(_t('تلاش دوباره', 'Retry'))),
                    ]),
                  ),
                )
              else if (!_enabled)
                _mfaEnrollment()
              else
                _mfaUnlock(),
              if (_recoveryCodes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _codesCard(),
              ],
            ]),
          ),
        ),
      );
}
