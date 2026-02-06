import 'package:flutter/material.dart';
import 'package:telegramflutter/pages/login_page.dart';
import 'package:telegramflutter/theme/colors.dart';

void main() {
  runApp(const TelegramApp());
}

class TelegramApp extends StatelessWidget {
  const TelegramApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme = AppTheme();
    return ListenableBuilder(
      listenable: appTheme,
      builder: (context, _) {
        return MaterialApp(
          title: 'Telegram Flutter',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appTheme.themeMode,
          home: const LoginPage(),
        );
      },
    );
  }
}
