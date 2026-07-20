import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/session_state.dart';
import 'package:motorz/core/domain/exceptions/auth_exception.dart';
import 'package:motorz/core/domain/model/device.dart';
import 'package:motorz/core/domain/model/phone_number.dart';
import 'package:motorz/core/domain/model/session.dart';
import 'package:motorz/core/domain/services/auth.repository.dart';
import 'package:motorz/infrastructure/auth/in_memory_auth_repository.dart';
import 'package:motorz/infrastructure/connectivity/connectivity_plus.service.dart';
import 'package:motorz/infrastructure/http/auth_interceptor.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/sync/sync_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Délègue à l'impl mémoire, mais peut faire échouer les demandes d'OTP à la
/// demande — pour rejouer « le renvoi automatique n'est pas parti ».
class _FlakyAuthRepository implements AuthRepository {
  final _inner = InMemoryAuthRepository();
  AuthErrorCode? failRequestWith;
  int requestCount = 0;

  @override
  Future<DateTime> requestOtp(PhoneNumber phone) async {
    requestCount++;
    final code = failRequestWith;
    if (code != null) throw AuthException(code);
    return _inner.requestOtp(phone);
  }

  @override
  Future<Session> verifyOtp({
    required PhoneNumber phone,
    required String code,
    required Device device,
  }) =>
      _inner.verifyOtp(phone: phone, code: code, device: device);
}

