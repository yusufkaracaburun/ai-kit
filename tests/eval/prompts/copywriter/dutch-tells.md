---
id: dutch-tells
skill: copywriter
expects:
  - loads copy-nl.mini.md because the text is Dutch, without being told to
  - flags the stacked connectives ("Daarnaast", "Bovendien")
  - flags "Het is belangrijk om te vermelden dat" as announcement instead of content
  - flags "of het nu gaat om" as a false range (§12)
  - flags "snel, veilig en betrouwbaar" as rule of three (§10)
  - flags "stelt je in staat om" / "zorgt ervoor dat" as copula avoidance (§8)
  - flags "naadloos" as a seamless calque
  - flags the em dashes around "al jaren de standaard" (§14)
  - names the section number each Dutch tell maps onto
  - does not decide je/u register — says that belongs in copy-context
  - returns the rewrite in Dutch
---

# Prompt

Humaniseer deze tekst. Hij moet Nederlands blijven.

In de wereld van moderne softwarekoppelingen is het belangrijk om te vermelden
dat integraties cruciaal zijn geworden. Daarnaast zorgt ons platform ervoor dat
je sneller werkt. Bovendien stelt het je in staat om naadloos te schakelen
tussen systemen, of het nu gaat om boekhouding, betalingen of klantbeheer.

Ons platform — al jaren de standaard — fungeert als de perfecte oplossing
voor bedrijven die willen groeien. Het is snel, veilig en betrouwbaar. Kortom, een must voor elke
organisatie die vooruit wil.
