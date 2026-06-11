import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../service_locator.dart';

/// Snelle check-in: 3 taps en klaar.
/// 
/// Vraagt alleen:
/// 1. Hoe voel je je? (stemming -5 tot +5)
/// 2. Hoeveel heb je geslapen? (uren)
/// 3. Medicatie genomen? (ja/nee)
/// 
/// Slaat op in daily_logs en medication_intake.
class QuickCheckInScreen extends StatefulWidget {
  const QuickCheckInScreen({super.key});

  @override
  State<QuickCheckInScreen> createState() => _QuickCheckInScreenState();
}

class _QuickCheckInScreenState extends State<QuickCheckInScreen> {
  double _stemming = 0.0;
  double _slaapUren = 7.0;
  bool _medicatieGenomen = false;
  bool _isSaving = false;

  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getStemmingLabel(double waarde) {
    if (waarde <= -4) return 'Ernstig depressief';
    if (waarde <= -3) return 'Matig depressief';
    if (waarde <= -2) return 'Licht depressief';
    if (waarde <= -1) return 'Somber';
    if (waarde == 0) return 'Stabiel / Neutraal';
    if (waarde <= 1) return 'Licht manisch';
    if (waarde <= 2) return 'Matig manisch';
    if (waarde <= 3) return 'Druk / Actief';
    if (waarde <= 4) return 'Ernstig manisch';
    return 'Uiterst manisch';
  }

  String _formatDatum() {
    final now = DateTime.now();
    final dagen = ['zondag', 'maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag'];
    final maanden = ['januari', 'februari', 'maart', 'april', 'mei', 'juni', 'juli', 'augustus', 'september', 'oktober', 'november', 'december'];
    return '${dagen[now.weekday % 7]} ${now.day} ${maanden[now.month - 1]}';
  }

  Color _getStemmingKleur(double waarde) {
    if (waarde <= -3) return Colors.blue[600]!;
    if (waarde <= -1) return Colors.blue[300]!;
    if (waarde == 0) return Colors.green[400]!;
    if (waarde <= 2) return Colors.orange[500]!;
    return Colors.red[500]!;
  }

  Future<void> _opslaan() async {
    setState(() => _isSaving = true);

    try {
      // 1. Sla stemming + slaap op in daily_logs
      // Quick check-in: altijd als stemming_hoog opslaan (positief of negatief)
      // Het stemming scherm interpreteert dit correct
      await db.upsertDailyLog({
        'date': _today,
        'stemming_hoog': _stemming,
        'stemming_laag': _stemming,
        'gesplitste_stemming': false,
        'uren_slaap': _slaapUren,
      });

      // 2. Sla medicatie intake op (als aangevinkt)
      if (_medicatieGenomen) {
        final configs = await db.getMedicationConfigs();
        for (final config in configs) {
          final rawId = config['id'];
          final id = rawId is int ? rawId : int.tryParse(rawId.toString());
          if (id != null) {
            await db.confirmMedicationIntake(_today, id, 1);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Check-in opgeslagen!'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Snelle Check-in',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: _isSaving
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Datum
                  Text(
                    _formatDatum(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 24),

                  // 1. STEMMING
                  _buildSectionTitle('1. Hoe voel je je vandaag?'),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Grote emoji + label
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                          decoration: BoxDecoration(
                            color: _getStemmingKleur(_stemming).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _stemming.round().toString(),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: _getStemmingKleur(_stemming),
                                ),
                              ),
                              Text(
                                _getStemmingLabel(_stemming),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _getStemmingKleur(_stemming),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        // Slider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _getStemmingKleur(_stemming),
                            inactiveTrackColor: Colors.grey.shade200,
                            thumbColor: _getStemmingKleur(_stemming),
                            overlayColor: _getStemmingKleur(_stemming).withValues(alpha: 0.2),
                            trackHeight: 8,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                          ),
                          child: Slider(
                            value: _stemming,
                            min: -5,
                            max: 5,
                            divisions: 10,
                            onChanged: (value) => setState(() => _stemming = value),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('😞', style: TextStyle(fontSize: 20)),
                              Text('😐', style: TextStyle(fontSize: 20)),
                              Text('😄', style: TextStyle(fontSize: 20)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // 2. SLAAP
                  _buildSectionTitle('2. Hoeveel uur heb je geslapen?'),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _slaapUren.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'uur',
                              style: TextStyle(
                                fontSize: 20,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.primaryTeal,
                            inactiveTrackColor: Colors.grey.shade200,
                            thumbColor: AppTheme.primaryTeal,
                            overlayColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
                            trackHeight: 8,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                          ),
                          child: Slider(
                            value: _slaapUren,
                            min: 0,
                            max: 14,
                            divisions: 28,
                            onChanged: (value) => setState(() => _slaapUren = value),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('0u', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('7u', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('14u', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // 3. MEDICATIE
                  _buildSectionTitle('3. Medicatie genomen?'),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _medicatieGenomen ? Colors.green.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _medicatieGenomen ? Colors.green.shade300 : Colors.grey.shade200,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => setState(() => _medicatieGenomen = !_medicatieGenomen),
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _medicatieGenomen
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _medicatieGenomen ? Icons.check_circle : Icons.medication_outlined,
                              color: _medicatieGenomen ? Colors.green[700] : Colors.grey,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _medicatieGenomen ? '✓ Medicatie genomen' : 'Medicatie nog niet genomen',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _medicatieGenomen ? Colors.green[800] : Colors.grey.shade800,
                                  ),
                                ),
                                Text(
                                  _medicatieGenomen 
                                    ? 'Je medicatie is geregistreerd'
                                    : 'Vergeet je medicatie niet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _medicatieGenomen,
                            onChanged: (value) => setState(() => _medicatieGenomen = value),
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 32),

                  // OPSLAAN KNOP
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _opslaan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Opslaan',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Link naar uitgebreide invoer
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/mood');
                      },
                      child: Text(
                        'Uitgebreide invoer →',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF333333),
      ),
    );
  }
}
