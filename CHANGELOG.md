# Onontwikkeld

## Verbeteringen
- **Statistieken: periodekiezer (7 / 14 / 30 dagen / alle)** — de Life Chart-grafieken
  en de KPI-kaarten laten nu zien over welke periode ze gaan. Met veel historie was de
  grafiek anders onleesbaar. Zelfde patroon als de stemming-trend op het dashboard.
- **Statistieken: slaapgrafiek toont de juiste datums** — de balken werden compact
  geteld terwijl de datumlabels uit de volledige lijst kwamen. Zodra er dagen zonder
  slaapdata tussen zaten, schoven de datums naar voren en toonde elke balk de
  verkeerde dag.
- **PDF-rapport: periode loopt van oud naar nieuw** — stond omgekeerd (nieuw → oud).
- **PDF-rapport: toont de 14 meest recente dagen** — stond de 14 oudste dagen.
- **PDF-rapport gaat over de volle historie** — los van de periode die op het scherm
  gekozen is; een rapport moet compleet zijn.

## Vertaling
- **Onboarding volledig vertaald** — de drie introductiepagina's, "Overslaan",
  "Volgende" en "Aan de slag" stonden hardcoded in het Nederlands.
- **Lege staten vertaald** — eerste gewichtsmeting en "geen voortekenen in de
  laatste 14 dagen".
- **Instellingen vertaald** — "Test automatische backup".

## Tests
- `test/statistieken_periode_test.dart` — regressietests voor de periodekiezer, de
  slaapgrafiek-datums en de PDF-periode.
- `test/geen_hardcoded_teksten_test.dart` — faalt zodra er weer een hardcoded
  Nederlandse gebruikerstekst in de schermen komt.

# Ritme v1.3.0

## Verbeteringen
- **Alle schermen voorzien van betere error handling**
- **Consistente foutmeldingen**: Gebruikers zien nu duidelijke foutmeldingen in plaats van crashes
- **Logger utility**: Centrale logging voor betere debugging
- **Error boundaries**: App beschermt tegen crashes en toont gebruiksvriendelijke foutmeldingen
- **Database error handling**: Alle database operaties hebben nu try-catch blocks
- **Gebruikersfeedback**: SnackBars tonen specifieke foutmeldingen bij opslagproblemen

## Schermen bijgewerkt
- `lib/screens/activity_screen.dart` - Error handling + loading states
- `lib/screens/appointments_screen.dart` - Error handling + loading states
- `lib/screens/dashboard_screen.dart` - Error handling + loading states
- `lib/screens/event_screen.dart` - Error handling + loading states
- `lib/screens/insights_screen.dart` - Error handling + loading states
- `lib/screens/login_screen.dart` - Error handling + loading states
- `lib/screens/medication_screen.dart` - Error handling + loading states
- `lib/screens/medication_schedule_screen.dart` - Error handling + loading states
- `lib/screens/mood_screen.dart` - Error handling + loading states
- `lib/screens/settings_screen.dart` - Error handling + loading states
- `lib/screens/sociaal_ritme_meter_screen.dart` - Error handling + loading states
- `lib/screens/statistics_screen.dart` - Error handling + loading states
- `lib/screens/weight_screen.dart` - Error handling + loading states

## Technische Details
- Logger utility in `lib/utils/logger.dart`
- Error boundary in `lib/main.dart`
- Consistente error handling pattern in alle schermen:
  - `_isLoading` state voor loading indicators
  - `_errorMessage` state voor foutmeldingen
  - `_buildErrorWidget()` voor error UI
  - `_buildEmptyState()` voor lege data
  - Try-catch blocks rondom alle database operaties
  - SnackBars voor gebruikersfeedback

## Volgende Stappen
- [ ] Performance optimalisaties
- [ ] Data export/import verbeteringen
- [ ] Nieuwe features toevoegen
