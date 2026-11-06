part of 'home_page.dart';


Widget buildResponsiveHomeFeed(
  BuildContext context,
  VoidCallback onOpenExplore,
  VoidCallback onOpenMenu,
  VoidCallback onOpenCreate,
) =>
    HopeResponsive(
      child: PremiumHomeFeed(
        onOpenExplore: onOpenExplore,
        onOpenMenu: onOpenMenu,
        onOpenCreate: onOpenCreate,
      ),
    );

extension _HomePageScaffold on _HomePageState {
  Widget _buildHomeScaffold(BuildContext context) {
    final auth = context.watch<AuthController>();
    final settings = context.watch<HopeSettingsController>();
    final isDesktop = MediaQuery.sizeOf(context).width >= HopeV2Breakpoints.medium;
    final destinations = [
      NavigationDestination(
        icon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-home'),
          icon: HopeV2NavigationIcons.home,
          selected: false,
        ),
        selectedIcon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-home-selected'),
          icon: HopeV2NavigationIcons.homeSelected,
          selected: true,
        ),
        label: _t(context, 'خانه', 'Home'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-explore'),
          icon: HopeV2NavigationIcons.explore,
          selected: false,
        ),
        selectedIcon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-explore-selected'),
          icon: HopeV2NavigationIcons.exploreSelected,
          selected: true,
        ),
        label: _t(context, 'کاوش', 'Explore'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-work'),
          icon: HopeV2NavigationIcons.workshop,
          selected: false,
        ),
        selectedIcon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-work-selected'),
          icon: HopeV2NavigationIcons.workshopSelected,
          selected: true,
        ),
        label: _t(context, 'کارگاه', 'Workshop'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-wallet'),
          icon: HopeV2NavigationIcons.wallet,
          selected: false,
        ),
        selectedIcon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-wallet-selected'),
          icon: HopeV2NavigationIcons.walletSelected,
          selected: true,
        ),
        label: _t(context, 'کیف پول', 'Wallet'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-profile'),
          icon: HopeV2NavigationIcons.profile,
          selected: false,
        ),
        selectedIcon: const HopeNavigationGlyph(
          key: ValueKey('hope-nav-profile-selected'),
          icon: HopeV2NavigationIcons.profileSelected,
          selected: true,
        ),
        label: _t(context, 'پروفایل', 'Profile'),
      ),
    ];

    final content = PageView.builder(
      key: const ValueKey('hope-tab-pager'),
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) => _KeepAliveTab(
        key: ValueKey('hope-tab-keepalive-$index'),
        active: index == tab,
        builder: () => AnimatedBuilder(
          animation: _pageController,
          child: _buildTab(index),
          builder: (context, child) {
            final page = _pageController.hasClients
                ? (_pageController.page ?? _pageController.initialPage.toDouble())
                : _pageController.initialPage.toDouble();
            final distance = (page - index).abs().clamp(0.0, 1.0).toDouble();
            return Opacity(
              opacity: 1.0 - distance * .12,
              child: Transform.scale(
                scale: 1.0 - distance * .025,
                alignment: Alignment.topCenter,
                child: child,
              ),
            );
          },
        ),
      ),
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
                    HopeV2Icons.workshop,
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
                      HopeV2Icons.message,
                      _t(context, 'گفتگوها', 'Chats'),
                      () {
                        Navigator.pop(context);
                        Navigator.push(context, HopeRoutes.chats());
                      },
                    ),
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
}
