<script setup lang="ts">
// V7: Top-level await makes this an async component; no callsite wraps it in
// <Suspense>, so it silently never renders and a rejection has no handler (🟠).
const res = await fetch("/api/orders");
const orders = await res.json();
</script>

<template>
  <section>{{ orders.length }}</section>
</template>
