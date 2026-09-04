import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeparty/core/policy/agency_host_policy.dart';
import 'package:zeparty/core/policy/live_host_policy.dart';
import 'package:zeparty/providers/agency_provider.dart';
import 'package:zeparty/providers/live_host_provider.dart';
import 'package:zeparty/models/live_host_application_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modules 11, 12, 13, 14 & 15 Feature Tests', () {
    late AgencyProvider agencyProvider;
    late LiveHostProvider liveHostProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      agencyProvider = AgencyProvider();
      liveHostProvider = LiveHostProvider();
    });

    test('Verify Module 14 Shared Agency Host Policy Calculations (Levels 1-25)', () {
      // Level 1: 25k diamonds, 10 valid days, $2.00 Total ($1.60 Host, $0.40 Agency)
      final lvl1 = AgencyHostPolicy.getLevelForDiamonds(25000);
      expect(lvl1.level, 1);
      expect(lvl1.validDaysRequired, 10);
      expect(lvl1.basicTotalSalaryUsd, 2.0);
      expect(lvl1.hostBasicSalaryUsd, 1.60);
      expect(lvl1.agencySalaryUsd, 0.40);

      // Level 5: 500k diamonds, 8 valid days, $40.00 Total ($32 Host, $8 Agency)
      final lvl5 = AgencyHostPolicy.getLevelForDiamonds(500000);
      expect(lvl5.level, 5);
      expect(lvl5.validDaysRequired, 8);
      expect(lvl5.hostBasicSalaryUsd, 32.0);
      expect(lvl5.agencySalaryUsd, 8.0);

      // Level 25: 50M diamonds, 5 valid days, $4000.00 Total ($3200 Host, $800 Agency)
      final lvl25 = AgencyHostPolicy.getLevelForDiamonds(50000000);
      expect(lvl25.level, 25);
      expect(lvl25.validDaysRequired, 5);
      expect(lvl25.hostBasicSalaryUsd, 3200.0);
      expect(lvl25.agencySalaryUsd, 800.0);

      // Audio Host daily requirement = 2 hours (120 mins) online & unmuted
      expect(AgencyHostPolicy.requiredAudioHostDailyMinutes, 120);
    });

    test('Verify Module 12 Agency Wallet Settlement & Member Management', () {
      // 1. Check initial balances
      expect(agencyProvider.userAgency, isNotNull);
      expect(agencyProvider.userAgency!.pendingBalanceUsd, 284.0);

      // 2. Idempotent 15-day Cycle Settlement
      final settled = agencyProvider.settle15DayCycle(cycleId: 'cycle_test_101', actorUserId: 'user_1001');
      expect(settled, true);
      expect(agencyProvider.userAgency!.pendingBalanceUsd, 0.0);
      expect(agencyProvider.userAgency!.availableBalanceUsd, 1420.50 + 284.0);

      // 3. Member Removal with Reason Logging
      final removed = agencyProvider.removeMember(memberUserId: 'user_1004', reason: 'Contract Expired', actorUserId: 'user_1001');
      expect(removed, true);
      expect(agencyProvider.members.firstWhere((m) => m.userId == 'user_1004').status, 'Removed');
      expect(agencyProvider.auditLogs.any((a) => a['action'] == 'REMOVE_MEMBER'), true);
    });

    test('Verify Module 15 Direct Live Host Registration Policy & Direct Payouts', () {
      // Level 1: 25k diamonds, 10 valid days, $2.00 Direct Salary USD (No agency deduction)
      final lvl1 = LiveHostPolicy.getLevelForDiamonds(25000);
      expect(lvl1.level, 1);
      expect(lvl1.validDaysRequired, 10);
      expect(lvl1.basicSalaryUsd, 2.0);

      // Level 25: 50M diamonds, 5 valid days, $4000.00 Direct Salary USD
      final lvl25 = LiveHostPolicy.getLevelForDiamonds(50000000);
      expect(lvl25.level, 25);
      expect(lvl25.validDaysRequired, 5);
      expect(lvl25.basicSalaryUsd, 4000.0);

      // Direct Live Host daily requirement = 1 verified live streaming hour (60 mins)
      expect(LiveHostPolicy.requiredLiveHostDailyMinutes, 60);

      // Application Submission
      final app = LiveHostApplicationModel(
        id: 'app_test_55',
        userId: 'user_9999',
        legalName: 'New Live Host',
        displayName: 'Live Host 9999',
        dateOfBirth: '2000-01-01',
        gender: 'Female',
        country: 'GLOBAL',
        city: 'Metropolis',
        languages: 'English',
        category: 'Gaming',
        schedule: 'Daily 18:00',
        phoneOrEmail: '+199999999',
        govIdType: 'Passport',
        govIdNumber: 'PASS-12345',
        frontIdUrl: 'front.jpg',
        backIdUrl: 'back.jpg',
        selfieUrl: 'selfie.jpg',
        status: 'Submitted',
        submittedAt: DateTime.now(),
      );

      final msg = liveHostProvider.submitApplication(app);
      expect(msg, contains('submitted successfully'));
      expect(liveHostProvider.applications.any((a) => a.userId == 'user_9999'), true);
    });

    test('Verify Module 15 Direct Live Host 1-Hour Streaming Daily Requirement Tracking', () {
      expect(liveHostProvider.activeLiveHost, isNotNull);
      final initialValidDays = liveHostProvider.activeLiveHost!.completedValidDays;

      // Add 60 mins live streaming time
      liveHostProvider.addLiveStreamingMinutes(60);
      expect(liveHostProvider.activeLiveHost!.isTodayValid, true);
      expect(liveHostProvider.activeLiveHost!.completedValidDays, initialValidDays);
    });
  });
}
