import 'package:equatable/equatable.dart';

class Area extends Equatable {
  const Area({required this.id, required this.name, this.isActive = true, this.customerCount});

  final String id;
  final String name;
  final bool isActive;

  /// Only populated by the management screen.
  final int? customerCount;

  Area copyWith({String? name, bool? isActive}) =>
      Area(id: id, name: name ?? this.name, isActive: isActive ?? this.isActive, customerCount: customerCount);

  @override
  List<Object?> get props => [id, name, isActive, customerCount];
}
