import 'package:flutter/material.dart';
import 'package:arsenal/services/auth_services.dart';
import 'package:arsenal/Screens/login_screen.dart';
import 'package:arsenal/home/home_screen.dart';
import 'package:arsenal/Shared/loading.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthServices();

    return StreamBuilder(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Loading();
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
