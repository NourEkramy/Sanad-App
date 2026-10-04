import 'package:equatable/equatable.dart';

class Nurse extends Equatable {
  const Nurse({required this.id, required this.name, this.phone, this.isActive = true, this.notes});

  final String id;
  final String name;
  final String? phone;
  final bool isActive;
  final String? notes;

  Nurse copyWith({String? name, String? phone, bool? isActive, String? notes, bool clearPhone = false}) => Nurse(
        id: id,
        name: name ?? this.name,
        phone: clearPhone ? null : (phone ?? this.phone),
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
      );

  @override
  List<Object?> get props => [id, name, phone, isActive, notes];
}
