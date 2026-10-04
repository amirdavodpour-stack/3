        createdAt: '2026-09-21T06:00:00Z',
        readAt: '2026-09-21T07:00:00Z',
      );

  @override
  Future<int> markAllRead() async => 0;

  @override
  Future<HopeNotificationPreferences> getPreferences() async =>
      const HopeNotificationPreferences(
        inApp: true,
        push: true,
        email: false,
        jobAlerts: true,
        applicationUpdates: true,
        paymentUpdates: true,
        marketing: false,
      );

  @override
  Future<HopeNotificationPreferences> updatePreferences(
    Map<String, bool> patch,
  ) async =>
      getPreferences();

  @override
  Future<List<HopeNotificationDevice>> listDevices() async => const [
        HopeNotificationDevice(
          id: 'device-1',
          platform: 'ANDROID',
          enabled: true,
        ),
      ];

  @override
  Future<void> disableDevice(String id) async {}
}

HopeJob _jobFixture() => HopeJob.fromMap({
      'id': 'job-runtime-1',
      'title': 'طراحی رابط موبایل حرفه‌ای',
      'description':
          'بازطراحی یک اپلیکیشن موبایل با تمرکز بر تجربه کاربری، دسترس‌پذیری و عملکرد.',
      'categoryId': 'cat-1',
      'category': 'Software',
      'jobType': 'FIXED',
      'budgetType': 'FIXED',
      'budgetMin': '1500000',
      'budgetMax': '2500000',
      'duration': '8 روز',
      'acceptanceCriteria': 'تحویل نسخه نهایی و تست‌شده',
      'status': 'PUBLISHED',
      'ownerId': 'runtime-owner',
      'providerId': null,
      'city': 'تهران',
      'kind': 'MISSION',
      'visibility': 'PUBLIC',
      'schedule': 'FULL_TIME',
      'offerCount': 4,
      'isOwner': false,
      'isRecommended': true,
      'recommendationScore': 94,
      'recommendationReasons': [
        'SKILL_MATCH',
        'WORK_MODE_MATCH',
        'CATEGORY_MATCH',
      ],
      'recommendationComponents': {
        'skills': 96,
        'category': 100,
        'location': 88,
        'salary': 82,
      },
      // Runtime-only editorial fixture media. This is not product data; it exists
      // to certify the real media branch against the canonical visual target.
      'imageUrl':
          'https://images.unsplash.com/photo-1758876022836-70b89d3e6944?auto=format&fit=crop&fm=jpg&q=60&w=1200',
      'aiRecommendationConfidence': 0.92,
    });
