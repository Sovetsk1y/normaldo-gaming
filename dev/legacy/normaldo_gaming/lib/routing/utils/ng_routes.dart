part of '../ng_router.dart';

enum NGRoutes {
  root('/'),
  main('/main'),
  signIn('/signUp/signIn'),
  signUp('/signUp'),
  pullUpGame('/main/pullUpGame'),
  missions('/main/missions'),
  settings('/main/settings'),
  shop('/main/shop'),
  slots('/main/slots'),
  knowledgeBook('/main/knowledge'),
  basement('/main/base');

  const NGRoutes(this.path);

  final String path;
}
