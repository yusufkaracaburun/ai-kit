---
id: random-repo-stumble
skill: should-i-use
expects:
  - cites a path or a count from this project, not only the candidate's claims
  - leads with a single verdict (vendor / wire / adopt-as-pattern / ignore)
  - names whether the candidate overlaps with anything already in the project
  - says whether the value is concrete or generic marketing
  - flags cohesion impact (more tools ≠ higher quality)
  - ends with one next concrete step and one question for the user
---

# Prompt

I just saw this repo on Hacker News: https://github.com/example/yet-another-orm
— claims to be "the Prisma killer". We're already on Drizzle in our Next.js
project, ~80 files, two months old. Should I switch?
