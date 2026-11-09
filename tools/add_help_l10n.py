#!/usr/bin/env python3
"""Zet het help-scherm om naar l10n.

Het help-scherm had 35 hardcoded `isDutch ? '…' : '…'`-strings. Die zijn
vervangen door echte arb-sleutels, zodat het scherm alle talen van de app
volgt in plaats van alleen Nederlands en Engels.

Gebruik: python3 tools/add_help_l10n.py
"""
import json
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# key -> (nl, en)
SLEUTELS = {
    "helpTitel": ("Gebruiksaanwijzing", "User Guide"),
    "helpIntro": (
        "Ritme is gebaseerd op Social Rhythm Therapy (SRT), een bewezen methode "
        "om je dagelijks ritme te verbeteren. Door regelmatigheid in slaap, "
        "activiteiten, sociale contacten en medicatie kun je je stemming en "
        "welbevinden positief beïnvloeden. Alle inzichten zijn bedoeld ter "
        "ondersteuning, niet als medisch advies.",
        "Ritme is based on Social Rhythm Therapy (SRT), a proven method to "
        "improve your daily rhythm. Through regularity in sleep, activities, "
        "social contact and medication you can positively influence your mood "
        "and well-being. All insights are meant as support, not medical advice.",
    ),
    # Check-ins
    "helpCheckinsTitel": (
        "Check-ins (ochtend & avond)",
        "Check-ins (morning & evening)",
    ),
    "helpCheckinOchtend": (
        "Ochtend: opstaantijd, slaap (behoefte + kwaliteit), stemming, "
        "gebeurtenis, eerste contact, werk/hobby",
        "Morning: wake time, sleep (need + quality), mood, event, first "
        "contact, work/hobby",
    ),
    "helpCheckinAvond": (
        "Avond: stemming (3x), gebeurtenis, avondeten, bedtijd",
        "Evening: mood (3x), event, dinner, bedtime",
    ),
    "helpCheckinGroen": (
        "Een afgeronde check-in kleurt de tegel groen op het dashboard",
        "A finished check-in turns the dashboard tile green",
    ),
    "helpStemmingsschaalTitel": (
        "Stemmingsschaal (−5 tot +5)",
        "Mood scale (−5 to +5)",
    ),
    "helpSchaalMin5": ("−5: Uiterst depressief", "−5: Extremely depressed"),
    "helpSchaalMin3": ("−3: Matig depressief", "−3: Moderately depressed"),
    "helpSchaalNul": ("0: Neutraal", "0: Neutral"),
    "helpSchaalPlus3": ("+3: Matig manisch", "+3: Moderately manic"),
    "helpSchaalPlus5": ("+5: Uiterst manisch", "+5: Extremely manic"),
    # P-score
    "helpPScoreTitel": (
        "P-score legenda (sociaal ritme)",
        "P-score legend (social rhythm)",
    ),
    "helpPScore15": ("✓✓ Binnen 15 min", "✓✓ Within 15 min"),
    "helpPScore30": ("✓ Binnen 30 min", "✓ Within 30 min"),
    "helpPScore45": ("~ Binnen 45 min", "~ Within 45 min"),
    "helpPScore60": ("! Binnen 60 min", "! Within 60 min"),
    "helpPScoreMeer60": ("!! Meer dan 60 min", "!! More than 60 min"),
    "helpPScoreGeen": ("Geen activiteit", "No activity"),
    "helpPunten": ("punten", "points"),
    "helpPunt": ("punt", "point"),
    # Medicatie
    "helpMedicatieTitel": ("Medicatie", "Medication"),
    "helpMedicatieToevoegen": (
        "Voeg medicijnen toe met naam, dosering en vaste tijden",
        "Add medications with name, dosage and fixed times",
    ),
    "helpMedicatieHerinnering": (
        "Herinneringen komen via notificaties; markeer als genomen of overgeslagen",
        "Reminders arrive via notifications; mark as taken or skipped",
    ),
    # SRT-score
    "helpSrtUitstekend": ("Uitstekend stabiel", "Excellent stability"),
    "helpSrtUitstekendActie": ("✅ Blijf zo doorgaan", "✅ Keep it up"),
    "helpSrtGoed": ("Goed, kleine variaties", "Good, small variations"),
    "helpSrtGoedActie": ("✅ Acceptabel", "✅ Acceptable"),
    "helpSrtMatig": ("Matig, aandacht nodig", "Moderate, attention needed"),
    "helpSrtMatigActie": ("⚠️ Monitor je ritme", "⚠️ Monitor your rhythm"),
    "helpSrtInstabiel": ("Instabiel", "Unstable"),
    "helpSrtInstabielActie": (
        "🔴 Bespreek met behandelaar",
        "🔴 Discuss with therapist",
    ),
    "helpSrtZeerInstabiel": ("Zeer instabiel", "Very unstable"),
    "helpSrtZeerInstabielActie": ("🚨 Hulp zoeken", "🚨 Seek help"),
    # Rondkijken
    "helpRondkijkenTitel": (
        "Rondkijken (statistieken, episodes, instellingen)",
        "Explore (statistics, episodes, settings)",
    ),
    "helpRondkijkenStatistieken": (
        "Statistieken: weekgrafiek, slaap- en ritmedetails, SRT-trend",
        "Statistics: week graph, sleep and rhythm details, SRT trend",
    ),
    "helpRondkijkenMenu": (
        "Episodes, voortekenen, gewicht, afspraken en dagboek staan in het menu",
        "Episodes, prodromes, weight, appointments and journal live in the menu",
    ),
    "helpRondkijkenInstellingen": (
        "Doeltijden, thema en automatische backup stel je in bij Instellingen",
        "Target times, theme and automatic backup live in Settings",
    ),
    # Tips
    "helpTipsTitel": ("Tips voor succes", "Tips for success"),
    "helpTipDagelijks": (
        "Vul dagelijks in, liefst op vaste tijden — ook in het weekend",
        "Fill in daily, preferably at fixed times — weekends included",
    ),
    "helpTipMedicatie": (
        "Neem medicatie op de afgesproken tijden",
        "Take medication at the agreed times",
    ),
    "helpTipStatistieken": (
        "Bekijk je statistieken wekelijks om patronen te herkennen",
        "Review your statistics weekly to recognize patterns",
    ),
    "helpTipLokaal": (
        "Alle gegevens blijven lokaal op je toestel (PIN/biometrie mogelijk)",
        "All data stays locally on your device (PIN/biometrics available)",
    ),
}


def voeg_toe(pad: Path, index: int) -> None:
    data = json.loads(pad.read_text(encoding="utf-8"), object_pairs_hook=OrderedDict)
    for key, waarden in SLEUTELS.items():
        if key not in data:
            data[key] = waarden[index]
    pad.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"{pad.name}: {len(data)} sleutels")


if __name__ == "__main__":
    voeg_toe(ROOT / "lib" / "l10n" / "intl_nl.arb", 0)
    voeg_toe(ROOT / "lib" / "l10n" / "intl_en.arb", 1)
