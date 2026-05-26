import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/user.dart';

/// Session authentifiée persistée (`flutter_secure_storage`).
class Session {
  final String jwt;
  final User user;
  final Device device;

  const Session({required this.jwt, required this.user, required this.device});

  Session copyWith({String? jwt, User? user, Device? device}) =>
      Session(jwt: jwt ?? this.jwt, user: user ?? this.user, device: device ?? this.device);
}
