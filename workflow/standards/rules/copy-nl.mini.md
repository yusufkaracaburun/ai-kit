---
name: copy-nl
description: Dutch AI-writing tells — the vocabulary and constructions that give away machine-written Nederlands, mapped onto the 39 English humanizer patterns
applies_to:
  frameworks: []
  languages: []
  architectures: []
universal: false
default_mode: on-demand
weight: medium
repo_age_min_years: 0
---

# Nederlandse AI-tells

The 39 humanizer patterns in [`/ai:copywriter`](../../workflow/skills/copywriter/SKILL.md)
come from English Wikipedia. The *method* transfers to Dutch; the *word lists*
do not. This rule is the Dutch half.

Load it when the text under audit is Dutch. Everything here supplements the
numbered patterns, never replaces them: the § references point at the English
pattern each tell belongs to, so a finding reads the same in either language.

## Vocabulary (§7 — AI vocabulary)

| Tell | Waarom | Beter |
| ---- | ------ | ----- |
| Daarnaast, Bovendien, Tevens, Verder (zinsopening) | Gestapelde connectieven. Eén is normaal, drie op een pagina is een tell. | Begin bij het onderwerp. |
| Het is belangrijk om te vermelden dat | Aankondiging in plaats van inhoud. | Zeg het gewoon. |
| middels, derhalve, zulks | Ambtelijk register dat modellen te vaak kiezen. | met, dus |
| naadloos, moeiteloos | Leenvertaling van seamless/effortless. | Zeg wat er niet meer hoeft. |
| cruciaal, essentieel, van onschatbare waarde | Bijvoeglijke opblazing zonder bewijs. | Noem het effect. |
| een must, onmisbaar | Reclametaal. | Schrappen. |
| de perfecte oplossing voor | Belofte zonder inhoud. | Wat lost het op? |

## Constructions

| Tell | Pattern | Voorbeeld → beter |
| ---- | ------- | ----------------- |
| Naamwoordstijl | §8 | "het uitvoeren van een controle" → "controleren" |
| fungeert als, vormt, kenmerkt zich door | §8 copula avoidance | → "is" |
| zorgt ervoor dat | §8 | "zorgt ervoor dat je sneller werkt" → "je werkt sneller" |
| biedt de mogelijkheid om / stelt je in staat om | §8 | → "kan" |
| niet alleen X, maar ook Y | §9 | Zeg X. Zeg dan Y. |
| ..., geen gedoe. / ..., zonder zorgen. | §9 tailing negation | Maak er een hele zin van. |
| snel, veilig en betrouwbaar | §10 rule of three | Kies het bijvoeglijk naamwoord dat je kunt bewijzen. |
| of het nu gaat om X, Y of Z | §12 false range | Noem de gevallen die echt bestaan. |
| van A tot Z | §12 | Idem. |
| een breed scala aan, een verscheidenheid aan | §12 | Noem er twee. |

## Openers and closers

| Tell | Pattern |
| ---- | ------- |
| In de wereld van X / In het landschap van | §4 promotional |
| In de huidige maatschappij / Tegenwoordig zien we dat | §1 significance inflation |
| Wanneer het aankomt op | §7, leenvertaling van "when it comes to" |
| Ontdek / Duik in / We nemen je mee | §28 signposting |
| Kortom / Al met al / Samengevat | §25 generic positive conclusion |
| Wij bij [merk] geloven dat | §4, leenvertaling van "We at X believe" |

## Punctuation

Dutch typography does not use the spaced em dash the way English marketing copy
does. §14 still applies, and a `—` in Dutch text is a stronger tell than in
English, not a weaker one. Same for the ellipsis as a dramatic pause.

## What this rule does not decide

Register is a positioning choice, not a language fact. Whether the reader is
addressed as *je* or *u*, how formal the brand sounds, which words are banned
for brand reasons: that belongs in the project's
`.agents/memory/project/copy-context.md`, not here. This rule only names what
reads as machine-written in any Dutch text.