void main() {
  late _FlakyAuthRepository auth;

  setUp(() {
    // La session est persistée via `shared_preferences` (cf. sessionRepository) :
    // sans binding ni valeurs simulées, `getInstance()` échoue hors appareil.
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer makeContainer() {
    auth = _FlakyAuthRepository();
    final c = ProviderContainer(overrides: [
      connectivityServiceProvider.overrideWithValue(const AlwaysOnlineConnectivityService()),
      authRepositoryProvider.overrideWithValue(auth),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  /// Ouvre une session (numéro + code de démo), puis remet les compteurs à zéro.
  Future<SessionController> authenticated(ProviderContainer c) async {
    final ctrl = c.read(sessionControllerProvider.notifier);
    await ctrl.requestOtp('0612345678');
    await ctrl.verifyOtp('000000');
    expect(c.read(sessionControllerProvider), isA<Authenticated>());
    auth.requestCount = 0;
    return ctrl;
  }

  /// Joue une requête réelle à travers l'interceptor (Dio + adapter stub) et
  /// renvoie le nombre de signalements « session expirée ». Passer par Dio plutôt
  /// que d'appeler `onError` à la main vérifie aussi que le hook est bien câblé
  /// dans la chaîne d'interceptors.
  Future<int> unauthorizedSignals({
    String path = '/vehicles',
    int status = 401,
    String? code = 'invalid_token',
  }) async {
    var called = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = _StubAdapter(status, code)
      ..interceptors.add(AuthInterceptor(session: () => null, onUnauthorized: () => called++));
    try {
      await dio.get<dynamic>(path);
    } on DioException catch (_) {
      // Attendu : le stub répond en erreur.
    }
    return called;
  }

  group('Expiration de session (401 invalid_token)', () {
    test('renvoie un code au numéro du compte, sans repasser par la saisie', () async {
      final c = makeContainer();
      final ctrl = await authenticated(c);

      await ctrl.expire();

      final state = c.read(sessionControllerProvider);
      expect(state, isA<OtpRequested>(),
          reason: 'le SMS doit partir tout seul → écran de saisie du code');
      expect((state as OtpRequested).reason, OtpReason.sessionExpired,
          reason: "l'écran doit pouvoir expliquer pourquoi on redemande un code");
      expect(state.phone.e164, '+33612345678');
      expect(auth.requestCount, 1);
    });

    test('la session persistée est effacée (pas de restauration du token mort)', () async {
      final c = makeContainer();
      final ctrl = await authenticated(c);

      await ctrl.expire();

      expect(await c.read(sessionRepositoryProvider).read(), isNull);
      expect(c.read(currentSessionProvider), isNull,
          reason: "l'interceptor ne doit plus attacher le token refusé");
    });

    test('les 401 concurrents ne déclenchent qu\'un seul envoi de SMS', () async {
      // Le quota serveur est de 3 demandes / 15 min : une rafale de 401 (push +
      // pull de synchro + écrans ouverts) ne doit pas le brûler.
      final c = makeContainer();
      final ctrl = await authenticated(c);

      await Future.wait([ctrl.expire(), ctrl.expire(), ctrl.expire()]);

      expect(auth.requestCount, 1, reason: 'un seul SMS pour une seule expiration');
      expect(c.read(sessionControllerProvider), isA<OtpRequested>());
    });

    test('si le renvoi échoue, on reste sur l\'écran OTP avec la cause', () async {
      // Quota atteint, réseau coupé, compte supprimé : l'utilisateur ne doit pas
      // attendre un SMS qui n'arrivera jamais.
      final c = makeContainer();
      final ctrl = await authenticated(c);
      auth.failRequestWith = AuthErrorCode.rateLimited;

      await ctrl.expire();

      final state = c.read(sessionControllerProvider);
      expect(state, isA<SessionExpired>());
      expect((state as SessionExpired).error, AuthErrorCode.rateLimited);
      expect(state.phone.e164, '+33612345678',
          reason: 'le numéro reste connu pour le bouton « Réessayer »');
    });

    test('« Réessayer » relance l\'envoi une fois le problème passé', () async {
      final c = makeContainer();
      final ctrl = await authenticated(c);
      auth.failRequestWith = AuthErrorCode.network;
      await ctrl.expire();
      expect(c.read(sessionControllerProvider), isA<SessionExpired>());

      auth.failRequestWith = null;
      await ctrl.retryExpiredOtp();

      expect(c.read(sessionControllerProvider), isA<OtpRequested>());
    });

    test('le code saisi après expiration rouvre bien une session', () async {
      final c = makeContainer();
      final ctrl = await authenticated(c);
      await ctrl.expire();

      await ctrl.verifyOtp('000000');

      expect(c.read(sessionControllerProvider), isA<Authenticated>());
    });

    test('expire() ne fait rien hors session active', () async {
      final c = makeContainer();
      final ctrl = c.read(sessionControllerProvider.notifier);

      await ctrl.expire();

      expect(c.read(sessionControllerProvider), isA<Anonymous>());
      expect(auth.requestCount, 0);
    });
  });

  group('Reconnexion : sort de la file locale', () {
    /// Conteneur en mode serveur (et non `memory`), seul mode où la synchro
    /// tourne — c'est là que la file risquait d'être vidée.
    ({ProviderContainer container, _FakeSyncApi api}) serverContainer() {
      auth = _FlakyAuthRepository();
      final api = _FakeSyncApi();
      final c = ProviderContainer(overrides: [
        connectivityServiceProvider.overrideWithValue(const AlwaysOnlineConnectivityService()),
        authRepositoryProvider.overrideWithValue(auth),
        apiBaseUrlProvider.overrideWith(_FakeApiBaseUrl.new),
        syncApiProvider.overrideWithValue(api),
      ]);
      addTearDown(c.dispose);
      return (container: c, api: api);
    }

    /// Déroule le scénario réel : login, puis saisie locale, puis expiration du
    /// token, puis reconnexion. La saisie doit arriver **après** le login — un
    /// vrai login vide légitimement la file (le compte peut avoir changé).
    Future<void> loginThenExpire(
      ProviderContainer c,
      Future<void> Function() workOffline,
    ) async {
      final ctrl = c.read(sessionControllerProvider.notifier);
      await ctrl.requestOtp('0612345678');
      await ctrl.verifyOtp('000000');
      // `resetToRemote()` est lancé sans await par `_authenticate` : lui laisser
      // le temps de finir, sinon il viderait la file saisie juste après.
      await Future<void>.delayed(Duration.zero);
      await workOffline();
      await ctrl.expire();
      await ctrl.verifyOtp('000000');
      await Future<void>.delayed(Duration.zero);
    }

    Future<void> Function() enqueueFuel(ProviderContainer c) => () => c
        .read(pendingQueueProvider)
        .enqueue('fuel_entries', 'f-1', {
          'id': 'f-1',
          'station': 'Total Nation',
          'updated_at': '2026-05-27T09:00:00Z',
        });

    test('le mode serveur est bien actif (sinon les cas suivants ne prouvent rien)', () {
      final (:container, api: _) = serverContainer();
      expect(isMemoryMode(container.read(apiBaseUrlProvider)), isFalse);
      expect(container.read(syncServiceProvider).enabled, isTrue);
    });

    test('une saisie hors ligne survit à l\'expiration puis à la reconnexion', () async {
      // Le cœur du problème : la reconnexion passait par `resetToRemote()`, qui
      // vide la file — une saisie faite hors ligne juste avant l'expiration
      // disparaissait sans un mot.
      final (:container, :api) = serverContainer();

      await loginThenExpire(container, enqueueFuel(container));

      expect(api.pushed, isNotEmpty, reason: 'la saisie doit finir par partir');
      expect(api.pushed.last['fuel_entries']!.single['station'], 'Total Nation');
    });

    test('une divergence des deux côtés est soumise à l\'arbitrage', () async {
      final (:container, :api) = serverContainer();

      await loginThenExpire(container, () async {
        await enqueueFuel(container)();
        // Pendant la déconnexion, quelqu'un d'autre a modifié le même plein.
        api.serverState = {
          'fuel_entries': [
            {
              'id': 'f-1',
              'station': 'Esso Wagram',
              'updated_at': '2026-05-27T12:00:00Z',
            },
          ],
        };
      });

      final conflicts = container.read(pendingConflictsProvider);
      expect(conflicts, hasLength(1));
      expect(conflicts.single.changedFields, ['station']);
      expect(api.pushed, isEmpty,
          reason: 'rien ne doit partir tant que l\'utilisateur n\'a pas tranché');
    });
  });

  group('AuthInterceptor : détection du token refusé', () {
    test('un 401 invalid_token signale la session expirée', () async {
      expect(await unauthorizedSignals(), 1);
    });

    test('un 401 invalid_otp sur /auth/ ne coupe pas la session', () async {
      // `verify-otp` répond aussi 401 : c'est une faute de frappe sur le code,
      // pas une session morte.
      expect(
        await unauthorizedSignals(path: '/auth/verify-otp', code: 'invalid_otp'),
        0,
      );
    });

    test('un 401 sans code connu ne coupe pas la session', () async {
      expect(await unauthorizedSignals(code: null), 0);
    });

    test('une erreur non-401 est ignorée', () async {
      expect(await unauthorizedSignals(status: 500, code: null), 0);
    });
  });
}

/// Force le mode serveur : en `memory` la synchro est neutralisée et le flux de
/// reconnexion ne s'exécute pas.
class _FakeApiBaseUrl extends ApiBaseUrl {
  @override
  String build() => 'https://api.test';

  @override
  Future<void> load() async {}
}

/// SyncApi fictif : état serveur pilotable, pushes enregistrés.
class _FakeSyncApi extends SyncApi {
  _FakeSyncApi() : super(Dio());

  Map<String, List<Map<String, dynamic>>> serverState = {};
  final List<Map<String, List<Map<String, dynamic>>>> pushed = [];

  @override
  Future<PullResult> pull(String? since) async =>
      PullResult(serverTime: '2026-05-27T00:00:00Z', changes: serverState);

  @override
  Future<PushResult> push(Map<String, List<Map<String, dynamic>>> changes) async {
    pushed.add(changes);
    return const PushResult(rejected: []);
  }
}

/// Répond toujours le même statut/code d'erreur, sans réseau.
class _StubAdapter implements HttpClientAdapter {
  final int statusCode;
  final String? code;

  _StubAdapter(this.statusCode, this.code);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode(code == null
            ? <String, dynamic>{}
            : {
                'error': {'code': code},
              }),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
