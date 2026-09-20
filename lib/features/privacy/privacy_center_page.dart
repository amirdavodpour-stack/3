import 'dart:convert';
import '../../core/ui/components.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/account/account_privacy_repository.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/premium_components.dart';

class PrivacyCenterPage extends StatefulWidget {
  const PrivacyCenterPage({super.key});

  @override
  State<PrivacyCenterPage> createState() => _PrivacyCenterPageState();
}

class _PrivacyCenterPageState extends State<PrivacyCenterPage> {
  Map<String, dynamic>? _export;
  bool _loading = false;
  bool _deleting = false;

  AccountPrivacyRepository get _repo =>
      context.read<AccountPrivacyRepository>();

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  Future<void> _exportData() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.exportData();
      if (!mounted) return;
      setState(() => _export = data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('داده‌های حساب آماده شد.', 'Your account data is ready.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error,
            fallback: _t('دریافت داده‌ها ناموفق بود.', 'Could not export your data.')))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyExport() async {
    final data = _export;
    if (data == null) return;
    // Runtime JSON payload prevents this constructor from being const.
    // ignore: prefer_const_constructors
    await Clipboard.setData(ClipboardData(
      text: JsonEncoder.withIndent('  ').convert(data),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('خروجی JSON کپی شد.', 'JSON export copied.'))),
    );
  }

  Future<void> _deleteAccount() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('حذف حساب', 'Delete account')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t(
              'این عملیات حساب را حذف و اطلاعات شخصی را ناشناس می‌کند. برخی داده‌های لازم برای سوابق مالی و شواهد ممکن است طبق سیاست نگهداری باقی بمانند.',
              'This action deletes the account and anonymizes personal information. Some data required for financial records and evidence may remain under retention rules.',
            )),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: _t('برای تأیید DELETE را وارد کنید', 'Type DELETE to confirm'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('انصراف', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim().toUpperCase() == 'DELETE',
            ),
            child: Text(_t('حذف حساب', 'Delete account')),
          ),
        ],
      ),
    );
    controller.dispose();

    if (confirmed != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t(
            'تأیید کامل نشد؛ حساب حذف نشد.',
            'Confirmation failed; your account was not deleted.',
          ))),
        );
      }
      return;
    }

    setState(() => _deleting = true);
    try {
      await _repo.deleteAccount();
      if (!mounted) return;
      await context.read<AuthController>().logout(notifyServer: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error,
            fallback: _t('حذف حساب ناموفق بود.', 'Could not delete your account.')))),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('حریم خصوصی و داده‌ها', 'Privacy & data'))),
      body: PremiumPageFrame(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
        child: ListView(
          padding: EdgeInsets.zero,
        children: [
          PremiumHeader(
            eyebrow: _t('کنترل حساب', 'ACCOUNT CONTROL'),
            title: _t('داده‌ها تحت کنترل شماست', 'Your data, under your control'),
            subtitle: _t(
              'خروجی اطلاعات و حذف حساب را از یک مسیر شفاف مدیریت کنید.',
              'Export your account data or permanently delete the account from one clear place.',
            ),
            trailing: const HopeIconTile(Icons.privacy_tip_outlined, size: 50, filled: true),
          ),
          const SizedBox(height: 18),
          PremiumPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('دریافت داده‌ها', 'Export your data'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(_t(
                  'یک خروجی ساختاریافته از داده‌هایی که HOPE برای حساب شما نگه می‌دارد دریافت کن.',
                  'Get a structured export of the data HOPE stores for your account.',
                )),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : _exportData,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded),
                  label: Text(_loading ? _t('در حال آماده‌سازی…', 'Preparing…') : _t('دریافت خروجی', 'Export data')),
                ),
              ],
            ),
          ),
          if (_export != null) ...[
            const SizedBox(height: 12),
            PremiumPanel(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_t('پیش‌نمایش خروجی', 'Export preview'),
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      IconButton(
                        tooltip: _t('کپی JSON', 'Copy JSON'),
                        onPressed: _copyExport,
                        icon: const Icon(Icons.copy_all_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Runtime export JSON prevents this constructor from being const.
                  // ignore: prefer_const_constructors
                  SelectableText(
                    JsonEncoder.withIndent('  ').convert(_export),
                    maxLines: 18,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          PremiumPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('حذف حساب', 'Delete account'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    )),
                const SizedBox(height: 8),
                Text(_t(
                  'حذف حساب برگشت‌پذیر نیست. قبل از انجام آن، خروجی داده‌ها را دریافت کنید.',
                  'Account deletion cannot be undone. Export your data first if you need a copy.',
                )),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _deleting ? null : _deleteAccount,
                  icon: _deleting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_forever_rounded),
                  label: Text(_deleting ? _t('در حال حذف…', 'Deleting…') : _t('حذف دائمی حساب', 'Delete account permanently')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
