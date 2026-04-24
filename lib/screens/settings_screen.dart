import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';

class InstellingenScherm extends StatefulWidget {
  @override
  _InstellingenSchermState createState() => _InstellingenSchermState();
}

class _InstellingenSchermState extends State<InstellingenScherm> {
  final Color primaryTeal = const Color(0xFF4FB2C1);
  final TextEditingController _pinController = TextEditingController();
  
  Map<String, TimeOfDay?> _richttijden = {
    'target_opstaan': TimeOfDay(hour: 8, minute: 0),
    'target_contact': TimeOfDay(hour: 9, minute: 0),
    'target_werk': TimeOfDay(hour: 9, minute: 0),
    'target_eten': TimeOfDay(hour: 18, minute: 0),
    'target_slapen': TimeOfDay(hour: 23, minute: 0),
  };

  @override
  void initState() {
    super.initState();
    _laadInstellingen();
  }

  Future<void> _laadInstellingen() async {
    final settings = await db.getSettings();
    if (settings != null) {
      setState(() {
        _pinController.text = settings['password_hash'] ?? '';
        _richttijden.keys.forEach((key) {
          if (settings[key] != null && settings[key].toString().isNotEmpty) {
            final parts = settings[key].toString().split(':');
            _richttijden[key] = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        });
      });
    }
  }

  Future<void> _kiesTijd(String key) async {
    final TimeOfDay? gekozen = await showTimePicker(
      context: context,
      initialTime: _richttijden[key] ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: primaryTeal)),
        child: child!,
      ),
    );
    if (gekozen != null) {
      setState(() => _richttijden[key] = gekozen);
    }
  }

  String _tijdNaarString(TimeOfDay? tijd) {
    if (tijd == null) return '';
    return '${tijd.hour.toString().padLeft(2, '0')}:${tijd.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _opslaan() async {
    final settingsMap = {
      'username': 'Gebruiker',
      'password_hash': _pinController.text,
      'target_opstaan': _tijdNaarString(_richttijden['target_opstaan']),
      'target_contact': _tijdNaarString(_richttijden['target_contact']),
      'target_werk': _tijdNaarString(_richttijden['target_werk']),
      'target_eten': _tijdNaarString(_richttijden['target_eten']),
      'target_slapen': _tijdNaarString(_richttijden['target_slapen']),
    };
    
    await db.updateSettingsMap(settingsMap);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Instellingen opgeslagen!'), backgroundColor: primaryTeal),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Instellingen'), backgroundColor: primaryTeal),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text('Beveiliging', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Pincode voor app'),
          ),
          SizedBox(height: 24),
          Text('Richttijden (SRT)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Stel je ideale tijden in. Dit is de basis voor je SRT-score.', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 16),
          _bouwTijdRij('Opstaan', 'target_opstaan'),
          _bouwTijdRij('Eerste Contact', 'target_contact'),
          _bouwTijdRij('Werk / Hobby', 'target_werk'),
          _bouwTijdRij('Avondeten', 'target_eten'),
          _bouwTijdRij('Naar Bed', 'target_slapen'),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: _opslaan,
            style: ElevatedButton.styleFrom(backgroundColor: primaryTeal, padding: EdgeInsets.symmetric(vertical: 16)),
            child: Text('Opslaan', style: TextStyle(fontSize: 18, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _bouwTijdRij(String label, String key) {
    return ListTile(
      title: Text(label),
      trailing: Text(_tijdNaarString(_richttijden[key]), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTeal)),
      onTap: () => _kiesTijd(key),
    );
  }
}
