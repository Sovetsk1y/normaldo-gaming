part of '../ng_router.dart';

extension GoRouteExt on BuildContext {
  void goRoute(NGRoutes route, {Object? extra}) {
    go(route.path, extra: extra);
  }
}
