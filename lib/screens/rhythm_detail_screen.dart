import 'package:flutter/material.dart';

import '../generated/l10n/app_localizations.dart';
import '../service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/activity_icon.dart';
import '../utils/activity_type_l10n.dart';
import '../utils/stability_palette.dart';

/// Ritme Stabiliteit: hoe consequent worden de dagelijkse activiteiten op hun
/// richttijd uitgevoerd (SRM P-scores over de laatste 7 dagen).
class RhythmDetailScreen extends StatefulWidget {
  const RhythmDetailScreen({super.key});

  @override
  State<RhythmDetailScreen> createState() => _RhythmDetailScreenState();
}

class _RhythmDetailScreenState extends State<RhythmDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activities = [];
  double _stabilityScore = 0;
  int _totalActivities = 0;
  int _onTimeCount = 0;
  Map<String, int> _activityTypeCounts = {};

  /// Stabiliteit over de 7 dagen daarvóór, voor het trendchipje.
  /// `null` als die periode geen activiteiten heeft — dan is er niets te
  /// vergelijken en tonen we liever geen chip dan een misleidende "+0%".
  double? _previousScore;

  /// Actief type-filter; `null` = alles tonen.
  /// De waarde is het ruwe DB-type, niet het vertaalde label.
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();

      // Doeltijden staan onder vaste settings-keys. De lookup moet op de
      // STABIELE DB-naam gebeuren ('Opstaan'), niet op het vertaalde label:
      // met een Engelse telefoon vroeg dit scherm 'Wake up' op, vond niets,
      // en viel terug op een ontbrekende p-score.
      final settings = await db.getSettings();
      final targetTimes = <String, String?>{
        'Opstaan': settings?['target_opstaan']?.toString(),
        'Eerste contact': settings?['target_contact']?.toString(),
        'Werk / Hobby': settings?['target_werk']?.toString(),
        'Avondeten': settings?['target_eten']?.toString(),
        'Naar bed': settings?['target_slapen']?.toString(),
      };

      List<Map<String, dynamic>> allActivities = [];
      int totalOnTime = 0;
      int totalActs = 0;
      Map<String, int> typeCounts = {};
      int prevOnTime = 0;
      int prevActs = 0;

      // 14 dagen: 0-6 = deze week (getoond), 7-13 = vorige week (alleen trend).
      for (int i = 0; i < 14; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final checkDateStr = _dateKey(checkDate);
        final dayActivities = await db.getSrmActivities(checkDateStr);
        final isCurrentWeek = i < 7;

        for (var activity in dayActivities) {
          final type = activity['activity_type']?.toString() ?? 'Onbekend';
          final dbName = activityDbType(type);
          final actualTime = activity['actual_time']?.toString();
          final dbTargetTime = activity['target_time']?.toString();
          final targetTime = dbTargetTime ?? targetTimes[dbName];

          // Herbereken de p-score zodra we een richttijd hebben, zodat een
          // gewijzigde richttijd meteen doorwerkt in de stabiliteit.
          final int pScore;
          if (targetTime != null &&
              targetTime.isNotEmpty &&
              actualTime != null &&
              actualTime.isNotEmpty) {
            pScore = _calculatePScore(targetTime, actualTime);
          } else {
            pScore = _parseInt(activity['p_score']);
          }

          if (!isCurrentWeek) {
            prevActs++;
            if (pScore >= 3) prevOnTime++;
            continue;
          }

          allActivities.add({
            'date': checkDateStr,
            'day': _dayName(checkDate.weekday),
            'type': dbName,
            'p_score': pScore,
            'actual_time': actualTime ?? '-',
            'target_time': targetTime ?? '-',
            'on_time': pScore >= 3,
          });

          totalActs++;
          if (pScore >= 3) totalOnTime++;
          typeCounts[dbName] = (typeCounts[dbName] ?? 0) + 1;
        }
      }

      if (!mounted) return;
      setState(() {
        _activities = allActivities;
        _totalActivities = totalActs;
        _onTimeCount = totalOnTime;
        _stabilityScore = totalActs > 0 ? (totalOnTime / totalActs * 100) : 0;
        _activityTypeCounts = typeCounts;
        _previousScore = prevActs > 0 ? (prevOnTime / prevActs * 100) : null;
        // Een filter dat na het verversen geen activiteiten meer heeft zou een
        // leeg scherm geven zonder zichtbare oorzaak — dan liever alles tonen.
        if (_selectedType != null && !typeCounts.containsKey(_selectedType)) {
          _selectedType = null;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  /// P-score uit het absolute tijdsverschil met de richttijd.
  int _calculatePScore(String targetTime, String actualTime) {
    final targetParts = targetTime.split(':');
    final actualParts = actualTime.split(':');
    if (targetParts.length < 2 || actualParts.length < 2) return 0;

    final targetMinutes =
        (int.tryParse(targetParts[0]) ?? 0) * 60 + (int.tryParse(targetParts[1]) ?? 0);
    final actualMinutes =
        (int.tryParse(actualParts[0]) ?? 0) * 60 + (int.tryParse(actualParts[1]) ?? 0);

    final diff = (actualMinutes - targetMinutes).abs();
    if (diff <= 15) return 5;
    if (diff <= 30) return 4;
    if (diff <= 45) return 3;
    if (diff <= 60) return 2;
    return 1;
  }

  String _dayName(int weekday) {
    final l10n = AppLocalizations.of(context);
    final days = ['', l10n.dagMa, l10n.dagDi, l10n.dagWo, l10n.dagDo, l10n.dagVr, l10n.dagZa, l10n.dagZo];
    return days[weekday];
  }

  String _getPScoreLabel(int score) {
    final l10n = AppLocalizations.of(context);
    if (score >= 5) return l10n.perfect;
    if (score >= 3) return l10n.opTijd;
    if (score >= 1) return l10n.enigszins;
    return l10n.gemist;
  }

  /// Percentage als chip-tekst: "+3%", "—2%" of "0%".
  String _formatDiff(double diff) {
    final rounded = diff.round();
    if (rounded == 0) return '0%';
    return rounded > 0 ? '+$rounded%' : '—${rounded.abs()}%';
  }

  List<Map<String, dynamic>> get _visibleActivities => _selectedType == null
      ? _activities
      : _activities.where((a) => a['type'] == _selectedType).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: StabilityPalette.canvas(brightness),
      appBar: AppBar(
        // Balkkleur, elevation, scrolledUnderElevation én foregroundColor staan
        // in appBarTheme. Hier stond `StabilityPalette.primaryText(brightness)`,
        // dat in dark mode puur wit koos terwijl het thema darkText gebruikt.
        // Die afwijking is nu weg: één bron voor alle 20 schermen.
        titleSpacing: AppTheme.screenPadding,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.ritmeStabiliteit,
          style: TextStyle(
            color: StabilityPalette.primaryText(brightness),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: StabilityPalette.accent(brightness),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: StabilityPalette.accent(brightness),
                backgroundColor: StabilityPalette.card(brightness),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                      AppTheme.screenPadding, 8, AppTheme.screenPadding, 0),
                  children: [
                    _ScoreCard(
                      score: _stabilityScore,
                      onTime: _onTimeCount,
                      total: _totalActivities,
                      previousScore: _previousScore,
                      formatDiff: _formatDiff,
                    ),
                    const SizedBox(height: 24),
                    if (_activityTypeCounts.isNotEmpty) ...[
                      _sectionHeader(l10n.rhythmActiviteitTypes, brightness),
                      const SizedBox(height: 10),
                      _buildTypeFilter(brightness, l10n),
                      const SizedBox(height: 24),
                    ],
                    _sectionHeader(
                        l10n.rhythmActiviteitenDezeWeek, brightness),
                    const SizedBox(height: 10),
                    if (_visibleActivities.isEmpty)
                      _buildEmptyState(
                        l10n.geenActiviteitenGevonden,
                        l10n.voegSrmActiviteitenToe,
                      )
                    else
                      ..._visibleActivities.map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ActivityTile(
                            activity: a,
                            statusLabel: _getPScoreLabel(a['p_score'] as int),
                          ),
                        ),
                      ),
                    // Ruimte onderaan zodat de systeemnavigatiebalk de laatste
                    // kaart niet afsnijdt.
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionHeader(String text, Brightness brightness) => Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: StabilityPalette.primaryText(brightness),
        ),
      );

  /// Horizontaal scrollende filterchips met hoge contrasten.
  ///
  /// Verving een `Wrap` van witte chips die in dark mode fel afstaken en
  /// scheef liepen zodra labels afgekapt werden.
  Widget _buildTypeFilter(Brightness brightness, AppLocalizations l10n) {
    final entries = _activityTypeCounts.entries.toList();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _TypeChip(
              label: l10n.alle,
              icon: Icons.apps_rounded,
              selected: _selectedType == null,
              onTap: () => setState(() => _selectedType = null),
            );
          }
          final entry = entries[index - 1];
          return _TypeChip(
            label: '${entry.key.localizedActivityType(l10n)} (${entry.value})',
            icon: activityTypeIcon(entry.key),
            selected: _selectedType == entry.key,
            onTap: () => setState(
              () => _selectedType =
                  _selectedType == entry.key ? null : entry.key,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: StabilityPalette.card(brightness),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.schedule_outlined,
              size: 48, color: StabilityPalette.secondaryText(brightness)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: StabilityPalette.primaryText(brightness),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.3,
              color: StabilityPalette.secondaryText(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero-kaart met de stabiliteitsscore en optioneel een trendchip.
class _ScoreCard extends StatelessWidget {
  final double score;
  final int onTime;
  final int total;
  final double? previousScore;
  final String Function(double) formatDiff;

  const _ScoreCard({
    required this.score,
    required this.onTime,
    required this.total,
    required this.previousScore,
    required this.formatDiff,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final accent = StabilityPalette.accent(brightness);

    final diff = previousScore == null ? null : score - previousScore!;
    // Onder een halve punt is het verschil afrondingsruis; dan geen chip.
    final showTrend = diff != null && diff.abs() >= 0.5;
    final trendUp = showTrend && diff > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: StabilityPalette.card(brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.stabiliteitScore,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              color: StabilityPalette.secondaryText(brightness),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${score.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.activiteitenOpTijd(onTime, total),
            style: TextStyle(
              fontSize: 14,
              color: StabilityPalette.secondaryText(brightness),
            ),
          ),
          if (showTrend) ...[
            const SizedBox(height: 14),
            _TrendChip(
              label: l10n.stabiliteitTrendChip(formatDiff(diff)),
              up: trendUp,
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip met de richting van de trend t.o.v. de vorige week.
class _TrendChip extends StatelessWidget {
  final String label;
  final bool up;

  const _TrendChip({required this.label, required this.up});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = up
        ? StabilityPalette.status(brightness, 5)
        : StabilityPalette.status(brightness, 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filterchip voor één activiteitstype.
class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = StabilityPalette.accent(brightness);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? accent
                : StabilityPalette.chip(brightness),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? accent : accent.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                // Donkere tekst/icoon op het accent — wit haalt daar 1.79:1.
                color: selected
                    ? StabilityPalette.onAccent
                    : StabilityPalette.primaryText(brightness),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? StabilityPalette.onAccent
                      : StabilityPalette.primaryText(brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eén activiteit uit de afgelopen week.
class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  final String statusLabel;

  const _ActivityTile({required this.activity, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final pScore = activity['p_score'] as int;
    final accent = StabilityPalette.accent(brightness);
    final type = activity['type']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StabilityPalette.card(brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categorie-icoon (niet de status): de pil rechts draagt de status,
          // zo blijft er één rustige kleurbron per kaart.
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(activityTypeIcon(type), size: 20, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.localizedActivityType(l10n),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: StabilityPalette.primaryText(brightness),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activity['day']} • ${l10n.rhythmDaadwerkelijk}: ${activity['actual_time']}',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: StabilityPalette.secondaryText(brightness),
                  ),
                ),
                if (activity['target_time'] != '-') ...[
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.rhythmTarget}: ${activity['target_time']}',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: StabilityPalette.secondaryText(brightness)
                          .withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(label: statusLabel, pScore: pScore),
        ],
      ),
    );
  }
}

/// Statusbadge (Op tijd / Enigszins / Gemist).
class _StatusPill extends StatelessWidget {
  final String label;
  final int pScore;

  const _StatusPill({required this.label, required this.pScore});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = StabilityPalette.status(brightness, pScore);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
