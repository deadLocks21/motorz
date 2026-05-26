import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';
import 'package:motorz/core/domain/model/user.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/services/auth.repository.dart';

/// Auth factice pour le mode local-only (dev/web/tests) : pas de backend ni de
/// provisioning, donc tout numéro se connecte avec le code `000000` et ouvre
/// une session de démo. L'inscription self-service n'existe pas côté app.
class InMemoryAuthRepository implements AuthRepository {
  @override
  Future<DateTime> requestOtp(PhoneNumber phone) async {
    return DateTime.now().add(const Duration(minutes: 5));
  }

  @override
  Future<Session> verifyOtp({
    required PhoneNumber phone,
    required String code,
    required Device device,
  }) async {
    if (code != '000000') throw const AuthException(AuthErrorCode.invalidOtp);
    return Session(
      jwt: 'dev.jwt.token',
      user: User(
        id: UuidValue.generate(),
        firstName: 'Dev',
        lastName: 'User',
        phoneNumber: phone.e164,
      ),
      device: device,
    );
  }
}
