import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';
import 'package:motorz/core/domain/model/user.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/services/auth.repository.dart';

/// Auth factice pour le mode local-only (dev/web/tests) : pas de backend, donc
/// le code OTP est toujours `000000` et la session est une démo. Le mode simule
/// néanmoins le provisioning serveur : seuls les numéros de [_allowedPhones]
/// peuvent se connecter ; tout autre numéro est rejeté comme un compte inconnu
/// (`accountNotFound`), exactement comme le ferait le vrai backend.
class InMemoryAuthRepository implements AuthRepository {
  /// Numéros autorisés en mode local-only, en E.164. Ici `06 12 34 56 78`.
  static const _allowedPhones = {'+33612345678'};

  /// Identité **déterministe** du compte démo, stable d'un login à l'autre (un
  /// `UuidValue.generate()` donnerait un propriétaire différent à chaque login,
  /// faisant basculer les véhicules en « partagés »). Le seed de démo rattache
  /// ses données à cet `id` — qui correspond donc à « Mes véhicules ».
  static final _demoUserId = UuidValue.parse('0a5c0000-0000-4000-8000-0000000000ff');

  @override
  Future<DateTime> requestOtp(PhoneNumber phone) async {
    if (!_allowedPhones.contains(phone.e164)) {
      throw const AuthException(AuthErrorCode.accountNotFound);
    }
    return DateTime.now().add(const Duration(minutes: 5));
  }

  @override
  Future<Session> verifyOtp({
    required PhoneNumber phone,
    required String code,
    required Device device,
  }) async {
    if (!_allowedPhones.contains(phone.e164)) {
      throw const AuthException(AuthErrorCode.accountNotFound);
    }
    if (code != '000000') throw const AuthException(AuthErrorCode.invalidOtp);
    return Session(
      jwt: 'dev.jwt.token',
      user: User(
        id: _demoUserId,
        firstName: 'Dev',
        lastName: 'User',
        phoneNumber: phone.e164,
      ),
      device: device,
    );
  }
}
