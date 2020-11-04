import 'package:flutter/widgets.dart';
import 'package:platform_info/platform_info.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart';

import 'locator.dart';
import 'models/setup_icon.dart';
import 'models/upload_file.dart';
import 'models/user_interface.dart';
import 'ui/app_appearance.dart';

//TODO Add accesibility and semantic labels.
//TODO Migrate to null-safety when it's become stable.
void main() {
  if (!platform.isWeb && platform.isDesktop) {
    WidgetsFlutterBinding.ensureInitialized();
    setWindowTitle('Flutter Launcher Icon Preview');
    setWindowMinSize(const Size(320, 840));
  }
  UserInterface.setupUI();
  setupLocator();
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider<UserInterface>(create: (_) => UserInterface()),
    ChangeNotifierProvider<UploadFile>(create: (_) => UploadFile()),
    ChangeNotifierProxyProvider<UploadFile, SetupIcon>(
      create: (_) => SetupIcon(),
      update: (_, _file, _icon) => _icon
        ..foregroundErrorCodes = _file.foregroundIssues
        ..backgroundErrorCodes = _file.backgroundIssues
        ..iconErrorCodes = _file.iconIssues
        ..adaptiveForeground = _file.recivedForeground
        ..adaptiveBackground = _file.recivedBackground
        ..regularIcon = _file.recivedIcon,
    ),
  ], child: const MyApp()));
}
