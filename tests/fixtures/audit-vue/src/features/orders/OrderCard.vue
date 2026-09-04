<script setup lang="ts">
// V4: Props-bloat — 9 props on one SFC (🟠).
// V8: Runtime-object defineProps in a TS SFC — no compile-time contract (🟠).
defineProps({
  id: { type: String, required: true },
  title: { type: String, required: true },
  subtitle: { type: String, default: "" },
  total: { type: Number, required: true },
  currency: { type: String, default: "EUR" },
  status: { type: String, default: "open" },
  createdAt: { type: String, required: true },
  customerName: { type: String, required: true },
  isHighlighted: { type: Boolean, default: false },
});
</script>

<template>
  <article />
</template>
