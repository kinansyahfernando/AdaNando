import 'package:mobile_app/app/app.dart';
import 'package:mobile_app/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
