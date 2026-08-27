import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_data.dart';
import 'services/local_database.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.instance.init();

  runApp(const PharmaFodyApp());
}

class PharmaFodyApp extends StatelessWidget {
  const PharmaFodyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppData(),
      child: Consumer<AppData>(
        builder: (context, data, _) {
          return MaterialApp(
            title: 'PharmaFody',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: data.themeMode,
            home: data.isAuthenticated ? const AppShell() : const LoginScreen(),
          );
        },
      ),
    );
  }
}
