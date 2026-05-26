import 'package:motorz/core/domain/model/uuid_value.dart';

/// Compte individuel. Identifié par son numéro de téléphone (OTP).
class User {
  final UuidValue id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final bool isAdmin;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.isAdmin = false,
  }) : assert(firstName.trim().isNotEmpty, 'firstName cannot be empty');

  String get fullName => '$firstName $lastName'.trim();
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return (f + l).toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
