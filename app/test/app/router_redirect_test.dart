import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/app/router.dart';
import 'package:sanad/app/routes.dart';
import 'package:sanad/features/auth/domain/entities/app_user.dart';
import 'package:sanad/features/auth/domain/repositories/auth_repository.dart';

void main() {
  const staff = Authenticated(AppUser(id: 's', email: 's@x.eg', fullName: 'Staff', role: UserRole.staff));
  const admin = Authenticated(AppUser(id: 'a', email: 'a@x.eg', fullName: 'Admin', role: UserRole.admin));

  String? go(AuthStatus? status, String location) {
    final uri = Uri.parse(location);
    return authRedirect(status, uri, uri.path);
  }

  test('a deep link survives the splash screen', () {
    final toSplash = go(null, '/more/settings');
    expect(toSplash, '/splash?from=%2Fmore%2Fsettings');
    expect(go(staff, toSplash!), '/more/settings');
  });

  test('a deep link survives signing in', () {
    final toLogin = go(const Unauthenticated(), '/customers/c1');
    expect(toLogin, '/login?from=%2Fcustomers%2Fc1');
    expect(go(staff, toLogin!), '/customers/c1');
  });

  test('signed-in users never see the entry screens', () {
    expect(go(staff, Routes.login), Routes.home);
    expect(go(staff, Routes.splash), Routes.home);
    expect(go(staff, '${Routes.login}?from=%2Flogin'), Routes.home, reason: 'no redirect loops');
  });

  test('signed-out users only see public screens', () {
    expect(go(const Unauthenticated(), Routes.forgotPassword), isNull);
    expect(go(const Unauthenticated(), Routes.home), startsWith(Routes.login));
  });

  test('password recovery forces the reset screen', () {
    expect(go(const PasswordRecovery(), Routes.home), Routes.resetPassword);
    expect(go(const PasswordRecovery(), Routes.resetPassword), isNull);
  });

  test('admin-only screens are guarded by permission', () {
    expect(go(staff, Routes.import), Routes.more);
    expect(go(staff, Routes.export), Routes.more);
    expect(go(staff, Routes.users), Routes.more);
    expect(go(staff, Routes.editCustomer('c1')), Routes.home);
    expect(go(admin, Routes.import), isNull);
    expect(go(admin, Routes.users), isNull);
    expect(go(staff, Routes.nurses), isNull);
  });
}
