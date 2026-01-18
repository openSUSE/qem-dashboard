<script setup>
import {computed} from 'vue';
import {useConfigStore} from '@/stores/config';

const props = defineProps({
  result: {type: Object, required: true}
});

const configStore = useConfigStore();

const stopped = computed(() => props.result.stopped || 0);
const passed = computed(() => props.result.passed || 0);
const waiting = computed(() => props.result.waiting || 0);
const failed = computed(() => props.result.failed || 0);
const total = computed(() => stopped.value + failed.value + waiting.value + passed.value);

const link = computed(() => {
  const searchParams = new URLSearchParams(props.result.linkinfo);
  // Arrays are handled incompatible to how openQA expects it
  if (Array.isArray(props.result.linkinfo.flavor)) {
    searchParams.delete('flavor');
    props.result.linkinfo.flavor.forEach(flavor => {
      searchParams.append('flavor', flavor);
    });
  }
  searchParams.delete('distri');
  return `${configStore.openqaUrl}?${searchParams.toString()}`;
});
</script>

<template>
  <a v-if="failed > 0" :href="link" class="btn btn-danger" target="_blank">
    <i class="fas fa-times-circle me-1" aria-hidden="true"></i>
    {{ result.name }} <span class="badge bg-light text-dark">{{ failed }}/{{ total }}</span>
    <span class="visually-hidden">failed jobs</span>
  </a>
  <a v-else-if="stopped > 0" :href="link" class="btn btn-secondary" target="_blank">
    <i class="fas fa-stop-circle me-1" aria-hidden="true"></i>
    {{ result.name }} <span class="badge bg-light text-dark">{{ stopped }}/{{ total }}</span>
    <span class="visually-hidden">stopped jobs</span>
  </a>
  <a v-else-if="waiting > 0" :href="link" class="btn btn-primary" target="_blank">
    <i class="fas fa-clock me-1" aria-hidden="true"></i>
    {{ result.name }} <span class="badge bg-light text-dark">{{ waiting }}/{{ total }}</span>
    <span class="visually-hidden">waiting jobs</span>
  </a>
  <a v-else-if="passed == total && total > 0" :href="link" class="btn btn-success" target="_blank">
    <i class="fas fa-check-circle me-1" aria-hidden="true"></i>
    {{ result.name }} <span class="badge bg-light text-dark">{{ total }}</span>
    <span class="visually-hidden">passed jobs</span>
  </a>
  <a v-else>
    <i class="fas fa-exclamation-triangle me-1" aria-hidden="true"></i>
    {{ result.name }} is problematic
  </a>
</template>

<script>
export default {
  name: 'ResultSummary'
};
</script>
