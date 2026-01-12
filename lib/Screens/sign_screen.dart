import 'package:flutter/material.dart';
import 'package:arsenal/Shared/loading.dart';
import 'package:arsenal/services/auth_services.dart';
import 'package:arsenal/Shared/chamfer_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final AuthServices _auth = AuthServices();

  bool _isLoading = false;

  Future<void> _signup() async {
    if (_passwordController.text != _confirmController.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.createAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pop(context); // Back to Login → AuthWrapper handles rest
    } catch (e) {
      _showError(e.toString());
    }

    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black,
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Loading();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Sign Up',
          style: TextStyle(
            fontFamily: 'Quantico',
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildInputField(
              controller: _emailController,
              label: 'Email',
              obscure: false,
            ),
            const SizedBox(height: 24),
            _buildInputField(
              controller: _passwordController,
              label: 'Password',
              obscure: true,
            ),
            const SizedBox(height: 24),
            _buildInputField(
              controller: _confirmController,
              label: 'Confirm Password',
              obscure: true,
            ),
            const SizedBox(height: 40),

            ChamferButton(
              onPressed: _signup,
              child: const Text(
                'SIGN UP',
                style: TextStyle(
                  fontFamily: 'Quantico',
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Quantico',
      ),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.white70,
          fontFamily: 'Quantico',
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}
