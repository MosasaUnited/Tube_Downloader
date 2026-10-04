import 'package:tube_downloader/core/app_bootstrap.dart';
import 'package:tube_downloader/core/configs/app_config.dart';

Future<void> main() => bootstrapAndRun(const AppConfig.production());
