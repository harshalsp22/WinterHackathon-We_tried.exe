import 'package:flutter/material.dart';
import '../models/diagnostic_plan.dart';

class DiagnosticPlanScreen extends StatelessWidget {
  final DiagnosticPlan plan;

  const DiagnosticPlanScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Diagnostic Plan',style: const TextStyle(color: Colors.white)
        ),

      ),
      body: ListView.builder(
        itemCount: plan.steps.length,
        itemBuilder: (_, i) {
          final step = plan.steps[i];
          return ListTile(
            title: Text(step.title, style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              step.description,
              style: const TextStyle(color: Colors.white70),
            ),
          );
        },
      ),
    );
  }
}
