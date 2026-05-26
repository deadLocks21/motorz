import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:motorz/core/application/session_state.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/ui/pages/auth/otp_verify.page.dart';
import 'package:motorz/ui/pages/auth/phone_entry.page.dart';
import 'package:motorz/ui/pages/garage/garage.page.dart';
import 'package:motorz/ui/pages/settings/settings.page.dart';
import 'package:motorz/ui/pages/vehicle_detail/vehicle_detail.page.dart';
import 'package:motorz/ui/pages/vehicle_form/vehicle_form.page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

abstract final class AppRoutes {
  static const auth = '/auth';
  static const otp = '/auth/otp';
  static const garage = '/';
  static const newVehicle = '/vehicle/new';
  static const settings = '/settings';
  static String vehicle(String id) => '/vehicle/$id';
}

/// Router unique, dont le `redirect` est piloté par [SessionState] et
/// rafraîchi via un `ValueNotifier` bumpé à chaque transition de session.
@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.garage,
    refreshListenable: refresh,
    redirect: (context, goState) {
      final session = ref.read(sessionControllerProvider);
      final loc = goState.matchedLocation;
      return switch (session) {
        Anonymous() => loc == AppRoutes.auth ? null : AppRoutes.auth,
        OtpRequested() => loc == AppRoutes.otp ? null : AppRoutes.otp,
        Authenticated() => loc.startsWith('/auth') ? AppRoutes.garage : null,
      };
    },
    routes: [
      GoRoute(path: AppRoutes.auth, builder: (_, _) => const PhoneEntryPage()),
      GoRoute(path: AppRoutes.otp, builder: (_, _) => const OtpVerifyPage()),
      GoRoute(path: AppRoutes.garage, builder: (_, _) => const GaragePage()),
      GoRoute(path: AppRoutes.settings, builder: (_, _) => const SettingsPage()),
      GoRoute(path: AppRoutes.newVehicle, builder: (_, _) => const VehicleFormPage()),
      GoRoute(
        path: '/vehicle/:id',
        builder: (_, st) => VehicleDetailPage(vehicleId: st.pathParameters['id']!),
      ),
    ],
  );
}
