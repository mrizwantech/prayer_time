import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/time_format_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final timeFormatSettings = Provider.of<TimeFormatSettings>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('24-Hour Time Format'),
            value: timeFormatSettings.is24Hour,
            onChanged: (val) => timeFormatSettings.setFormat(val),
            subtitle: Text(timeFormatSettings.is24Hour ? '24-hour' : '12-hour'),
          ),
        ],
      ),
    );
  }
}
