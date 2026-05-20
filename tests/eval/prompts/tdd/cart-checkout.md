---
id: cart-checkout
skill: tdd
expects:
  - writes ONE failing test first, not several at once
  - test exercises behaviour through a public interface, not internal helpers
  - implements the minimal code to make the test pass before adding the next test
  - refactors AFTER green, with the test still passing
  - explicitly resists writing all tests up-front (horizontal-slice anti-pattern)
---

# Prompt

I'm building a shopping cart with a checkout flow: add items, apply a discount
code, checkout. I want to TDD this. Walk me through the first cycle — show me
what you'd write first and why.
