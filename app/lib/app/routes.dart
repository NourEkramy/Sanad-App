/// Route paths in one place so navigation never relies on string literals.
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  static const home = '/home';
  static const customers = '/customers';
  static const records = '/records';
  static const more = '/more';

  /// Phone search. `?for=record` selects a customer for a new record.
  static const search = '/search';
  static String searchForRecord() => '$search?for=record';

  static String newCustomer({String? phone, bool thenRecord = false}) => Uri(
    path: '/customers/new',
    queryParameters: {if (phone != null && phone.isNotEmpty) 'phone': phone, if (thenRecord) 'next': 'record'},
  ).toString();
  static String customer(String id) => '/customers/$id';
  static String customerSaved(String id) => '/customers/$id/saved';
  static String editCustomer(String id) => '/customers/$id/edit';

  /// [thenProfile]: after saving, show the customer's profile (and its
  /// updated history) instead of returning to the previous screen.
  static String addRecord(String customerId, {bool thenProfile = false}) =>
      '/customers/$customerId/records/new${thenProfile ? '?then=profile' : ''}';

  static String record(String id) => '/records/$id';
  static String editRecord(String id) => '/records/$id/edit';

  static const nurses = '/more/nurses';
  static const services = '/more/services';
  static const areas = '/more/areas';
  static const import = '/more/import';
  static const export = '/more/export';
  static const settings = '/more/settings';
  static const profile = '/more/profile';
  static const users = '/more/users';
  static const pendingSync = '/more/pending';
}
