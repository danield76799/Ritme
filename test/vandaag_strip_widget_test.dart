import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritme/utils/adherentie_dagen.dart';
import 'package:ritme/widgets/adherentie_heatmap.dart';
import 'package:ritme/widgets/prn_week_bars.dart';
import 'package:ritme/widgets/vandaag_strip.dart';

Widget _wrap(Widget child, {double schaal = 1.0}) => MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(schaal)),
          child: Center(
            child: SizedBox(width: 328, child: child),
          ),
        ),
      ),
    );

void main() {
  testWidgets('VandaagStrip past op een smal scherm, ook bij grote tekst',
      (tester) async {
    await tester.pumpWidget(_wrap(
      VandaagStrip(items: [
        VandaagItem(
          icon: Icons.mood_rounded,
          label: 'Stemming',
          value: '-2.5',
          delta: '+0.3 t.o.v. vorige week',
          onTap: () {},
        ),
        VandaagItem(
          icon: Icons.bedtime_rounded,
          label: 'Slaap',
          value: '7u 30m',
          delta: '-0.5u t.o.v. vorige week',
          onTap: () {},
        ),
        VandaagItem(
          icon: Icons.medication_rounded,
          label: 'Medicatie',
          value: '2/3',
          delta: 'Vandaag',
          onTap: () {},
        ),
      ]),
      schaal: 2.0,
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Heatmap en PRN-staafjes renderen zonder overflow',
      (tester) async {
    final dagen = List.generate(
      30,
      (i) => AdherentieDag(
        DateTime(2026, 11, 1).add(Duration(days: i)),
        i % 7 == 0 ? DagStatus.gemist : DagStatus.genomen,
      ),
    );
    await tester.pumpWidget(_wrap(
      Column(children: [
        AdherentieHeatmap(dagen: dagen),
        const SizedBox(height: 8),
        PrnWeekBars(waarden: const [0, 1, 0, 2, 0, 0, 3, 1]),
      ]),
      schaal: 2.0,
    ));
    expect(tester.takeException(), isNull);
  });
}
