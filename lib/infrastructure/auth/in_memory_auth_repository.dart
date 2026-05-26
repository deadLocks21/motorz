import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';
import 'package:motorz/core/domain/model/user.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/services/auth.repository.dart';

/// Auth factice (dev/web/tests) : code `000000`, inscription si prénom fourni.
class InMemoryAuthRepository implements AuthRepository {
  final Set<String> _knownPhones;
  InMemoryAuthRepository({Set<String>? knownPhones}) : _knownPhones = knownPhones ?? {};

  @override
  Future<OtpRequestResult> requestOtp(PhoneNumber phone) async {
    return OtpRequestResult(
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      isNewUser: !_knownPhones.contains(phone.e164),
    );
  }

  @override
  Future<Session> verifyOtp({
    required PhoneNumber phone,
    required String code,
    required Device device,
    String? firstName,
    String? lastName,
  }) async {
    if (code != '000000') throw const AuthException(AuthErrorCode.invalidOtp);
    final isNew = !_knownPhones.contains(phone.e164);
    if (isNew && (firstName == null || lastName == null)) {
      throw const AuthException(AuthErrorCode.registrationRequired);
    }
    _knownPhones.add(phone.e164);
    return Session(
      jwt: 'dev.jwt.token',
      user: User(
        id: UuidValue.generate(),
        firstName: firstName ?? 'Dev',
        lastName: lastName ?? 'User',
        phoneNumber: phone.e164,
      ),
      device: device,
    );
  }
}
