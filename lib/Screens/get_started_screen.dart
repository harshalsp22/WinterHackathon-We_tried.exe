import 'package:flutter/material.dart';
import 'auth_wrapper.dart';
import 'package:arsenal/Shared/chamfer_button.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/assets/images/bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP-LEFT HERO TEXT
            Padding(
              padding: const EdgeInsets.only(
                top: 200,
                left: 30,
                right: 30,
              ),
              child: SizedBox(
                width: 280,
                child: Text(
                  'Fix your PC and laptop with ARsenal',
                  style: const TextStyle(
                    fontFamily: 'Quantico',
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.normal,
                    letterSpacing: 1.4,
                    height: 1.3,
                  ),
                ),
              ),
            ),

            // CENTER CONTENT
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'An AR based hardware assist',
                      style: TextStyle(
                        fontFamily: 'Quantico',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 40),
                    ChamferButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AuthWrapper(),
                          ),
                        );
                      },
                      child: const Text(
                        'GET STARTED',
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
            ),
          ],
        ),
      ),
    );
  }
}
