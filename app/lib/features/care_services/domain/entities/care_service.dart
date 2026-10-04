import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

/// A service the team provides (named `CareService` to avoid confusion with
/// technical "services").
class CareService extends Equatable {
  const CareService({required this.id, required this.name, this.defaultPrice, this.isActive = true});

  final String id;
  final String name;

  /// Suggested price; null means the price varies per visit.
  final Money? defaultPrice;
  final bool isActive;

  CareService copyWith({String? name, Money? defaultPrice, bool clearPrice = false, bool? isActive}) => CareService(
        id: id,
        name: name ?? this.name,
        defaultPrice: clearPrice ? null : (defaultPrice ?? this.defaultPrice),
        isActive: isActive ?? this.isActive,
      );

  @override
  List<Object?> get props => [id, name, defaultPrice, isActive];
}
