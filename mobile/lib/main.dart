import 'dart:async';

import 'package:ankara_proje/app/app.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never hold the first Flutter frame for secure storage or the network.
  // Session restoration notifies the router/providers when it is ready.
  unawaited(apiAuthSession.initialize());
  runApp(const ProviderScope(child: AnkaraServicesApp()));
}
