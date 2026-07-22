import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';

void main() {
  test('le schéma omis est complété — sinon la requête ne sort pas de l\'appareil',
      () {
    expect(ApiBaseUrl.normalize('motorz.dtfh.fr/api'), 'https://motorz.dtfh.fr/api');
  });

  test('le slash final est retiré — il produirait un `//auth/request-otp`', () {
    expect(ApiBaseUrl.normalize('https://motorz.dtfh.fr/api/'), 'https://motorz.dtfh.fr/api');
  });

  test('les espaces de saisie sont rognés', () {
    expect(ApiBaseUrl.normalize('  https://motorz.dtfh.fr/api  '),
        'https://motorz.dtfh.fr/api');
  });

  test('une URL déjà correcte n\'est pas touchée, http compris', () {
    expect(ApiBaseUrl.normalize('http://localhost:3000'), 'http://localhost:3000');
    expect(ApiBaseUrl.normalize('https://motorz.dtfh.fr/api'), 'https://motorz.dtfh.fr/api');
  });

  test('« memory » n\'est pas une URL et traverse intact', () {
    expect(ApiBaseUrl.normalize('memory'), 'memory');
    expect(ApiBaseUrl.normalize(''), '');
  });
}
