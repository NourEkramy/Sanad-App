import 'package:equatable/equatable.dart';

enum UserRole {
  admin,
  staff;

  static UserRole fromJson(String? value) => value == 'admin' ? UserRole.admin : UserRole.staff;
}

/// Everything a user can do in the app. Screens and actions check a
/// [Permission] rather than a role, so adding a role (e.g. "accountant")
/// only means extending [RolePermissions].
enum Permission {
  searchCustomers,
  createCustomers,
  editCustomers,
  archiveCustomers,
  createRecords,
  editRecords,
  archiveRecords,
  viewRecords,
  createReferenceData,
  manageReferenceData,
  exportData,
  importData,
  manageUsers,
}

abstract final class RolePermissions {
  static const Map<UserRole, Set<Permission>> grants = {
    UserRole.admin: {...Permission.values},
    UserRole.staff: {
      Permission.searchCustomers,
      Permission.createCustomers,
      Permission.createRecords,
      Permission.viewRecords,
      Permission.createReferenceData,
    },
  };

  static bool allows(UserRole role, Permission permission) => grants[role]?.contains(permission) ?? false;
}

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final bool isActive;
  final DateTime? createdAt;

  bool can(Permission permission) => isActive && RolePermissions.allows(role, permission);

  bool get isAdmin => role == UserRole.admin;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters(1);
    return parts.first.characters(1) + parts.last.characters(1);
  }

  AppUser copyWith({String? fullName, UserRole? role, bool? isActive}) => AppUser(
        id: id,
        email: email,
        fullName: fullName ?? this.fullName,
        role: role ?? this.role,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, email, fullName, role, isActive, createdAt];
}

extension on String {
  String characters(int n) => String.fromCharCodes(runes.take(n)).toUpperCase();
}
