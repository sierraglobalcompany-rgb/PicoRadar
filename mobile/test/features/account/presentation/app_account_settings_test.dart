import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/account/data/app_account_client.dart';
import 'package:picoradar/features/account/data/app_account_config.dart';
import 'package:picoradar/features/account/presentation/app_account_settings.dart';

void main() {
  testWidgets('shows server-confirmed Free and preserves optional account use', (
    tester,
  ) async {
    final client = _AccountClient(_profile(
      plan: AppAccountPlan.free,
      planStatus: AppAccountEntitlementStatus.active,
      accountStatus: AppAccountStatus.active,
    ));

    await tester.pumpWidget(_app(client));
    await tester.tap(find.byKey(const ValueKey('account-restore-session')));
    await tester.pumpAndSettle();

    expect(find.text('Plan Free'), findsOneWidget);
    expect(find.text('Cuenta activa'), findsOneWidget);
    expect(find.textContaining('La cuenta es opcional'), findsOneWidget);
    expect(find.textContaining('vehículos y documentos permanecen'), findsOneWidget);
  });

  testWidgets('shows expired Pro as informational for an active account', (
    tester,
  ) async {
    final client = _AccountClient(_profile(
      plan: AppAccountPlan.pro,
      planStatus: AppAccountEntitlementStatus.expired,
      accountStatus: AppAccountStatus.active,
    ));

    await tester.pumpWidget(_app(client));
    await tester.tap(find.byKey(const ValueKey('account-restore-session')));
    await tester.pumpAndSettle();

    expect(find.text('Plan Pro sin vigencia confirmada'), findsOneWidget);
    expect(find.textContaining('La vigencia Pro terminó'), findsOneWidget);
  });

  testWidgets('unknown account status exposes only suppression actions', (tester) async {
    final client = _AccountClient(_profile(
      plan: AppAccountPlan.pro,
      planStatus: AppAccountEntitlementStatus.active,
      accountStatus: AppAccountStatus.unknown,
    ));

    await tester.pumpWidget(_app(client));
    await tester.tap(find.byKey(const ValueKey('account-restore-session')));
    await tester.pumpAndSettle();

    expect(find.text('Estado de cuenta sin confirmar'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-delete')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('account-reverify-suppression')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('account-name')), findsNothing);
    expect(find.byKey(const ValueKey('account-marketing-consent')), findsNothing);
  });
}

Widget _app(_AccountClient client) => ProviderScope(
  overrides: [
    appAccountConfigProvider.overrideWithValue(
      const AppAccountConfig(
        enabled: true,
        emailEnabled: true,
        apiBaseUrl: 'https://api.example.test',
        privacyUrl: 'https://example.test/privacy',
        privacyVersion: 'v1',
      ),
    ),
    appAccountClientProvider.overrideWithValue(client),
  ],
  child: const MaterialApp(home: Scaffold(body: AppAccountSettingsSection())),
);

AppAccountProfile _profile({
  required AppAccountPlan plan,
  required AppAccountEntitlementStatus planStatus,
  required AppAccountStatus accountStatus,
}) => AppAccountProfile(
  id: 'synthetic-id',
  name: '',
  email: 'person@example.test',
  phone: '',
  municipality: '',
  categories: const [],
  privacyVersion: 'v1',
  marketingConsent: false,
  accountStatus: accountStatus,
  entitlement: AppAccountEntitlement(
    plan: plan,
    status: planStatus,
    validFrom: DateTime.utc(2026, 11, 1),
    validUntil: DateTime.utc(2026, 11, 20),
    source: plan == AppAccountPlan.pro ? 'operator_grant' : 'default_free',
  ),
);

class _AccountClient implements AppAccountClient {
  _AccountClient(this.profile);

  final AppAccountProfile profile;

  @override
  Future<AppAccountProfile> loadProfile() async => profile;

  @override
  Future<void> requestOtp(String email, {required bool privacyAccepted}) async {}

  @override
  Future<AppAccountProfile> verifyOtp(String email, String code) async =>
      profile;

  @override
  Future<AppAccountProfile> updateProfile({
    required String name,
    required String phone,
    required String municipality,
    required List<String> categories,
  }) async => profile;

  @override
  Future<bool> updateMarketing(bool accepted) async => accepted;

  @override
  Future<void> logout() async {}

  @override
  Future<void> suppress() async {}

  @override
  Future<void> discardSuppressionToken() async {}
}
