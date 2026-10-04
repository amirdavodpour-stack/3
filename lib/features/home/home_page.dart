import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/router/app_routes.dart';
import '../../core/router/auth_return_intent.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/transactions/transaction_repository.dart';
import '../../core/transactions/wallet_repository.dart';
import '../../core/ui/hope_l10n.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../jobs/jobs_page.dart';
import '../profile/profile_page.dart';
import '../transactions/transactions_page.dart';
import '../wallet/wallet_page.dart';
import 'premium_home_feed.dart';



part 'home_widgets.part.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int tab = 0;
  late final List<Widget?> _tabs = List<Widget?>.filled(5, null);

  Widget _buildTab(int index) => _tabs[index] ??= switch (index) {
        0 => buildResponsiveHomeFeed(
            context,
            () => _selectTab(1),
            () => _scaffoldKey.currentState?.openDrawer(),
            () => _openCreate(context),
          ),
        1 => const JobsPage(key: ValueKey('explore')),
        2 => TransactionsPage(
            key: const ValueKey('transactions'),
            repository: context.read<TransactionRepository>(),
          ),
        3 => WalletPage(repository: context.read<WalletRepository>()),
        4 => const ProfilePage(key: ValueKey('profile')),
        _ => const SizedBox.shrink(),
      };

  void _selectTab(int value) {
    if (value == tab) return;
    setState(() => tab = value);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final settings = context.watch<HopeSettingsController>();
    final isDesktop = MediaQuery.sizeOf(context).width >= HopeV2Breakpoints.medium;
    final destinations = [
      NavigationDestination(
        icon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-home'),
          icon: HopeV2Icons.home,
          selected: false,
        ),
        selectedIcon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-home-selected'),
          icon: HopeV2Icons.home,
          selected: true,
        ),
        label: _t(context, 'خانه', 'Home'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-explore'),
          icon: HopeV2Icons.search,
          selected: false,
        ),
        selectedIcon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-explore-selected'),
          icon: HopeV2Icons.search,
          selected: true,
        ),
        label: _t(context, 'کاوش', 'Explore'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-work'),
          icon: HopeV2Icons.workshop,
          selected: false,
        ),
        selectedIcon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-work-selected'),
          icon: HopeV2Icons.workshop,
          selected: true,
        ),
        label: _t(context, 'کار', 'Work'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-wallet'),
          icon: HopeV2Icons.wallet,
          selected: false,
        ),
        selectedIcon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-wallet-selected'),
          icon: HopeV2Icons.wallet,
          selected: true,
        ),
        label: _t(context, 'کیف پول', 'Wallet'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-profile'),
          icon: HopeV2Icons.profile,
          selected: false,
        ),
        selectedIcon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-profile-selected'),
          icon: HopeV2Icons.profile,
          selected: true,
        ),
        label: _t(context, 'پروفایل', 'Profile'),
      ),
    ];

    final content = IndexedStack(
      index: tab,
      children: List.generate(5, (i) => _tabs[i] ?? (i == tab ? _buildTab(tab) : const SizedBox.shrink())),
    );

    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  PremiumNavigationRail(
                    selectedIndex: tab,
                    onDestinationSelected: _selectTab,
                    extended:
                        MediaQuery.sizeOf(context).width >= HopeV2Breakpoints.expanded,
                    leading: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 22),
                      child: HopeMark(
                        size: 44,
                        showText:
                            MediaQuery.sizeOf(context).width >=
                            HopeV2Breakpoints.expanded,
                      ),
                    ),
                    destinations: destinations,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
      bottomNavigationBar: isDesktop
          ? null
          : PremiumNavigationBar(
              selectedIndex: tab,
              onDestinationSelected: _selectTab,
              destinations: destinations,
            ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HopeMark(size: 48),
              const SizedBox(height: 18),
              Text(_t(context, 'منوی برنامه', 'App menu'), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(_t(context, 'دسترسی به بخش‌های برنامه.', 'App sections.'), style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              PremiumDomainNavigationGroup(
                domain: HopeProductDomain.discovery,
                compact: true,
                children: [
                  _drawerTile(
                    context,
                    HopeV2Icons.workshopSelected,
                    _t(context, 'کاوش فرصت‌ها', 'Explore opportunities'),
                    () {
                      Navigator.pop(context);
                      _selectTab(1);
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  _drawerTile(
                    context,
                    HopeV2Icons.add,
                    _t(context, 'ثبت فرصت جدید', 'Post new opportunity'),
                    () {
                      Navigator.pop(context);
                      _openCreate(context);
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  if (!auth.isGuest)
                    _drawerTile(
                      context,
                      HopeV2Icons.savedSearches,
                      _t(context, 'جست‌وجوهای ذخیره‌شده', 'Saved searches'),
                      () {
                        Navigator.pop(context);
                        Navigator.push(context, HopeRoutes.savedSearches());
                      },
                    ),
                ],
              ),
              if (!auth.isGuest)
                PremiumDomainNavigationGroup(
                  domain: HopeProductDomain.work,
                  compact: true,
                  children: [
                    _drawerTile(
                      context,
                      HopeV2Icons.mission,
                      _t(context, 'درخواست‌های من', 'My applications'),
                      () {
                        Navigator.pop(context);
                        Navigator.push(context, HopeRoutes.myApplications());
                      },
                    ),
                    const Divider(height: 1, indent: 72),
                    _drawerTile(
                      context,
                      HopeV2Icons.featured,
                      _t(context, 'پیشنهادها', 'Offers'),
                      () {
                        Navigator.pop(context);
                        Navigator.push(context, HopeRoutes.offers());
                      },
                    ),
                  ],
                ),
              if (!auth.isGuest)
                PremiumDomainNavigationGroup(
                  domain: HopeProductDomain.intelligence,
                  compact: true,
                  children: [
                    _drawerTile(
                      context,
                      HopeV2Icons.insights,
                      _t(context, 'پروفایل کاری هوشمند', 'AI work profile'),
                      () {
                        Navigator.pop(context);
                        Navigator.push(context, HopeRoutes.recommendationOnboarding());
                      },
                    ),
                  ],
                ),
              if (!auth.isGuest)
                PremiumDomainNavigationGroup(
                  domain: HopeProductDomain.communication,
                  compact: true,
                  children: [
                    _drawerTile(
                      context,
                      HopeV2Icons.notifications,
                      _t(context, 'اعلان‌ها', 'Notifications'),
                      () {
                        Navigator.pop(context);
                        Navigator.push(context, HopeRoutes.notifications());
                      },
                    ),
                  ],
                ),
              if (auth.user?['role'] == 'ADMIN')
                PremiumDomainNavigationGroup(
                  domain: HopeProductDomain.control,
                  compact: true,
                  children: [
                    _drawerTile(
                      context,
                      HopeV2Icons.secure,
                      _t(context, 'مرکز کنترل', 'Control center'),
                      () {
                        Navigator.pop(context);
                        Navigator.push(context, HopeRoutes.adminAccess());
                      },
                    ),
                  ],
                ),
              ListTile(
                leading: const HopeIconTile(HopeV2Icons.translate),
                title: Text(
                  settings.language == 'en' ? 'Language: English' : 'زبان: فارسی',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(_t(context, 'تغییر زبان', 'Change language')),
                onTap: () => settings.setLanguage(settings.language == 'en' ? 'fa' : 'en'),
              ),
              const Divider(height: 26),
              ListTile(
                leading: const HopeIconTile(HopeV2Icons.location),
                title: Text(_t(context, 'موقعیت فعلی', 'Current location')),
                subtitle: Text(settings.city),
                onTap: () { Navigator.pop(context); _selectTab(4); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  Widget _drawerTile(BuildContext context, Object icon, String label, VoidCallback tap) =>
      ListTile(
        leading: HopeIconTile(icon, filled: true, size: 42),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        onTap: tap,
      );

  void _openCreate(BuildContext context) {
    final auth = context.read<AuthController>();
    if (auth.isGuest) {
      _showSignIn(context);
      return;
    }
    Navigator.push(context, HopeRoutes.createJob());
  }
}

Future<void> _resumeCreateAfterAuth(
  BuildContext context, {
  required bool register,
}) async {
  final result = await Navigator.push<AuthReturnIntent?>(
    context,
    register
        ? HopeRoutes.register(returnIntent: AuthReturnIntent.createJob)
        : HopeRoutes.login(returnIntent: AuthReturnIntent.createJob),
  );
  if (!context.mounted ||
      result != AuthReturnIntent.createJob ||
      !context.read<AuthController>().isAuthenticated) {
    return;
  }
  await Navigator.push(context, HopeRoutes.createJob());
}

void _showSignIn(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HopeMark(size: 48),
            const SizedBox(height: 16),
            Text(HopeCopy.of(context).copy_start_here_555e56f, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 7),
            Text(HopeCopy.of(context).copy_create_an_account_or_log_in_to_post_opport_6bc74a1, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                _resumeCreateAfterAuth(context, register: true);
              },
              icon: const HugeIcon(icon: HopeV2Icons.userAdd, size: 21),
              label: Text(HopeCopy.of(context).copy_create_account_bfa3517),
            ),
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                _resumeCreateAfterAuth(context, register: false);
              },
              icon: const HugeIcon(icon: HopeV2Icons.login, size: 21),
              label: Text(HopeCopy.of(context).copy_log_in_b4c960b),
            ),
          ],
        ),
      ),
    ),
  );
}
