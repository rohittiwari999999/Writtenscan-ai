import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.psychology),
            title: Text('OCR Engine'),
            subtitle: Text('Google Gemini Vision 3.8 Flash'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.language),
            title: Text('Default Language'),
            subtitle: Text('Auto Detect (English, Hindi, Tamil, etc.)'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.security),
            title: Text('Data Privacy'),
            subtitle: Text('Zero image retention on cloud servers'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('WriteScan AI v1.0.0 (Build 1)'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
