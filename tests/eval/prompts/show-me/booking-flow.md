---
id: booking-flow
skill: show-me
expects:
  - answers with a drawing, not a paragraph describing the drawing
  - picks ONE view (a call tree here, since the question is about runtime order)
  - uses real names from the prompt (BookingController::store, SendConfirmationMail)
  - shows the queued job as queued, so the async boundary is visible
  - does NOT also emit a component tree, a file tree and a Mermaid diagram
  - keeps prose to a sentence or two beside the drawing
---

# Prompt

I'm reading `BookingController::store()` and I can't keep the order straight.
Validation, the model write, the event, the confirmation mail, the redirect.
What actually happens, and in what order? Show me.
