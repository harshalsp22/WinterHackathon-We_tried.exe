import 'package:flutter/material.dart';
import '../models/diagnostic_plan.dart';
import '../Screens/ar_camera_screen.dart';



class DiagnosticPlanScreen extends StatelessWidget {
  final DiagnosticPlan plan;

  const DiagnosticPlanScreen({
    super.key,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Diagnostic Plan'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: plan.steps.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, i) {
                final step = plan.steps[i];
                return Card(
                  color: Colors.grey[900],
                  child: ListTile(
                    title: Text(
                      step.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      step.description,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ARCameraScreen(plan: plan),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('START CAMERA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
