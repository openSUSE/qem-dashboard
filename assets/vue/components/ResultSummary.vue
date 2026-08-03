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
  // Jobs marked "@review:acceptable_for" this incident: not a genuine pass, but not blocking either.
  accepted: {btnClass: 'btn-warning', iconClass: 'fa-check-circle', label: 'accepted jobs'},
  passed: {btnClass: 'btn-success', iconClass: 'fa-check-circle', label: 'passed jobs'}
};

const currentConfig = computed(() => stateConfig[state.value]);

// Jobs still genuinely failing while others in the same box were accepted for this incident - the box stays
// red (it's still blocking) but this badge makes the partial acceptance visible instead of hiding it.
const acceptedWhileFailing = computed(() => (state.value === 'failed' ? props.result.accepted || 0 : 0));

const counts = computed(() => {
  const stopped = props.result.stopped || 0;
  const passed = props.result.passed || 0;
  const waiting = props.result.waiting || 0;
  const failed = props.result.failed || 0;
  const accepted = props.result.accepted || 0;
  const total = stopped + failed + waiting + passed + accepted;

  if (state.value === 'passed') return total;
  if (state.value === 'failed') return `${failed}/${total}`;
  if (state.value === 'stopped') return `${stopped}/${total}`;
  if (state.value === 'waiting') return `${waiting}/${total}`;
  if (state.value === 'accepted') return `${accepted}/${total}`;
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
  searchParams.append('not_group_glob', configStore.openqaNotGroupGlob);
  return `${configStore.openqaUrl}?${searchParams.toString()}`;
});
</script>

<template>
  <a
    v-if="currentConfig"
    :href="link"
    class="btn d-inline-flex flex-column align-items-center"
    :class="currentConfig.btnClass"
    target="_blank"
  >
    <span>
      <i class="fas me-1" :class="currentConfig.iconClass" aria-hidden="true"></i>
      {{ result.name }} <span class="badge bg-light text-dark">{{ counts }}</span>
      <span
        v-if="acceptedWhileFailing > 0"
        class="badge bg-warning text-dark ms-1"
        :title="`${acceptedWhileFailing} of the failed job(s) are marked @review:acceptable_for this incident`"
      >
        +{{ acceptedWhileFailing }} accepted
      </span>
    </span>
    <small class="opacity-75 subtitle" :class="{invisible: !$slots.subtitle}">
      <slot name="subtitle">&nbsp;</slot>
    </small>
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
