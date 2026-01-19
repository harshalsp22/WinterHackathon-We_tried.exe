import 'package:arsenal/Shared/loading.dart';
import 'package:flutter/material.dart';
import 'package:arsenal/Shared/chamfer_button.dart';
import '../models/device_spec.dart';
import '../models/device_spec_config.dart';
import '../services/ai_prompt_builder.dart';
import '../services/ai_service.dart';
import 'diagnostic_plan_screen.dart';

class DeviceInfoScreen extends StatefulWidget {
  final String brand;
  final String model;

  const DeviceInfoScreen({
    super.key,
    required this.brand,
    required this.model,
  });

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  List<DeviceSpec> specs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDeviceInfoUsingAI();
  }

  /// 🔮 Replace later with real AI call
  Future<void> _fetchDeviceInfoUsingAI() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      specs = [
        DeviceSpec(key: 'Brand', value: widget.brand),
        DeviceSpec(key: 'Model', value: widget.model),
        DeviceSpec(key: 'CPU', value: '12th Gen Intel Core i5-1235U'),
        DeviceSpec(key: 'RAM', value: '8GB DDR4'),
        DeviceSpec(key: 'Storage', value: '512GB SSD'),
        DeviceSpec(key: 'OS', value: 'Windows 11'),
        DeviceSpec(key: 'Graphics Card', value: 'Intel UHD Graphics'),
        DeviceSpec(key: 'Display', value: '15.6"/39.6cm'),
      ];
      isLoading = false;
    });
  }

  void _editField(DeviceSpec spec) async {
    final controller = TextEditingController(text: spec.value);

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Edit ${spec.key}',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Quantico',
          ),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => spec.value = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    final horizontalPadding = isTablet ? size.width * 0.15 : 24.0;
    final titleSize = isTablet ? 22.0 : 18.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          ' Device Info',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Quantico',
            fontSize: titleSize,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
        child: Loading(),
      )
          : Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 24,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: specs.length,
                separatorBuilder: (_, __) =>
                const Divider(color: Colors.white12),
                itemBuilder: (_, index) {
                  final spec = specs[index];
                  return _specTile(
                    spec: spec,
                    onTap: () => _editField(spec),
                  );
                },
              ),
            ),

        ChamferButton(
          onPressed: () async {
            final userIssue = await _askUserIssue(context);
            if (userIssue == null || userIssue.isEmpty) return;

            final deviceInfo = {
              "brand": widget.brand,
              "model": widget.model,
              "specs": {
                for (var s in specs) s.key.toLowerCase(): s.value,
              }
            };

            final prompt = buildAIPrompt(
              deviceInfo: deviceInfo,
              userIssue: userIssue,
            );

            final aiService = AIService();

            setState(() => isLoading = true);

            try {
              final plan = await aiService.generatePlan(prompt);

              if (!mounted) return;
              setState(() => isLoading = false);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DiagnosticPlanScreen(plan: plan),
                ),
              );
            } catch (e) {
              setState(() => isLoading = false);

              // ✅ Show error to user
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },

              child: const Text(
                'CONFIRM & CONTINUE',
                style: TextStyle(
                  fontFamily: 'Quantico',
                  color: Colors.black,
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

  Widget _specTile({
    required DeviceSpec spec,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        deviceSpecIcons[spec.key] ?? Icons.info,
        color: Colors.white,
      ),
      title: Text(
        spec.key,
        style: const TextStyle(
          color: Colors.white70,
          fontFamily: 'Quantico',
          fontSize: 12,
        ),
      ),
      subtitle: Text(
        spec.value,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Quantico',
          fontSize: 15,
        ),
      ),
      trailing: const Icon(Icons.edit, color: Colors.white54),
    );
  }
}
Future<String?> _askUserIssue(BuildContext context) async {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.black,
      title: const Text(
        'Describe the issue',
        style: TextStyle(color: Colors.white, fontFamily: 'Quantico'),
      ),
      content: TextField(
        controller: controller,
        maxLines: 3,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'e.g. Laptop not turning on, overheating, no display',
          hintStyle: TextStyle(color: Colors.white54),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, controller.text.trim()),
          child: const Text('Continue', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
