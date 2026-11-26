---
name: Story
about: Eén op te leveren stuk werk, valt onder een epic
title: ""
labels: [enhancement]
---

## Triage

- **Epic:** #N (verplicht als de repo epics heeft)
- **Area:** area/<name> (kies één of meer)
- **Depends on:** #N / extern (<wat>) / geen
- **Blocks:** #N / geen
- **Estimate:** <geschatte diff in regels>
- **Ready to start:** YES / NO — missing: <wat ontbreekt>

## Scope

<Wat bouwen we, in 1-3 zinnen.>

<!-- Optioneel: subtaken als `- [ ]`-regels -->

## Acceptance criteria

- [ ] <Meetbaar criterium> (bewijs: <commando, test, screenshot of meting>)
- [ ] <Meetbaar criterium> (bewijs: <commando, test, screenshot of meting>)
- [ ] <Delete of statuswijziging die data weghaalt: wat de database mee verwijdert en wat de server blokkeert, nagekeken in de backendcode> (bewijs: <bestand:regel>)

## Definition of Ready (vóór "In Progress")

- [ ] Priority-veld gezet (of een P-label als de repo geen veld heeft) + Area-label gezet + epic als parent, verplicht als de repo epics heeft (bewijs: velden, labels en parent op de kaart)
- [ ] Independent: elke blokkade staat bij Depends on, of "geen" (bewijs: de regel Depends on)
- [ ] Small: past in één PR (bewijs: Estimate op de kaart ≤ 400 regels, of een reden)
- [ ] Testable: elk acceptance criterium noemt zijn bewijs (bewijs: de criteria hierboven)
- [ ] Niets ontbreekt om te starten (bewijs: Ready to start staat op YES)

## Definition of Done (vóór close)

- [ ] Elk acceptance criterium afgevinkt (bewijs: commit, test-run of screenshot per criterium)
- [ ] Tests groen, of het resultaat is gemeten (bewijs: suite en uitkomst, of de meting)
- [ ] Docs kloppen met de domein-change, of er is er geen (bewijs: commit, of "geen domein-change")
- [ ] Review APPROVE (bewijs: verslag als opmerking op de kaart of PR, of geen diff)
