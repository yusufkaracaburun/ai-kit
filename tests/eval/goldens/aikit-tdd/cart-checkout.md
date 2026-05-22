---
id: cart-checkout
skill: aikit-tdd
required_headings:
  - "## First failing test"
  - "## Minimal implementation"
  - "## What I deliberately did NOT do"
required_keywords:
  - "public interface"
  - "behaviour"
  - "vertical slice"
  - "horizontal-slice"
  - "red"
  - "green"
required_phrases:
  - "ONE failing test"
forbidden_keywords:
  - "TODO"
  - "FIXME"
  - "[fill in]"
min_lines: 40
max_lines: 250
---

# Hand-written golden output for `aikit-tdd` / `cart-checkout`

This file represents an *ideal* TDD walkthrough response. The model is being
asked to demonstrate the first red-green cycle for a shopping cart. The
critical thing the response must do is resist the temptation to write *all*
the tests up-front (horizontal slicing) and instead deliver a single vertical
slice.

---

I'll walk through ONE red-green-refactor cycle and stop. Adding the next test
comes after we've seen this one go green — that's what makes TDD work as a
design tool instead of a structure-design exercise.

## First failing test

The smallest behaviour I can verify through the cart's public interface is:
*an empty cart has a total of zero*. That sounds trivial, but it forces the
test to choose the public interface ("how does a caller construct a cart?
how do they ask for the total?") before any implementation exists.

```ts
import { describe, expect, it } from 'vitest';
import { Cart } from './cart';

describe('Cart', () => {
  it('starts empty with a total of zero', () => {
    const cart = new Cart();
    expect(cart.total()).toBe(0);
  });
});
```

Run it — fails. The `Cart` class does not exist yet. That is the **red** state.
The failure message tells me exactly the minimum I need to build next.

Notice what this test does NOT do:

- It does not touch any internal field or private method.
- It does not stub or mock anything; there's nothing to stub.
- It describes a behaviour ("starts empty with a total of zero"), not a shape.

The test reads like a sentence about the system's behaviour. That is the
mark of a test you can keep through refactors.

## Minimal implementation

The smallest thing that turns this test green:

```ts
export class Cart {
  total(): number {
    return 0;
  }
}
```

Yes — it returns a constant. That is correct TDD. The test only proved the
behaviour for an empty cart; the implementation is allowed to be exactly as
specific as the test demands. The next failing test (adding an item changes
the total) will force the implementation to grow. We let the tests pull the
design forward.

Run the test — it goes green. This is the moment to commit: a single behaviour
verified, a single minimal implementation, both alive.

If anything in the surrounding code is messy at this point, **refactor now**
while the test is still green. For one line of implementation there is
nothing to refactor, so we move to the next cycle.

## What I deliberately did NOT do

I am stopping here, not because we are done, but because the next behaviour
("adding an item increases the total") is its own red-green-refactor cycle.
Specifically:

- I did NOT write tests for "add item", "remove item", "apply discount", and
  "checkout" all up-front. That is the horizontal-slice anti-pattern: the
  bulk-written tests would describe *imagined* behaviour, not the behaviour
  that emerges as the design takes shape. They would also lock in the public
  interface before we have learned anything about it.
- I did NOT introduce a `LineItem`, `Discount`, or `Money` class. The test
  did not ask for them. Each will appear when a test forces it.
- I did NOT mock a pricing service or a discount engine. Mocks at this stage
  would couple the test to an implementation that does not exist yet.

The next vertical slice starts the same way: pick the single smallest
behaviour that moves us forward (probably "adding an item changes the total"),
write ONE failing test, watch it fail, write the minimal code, watch it pass,
refactor.

That is the loop. Vertical, one slice at a time, design pulled by behaviour.
