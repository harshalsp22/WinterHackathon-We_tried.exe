import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arsenal/Shared/chamfer_button.dart';
import 'package:arsenal/Screens/device_info_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedBrand;
  String? selectedModel;

  final Map<String, List<String>> laptopModels = {
    'Dell': [
      'Inspiron 15',
      'XPS 13',
      'XPS 15',
      'Latitude 5420',
      'G15 Gaming',
    ],
    'HP': [
      'Pavilion 14',
      'Victus 16',
      'Omen 15',
      'EliteBook 840',
    ],
    'Lenovo': [
      'ThinkPad E14',
      'ThinkPad X1 Carbon',
      'IdeaPad Slim 5',
      'Legion 5',
    ],
    'ASUS': [
      'VivoBook 15',
      'ZenBook 14',
      'ROG Strix G15',
      'TUF F15',
    ],
    'Acer': [
      'Aspire 7',
      'Nitro 5',
      'Swift 3',
    ],
    'Apple': [
      'MacBook Air M1',
      'MacBook Air M2',
      'MacBook Pro 14"',
      'MacBook Pro 16"',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final models = selectedBrand == null
        ? <String>[]
        : laptopModels[selectedBrand]!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Select Laptop',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Quantico',
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: Colors.white,
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Brand'),
            _dropdown(
              value: selectedBrand,
              hint: 'Select Brand',
              items: laptopModels.keys.toList(),
              onChanged: (value) {
                setState(() {
                  selectedBrand = value;
                  selectedModel = null;
                });
              },
            ),

            const SizedBox(height: 30),

            _label('Model'),
            _dropdown(
              value: selectedModel,
              hint: selectedBrand == null
                  ? 'Select brand first'
                  : 'Select Model',
              items: models,
              enabled: selectedBrand != null,
              onChanged: (value) {
                setState(() => selectedModel = value);
              },
            ),

            const SizedBox(height: 50),

            Center(
              child: ChamferButton(
                onPressed: selectedModel == null
                    ? () {}
                    : () {
                  // TODO: Navigate to AR / diagnostics
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeviceInfoScreen(
                        brand: selectedBrand!,
                        model: selectedModel!,
                      ),
                    ),
                  );
                  debugPrint(
                    'Selected: $selectedBrand - $selectedModel',
                  );
                },
                child: const Text(
                  'CONTINUE',
                  style: TextStyle(
                    fontFamily: 'Quantico',
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Quantico',
          color: Colors.white70,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String hint,
    required List<String> items,
    String? value,
    bool enabled = true,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      dropdownColor: Colors.black,
      iconEnabledColor: Colors.white,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Quantico',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
        disabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
          value: item,
          child: Text(item),
        ),
      )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}
