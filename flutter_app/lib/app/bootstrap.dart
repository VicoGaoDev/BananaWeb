import 'package:flutter/widgets.dart';

void bootstrap(Widget Function() builder) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(builder());
}
