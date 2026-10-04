import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_fields.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/l10n.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';
import '../domain/user_management.dart';

class UsersState extends Equatable {
  const UsersState({this.users = const [], this.loading = true, this.failure});

  final List<AppUser> users;
  final bool loading;
  final Failure? failure;

  @override
  List<Object?> get props => [users, loading, failure];
}

class UsersCubit extends Cubit<UsersState> {
  UsersCubit({required ListUsers list, required ChangeUserAccess change, required InviteUser invite})
    : _list = list,
      _change = change,
      _invite = invite,
      super(const UsersState());

  final ListUsers _list;
  final ChangeUserAccess _change;
  final InviteUser _invite;

  Future<void> load() async {
    emit(UsersState(users: state.users));
    final result = await _list();
    if (isClosed) return;
    emit(
      result.fold(
        (f) => UsersState(users: state.users, loading: false, failure: f),
        (users) => UsersState(users: users, loading: false),
      ),
    );
  }

  Future<Failure?> change(AppUser actor, AppUser target, {UserRole? role, bool? active}) async {
    final result = await _change(actor: actor, target: target, role: role, active: active);
    if (isClosed) return null;
    if (result.valueOrNull case final updated?) {
      emit(UsersState(users: [for (final u in state.users) u.id == updated.id ? updated : u], loading: false));
    }
    return result.failureOrNull;
  }

  Future<Failure?> invite({required String email, required String fullName, required UserRole role}) async {
    final result = await _invite(email: email, fullName: fullName, role: role);
    if (result.isSuccess) await load();
    return result.failureOrNull;
  }
}

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = context.watch<AuthCubit>().user!;
    return BlocBuilder<UsersCubit, UsersState>(
      builder: (context, state) {
        final cubit = context.read<UsersCubit>();
        return Scaffold(
          appBar: AppBar(title: Text(l.usersTitle)),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'users-fab',
            onPressed: () => _invite(context),
            icon: const Icon(Icons.person_add_alt_rounded),
            label: Text(l.inviteUser),
          ),
          body: RefreshIndicator(
            onRefresh: cubit.load,
            child: switch (state) {
              UsersState(loading: true, users: []) => const LoadingView(),
              UsersState(users: [], :final failure?) => ListView(
                children: [ErrorView(failure: failure, onRetry: cubit.load)],
              ),
              _ => ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 96),
                itemCount: state.users.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) {
                  final u = state.users[i];
                  final isMe = u.id == me.id;
                  return Card(
                    child: ListTile(
                      minTileHeight: 72,
                      leading: InitialsAvatar(u.fullName),
                      title: Text(isMe ? '${u.fullName} (${l.userYou})' : u.fullName),
                      subtitle: Text(u.email),
                      trailing: Wrap(
                        spacing: AppSpacing.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusChip(label: u.isAdmin ? l.roleAdmin : l.roleStaff),
                          if (!u.isActive)
                            StatusChip(
                              label: l.commonInactive,
                              color: AppColors.textSecondary,
                              background: AppColors.surfaceMuted,
                            ),
                          if (!isMe)
                            PopupMenuButton<String>(
                              onSelected: (action) => _act(context, me, u, action),
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'role', child: Text(u.isAdmin ? l.makeStaff : l.makeAdmin)),
                                PopupMenuItem(
                                  value: 'active',
                                  child: Text(u.isActive ? l.commonDeactivate : l.commonActivate),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            },
          ),
        );
      },
    );
  }

  Future<void> _act(BuildContext context, AppUser me, AppUser target, String action) async {
    final l = context.l10n;
    final cubit = context.read<UsersCubit>();
    if (action == 'active' && target.isActive) {
      final ok = await context.confirm(
        title: l.commonDeactivate,
        message: l.userDeactivateConfirm(target.fullName),
        confirmLabel: l.commonDeactivate,
        destructive: true,
      );
      if (!ok) return;
    }
    final failure = action == 'role'
        ? await cubit.change(me, target, role: target.isAdmin ? UserRole.staff : UserRole.admin)
        : await cubit.change(me, target, active: !target.isActive);
    if (!context.mounted) return;
    if (failure != null) {
      context.showFailure(failure);
    } else {
      context.showSuccess(l.userUpdated);
    }
  }

  Future<void> _invite(BuildContext context) async {
    final cubit = context.read<UsersCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(value: cubit, child: const _InviteSheet()),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet();

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  UserRole _role = UserRole.staff;
  bool _sending = false;
  Failure? _failure;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _failure = null;
    });
    final failure = await context.read<UsersCubit>().invite(email: _email.text, fullName: _name.text, role: _role);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _failure = failure;
    });
    if (failure == null) {
      context.showSuccess(context.l10n.inviteSent(_email.text.trim()));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.inviteUser, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if (_failure != null && _failure is! ValidationFailure) ...[
              InlineBanner.error(message: context.failureMessage(_failure!)),
              const SizedBox(height: AppSpacing.md),
            ],
            AppTextField(
              controller: _name,
              label: l.profileName,
              autofocus: true,
              errorText: context.fieldError(_failure, 'fullName'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _email,
              label: l.loginEmail,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              errorText: context.fieldError(_failure, 'email'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l.inviteRole, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<UserRole>(
              segments: [
                ButtonSegment(value: UserRole.staff, label: Text(l.roleStaff)),
                ButtonSegment(value: UserRole.admin, label: Text(l.roleAdmin)),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: l.inviteUser, loading: _sending, onPressed: _send),
          ],
        ),
      ),
    );
  }
}
