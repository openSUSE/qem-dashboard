<template>
  <a v-if="failed > 0" :href="link" class="btn btn-danger" target="_blank">
    {{ result.name }} <span class="badge bg-light text-dark">{{ failed }}/{{ total }}</span>
    <span class="visually-hidden">failed jobs</span>
  </a>
  <a v-else-if="stopped > 0" :href="link" class="btn btn-secondary" target="_blank">
    {{ result.name }} <span class="badge bg-light text-dark">{{ stopped }}/{{ total }}</span>
    <span class="visually-hidden">stopped jobs</span>
  </a>
  <a v-else-if="waiting > 0" :href="link" class="btn btn-primary" target="_blank">
    {{ result.name }} <span class="badge bg-light text-dark">{{ waiting }}/{{ total }}</span>
    <span class="visually-hidden">waiting jobs</span>
  </a>
  <a v-else-if="passed == total" :href="link" class="btn btn-success" target="_blank">
    {{ result.name }} <span class="badge bg-light text-dark">{{ total }}</span>
    <span class="visually-hidden">passed jobs</span>
  </a>
  <a v-else> {{ result.name }} is problematic </a>
</template>

<script>
export default {
  name: 'ResultSummary',
  props: {result: {type: Object, required: true}},
  computed: {
    link() {
      const searchParams = new URLSearchParams(this.result.linkinfo);
      // Arrays are handled incompatible to how openQA expects it
      if (Array.isArray(this.result.linkinfo.flavor)) {
        searchParams.delete('flavor');
        this.result.linkinfo.flavor.forEach(flavor => {
          searchParams.append('flavor', flavor);
        });
      }
      searchParams.delete('distri');
      return `${this.appConfig.openqaUrl}?${searchParams.toString()}`;
    },
    stopped() {
      return this.result.stopped || 0;
    },
    passed() {
      return this.result.passed || 0;
    },
    waiting() {
      return this.result.waiting || 0;
    },
    failed() {
      return this.result.failed || 0;
    },
    total() {
      return this.stopped + this.failed + this.waiting + this.passed;
    }
  }
};
</script>
