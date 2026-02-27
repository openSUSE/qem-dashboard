<script setup>
import {computed} from 'vue';
import {useConfigStore} from '@/stores/config';
import {getResultState} from '../helpers/filtering.js';

const props = defineProps({
  result: {type: Object, required: true}
});

const configStore = useConfigStore();

const state = computed(() => getResultState(props.result));

const stateConfig = {
  failed: {btnClass: 'btn-danger', iconClass: 'fa-times-circle', label: 'failed jobs'},
  stopped: {btnClass: 'btn-secondary', iconClass: 'fa-stop-circle', label: 'stopped jobs'},
  waiting: {btnClass: 'btn-primary', iconClass: 'fa-clock', label: 'waiting jobs'},
  passed: {btnClass: 'btn-success', iconClass: 'fa-check-circle', label: 'passed jobs'}
};

const currentConfig = computed(() => stateConfig[state.value]);

const counts = computed(() => {
  const stopped = props.result.stopped || 0;
  const passed = props.result.passed || 0;
  const waiting = props.result.waiting || 0;
  const failed = props.result.failed || 0;
  const total = stopped + failed + waiting + passed;

  if (state.value === 'passed') return total;
  if (state.value === 'failed') return `${failed}/${total}`;
  if (state.value === 'stopped') return `${stopped}/${total}`;
  if (state.value === 'waiting') return `${waiting}/${total}`;
  return total;
});

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
  <a v-if="currentConfig" :href="link" class="btn" :class="currentConfig.btnClass" target="_blank">
    <i class="fas me-1" :class="currentConfig.iconClass" aria-hidden="true"></i>
    {{ result.name }} <span class="badge bg-light text-dark">{{ counts }}</span>
    <span class="visually-hidden">{{ currentConfig.label }}</span>
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
