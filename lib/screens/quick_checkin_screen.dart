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
          final id = config['id'] as int?;
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Snelle Check-in',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Datum
                  Text(
                    DateFormat('EEEE d MMMM', 'nl_NL').format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. STEMMING
                  _buildSectionTitle('1. Hoe voel je je vandaag?'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                        const SizedBox(height: 20),
                        // Slider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _getStemmingKleur(_stemming),
                            inactiveTrackColor: Colors.grey[200],
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
                  const SizedBox(height: 24),

                  // 2. SLAAP
                  _buildSectionTitle('2. Hoeveel uur heb je geslapen?'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                            const SizedBox(width: 8),
                            Text(
                              'uur',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.primaryTeal,
                            inactiveTrackColor: Colors.grey[200],
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
                  const SizedBox(height: 24),

                  // 3. MEDICATIE
                  _buildSectionTitle('3. Medicatie genomen?'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
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
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _medicatieGenomen
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _medicatieGenomen ? Icons.check_circle : Icons.medication,
                              color: _medicatieGenomen ? Colors.green[700] : Colors.grey,
                              size: 28,
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
                                    color: _medicatieGenomen ? Colors.green[800] : Colors.grey[800],
                                  ),
                                ),
                                Text(
                                  'Tap om te wisselen',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
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
                  const SizedBox(height: 32),

                  // OPSLAAN KNOP
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _opslaan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
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
                  const SizedBox(height: 12),

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
                          color: Colors.grey[600],
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
