import 'package:arsenal/Shared/loading.dart';
import 'package:flutter/material.dart';
import 'package:arsenal/Shared/chamfer_button.dart';
import '../models/device_spec.dart';
import '../models/device_spec_config.dart';

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

    specs = [
      DeviceSpec(key: 'Brand', value: widget.brand),
      DeviceSpec(key: 'Model', value: widget.model),
      DeviceSpec(key: 'CPU', value: 'enter'),
      DeviceSpec(key: 'RAM', value: '8 GB'),
      DeviceSpec(key: 'Storage', value: '512 GB SSD'),
      DeviceSpec(key: 'OS', value: 'Windows 11'),
      DeviceSpec(key: 'Graphics Card', value: 'NVIDIA GeForce RTX 3060'),
      DeviceSpec(key: 'Display' , value: '15.6"')
    ];

    setState(() => isLoading = false);
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
              onPressed: () {
                final confirmedData = {
                  for (var s in specs) s.key: s.value,
                };
                debugPrint(confirmedData.toString());
                // NEXT: Firestore / AR flow
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
