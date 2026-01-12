class DiagnosticPlan {
  final List<DiagnosticStep> steps;
  final List<String> requiredTools;
  final String confidenceLevel;

  DiagnosticPlan({
    required this.steps,
    required this.requiredTools,
    required this.confidenceLevel,
  });

  factory DiagnosticPlan.fromJson(Map<String, dynamic> json) {
    return DiagnosticPlan(
      steps: (json['diagnosis_plan'] as List<dynamic>?)
          ?.map((e) => DiagnosticStep.fromJson(e))
          .toList() ??
          [],
      requiredTools: List<String>.from(json['required_tools'] ?? []),
      confidenceLevel: json['confidence_level'] ?? 'Unknown',
    );
  }
}

class DiagnosticStep {
  final int step;
  final String title;
  final String description;
  final String cameraFocus;
  final String safetyWarning;

  DiagnosticStep({
    required this.step,
    required this.title,
    required this.description,
    required this.cameraFocus,
    required this.safetyWarning,
  });

  factory DiagnosticStep.fromJson(Map<String, dynamic> json) {
    return DiagnosticStep(
      step: json['step'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      cameraFocus: json['camera_focus'] ?? '',
      safetyWarning: json['safety_warning'] ?? '',
    );
  }
}
