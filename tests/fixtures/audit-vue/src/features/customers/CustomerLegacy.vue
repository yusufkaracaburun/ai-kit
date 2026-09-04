<script>
// V2: Options-API SFC in a codebase that is otherwise <script setup> (🟡).
// V3: Vue 3 mixins: where a composable belongs — implicit property injection,
//     no test seam, silent name collisions (🟠).
const trackingMixin = { mounted() {} };

export default {
  mixins: [trackingMixin],
  data() {
    return { customers: [] };
  },
  methods: {
    reload() {
      this.customers = [];
    },
  },
};
</script>

<template>
  <ul />
</template>
