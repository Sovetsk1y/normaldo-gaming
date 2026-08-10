import 'package:flutter/material.dart';
import 'package:normaldo_gaming/core/config/config.dart';

class ConfigInheritedWidget extends InheritedWidget {
  const ConfigInheritedWidget({
    required this.config,
    required super.child,
    super.key,
  });

  final Config config;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}
