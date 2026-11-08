#!/usr/bin/env python3
"""Voegt ontbrekende l10n-sleutels toe aan de Ritme .arb-bestanden.

Gebruik: python3 tools/add_l10n_keys.py
"""
import json
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# key -> (nl, en)
NIEUWE_SLEUTELS = {
    # Periodekiezer
    "dertigDagen": ("30 dagen", "30 days"),
    "periodeKiezer": ("Periode", "Period"),
    # Onboarding
    "onboardingWelkomTitel": ("Welkom bij Ritme", "Welcome to Ritme"),
    "onboardingWelkomBeschrijving": (
        "Ritme helpt je dagelijks je sociale ritme bij te houden: stemming, slaap, activiteiten, medicatie en afspraken. Jouw data blijft op je telefoon.",
        "Ritme helps you track your daily social rhythm: mood, sleep, activities, medication and appointments. Your data stays on your phone.",
    ),
    "onboardingCheckinTitel": ("Ochtend & avond check-in", "Morning & evening check-in"),
    "onboardingCheckinBeschrijving": (
        "Start je dag met de ochtend-check-in (slaap & stemming) en sluit af met de avond-check-in (5 SRM-momenten). Dashboard toont of je dag compleet is.",
        "Start your day with the morning check-in (sleep & mood) and end it with the evening check-in (5 SRM moments). The dashboard shows whether your day is complete.",
    ),
    "onboardingCrisisplanTitel": (
        "Crisisplan binnen handbereik",
        "Crisis plan always within reach",
    ),
    "onboardingCrisisplanBeschrijving": (
        "Je crisisplan staat altijd in het menu (hart-icoon). Voeg contacten en voortekenen toe, zodat je er snel bij kunt als het nodig is.",
        "Your crisis plan is always in the menu (heart icon). Add contacts and early warning signs so you can reach it quickly when needed.",
    ),
    "overslaan": ("Overslaan", "Skip"),
    "volgende": ("Volgende", "Next"),
    "aanDeSlag": ("Aan de slag", "Get started"),
    # Lege staten
    "eersteGewichtsmeting": (
        "Voeg je eerste meting toe om je trend te zien.",
        "Add your first measurement to see your trend.",
    ),
    "geenVoortekenenLaatste14Dagen": (
        "Geen voortekenen geregistreerd in de laatste 14 dagen.",
        "No early warning signs recorded in the last 14 days.",
    ),
    # Instellingen
    "testAutomatischeBackup": ("Test automatische backup", "Test automatic backup"),
    # Statistieken
    "statistiekenPeriode": ("Periode", "Period"),
    "statistiekenAllePeriodes": ("Alle", "All"),
}


def voeg_toe(pad: Path, index: int) -> None:
    data = json.loads(pad.read_text(encoding="utf-8"), object_pairs_hook=OrderedDict)
    for key, waarden in NIEUWE_SLEUTELS.items():
        if key in data:
            continue
        data[key] = waarden[index]
    # Schrijf terug met 2 spaties indent, unicode ongewijzigd.
    pad.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"{pad.name}: {len(data)} sleutels")


if __name__ == "__main__":
    voeg_toe(ROOT / "lib" / "l10n" / "intl_nl.arb", 0)
    voeg_toe(ROOT / "lib" / "l10n" / "intl_en.arb", 1)
