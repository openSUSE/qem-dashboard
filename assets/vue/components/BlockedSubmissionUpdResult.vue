<script setup>
import {computed} from 'vue';
import ResultSummary from './ResultSummary.vue';

const props = defineProps({
  result: {type: Object, required: true},
  groupId: {type: String, required: true},
  groupFlavors: Boolean
});

const title = computed(() => {
  if (props.groupFlavors) {
    return `Aggregate: ${props.result.linkinfo.version}`;
  }
  return `Aggregate: ${props.result.linkinfo.flavor}-${props.result.linkinfo.version}`;
});
</script>

<template>
  <li :group-id="groupId" data-bs-toggle="tooltip" data-bs-placement="left" :title="title">
    <ResultSummary :result="result" />
  </li>
</template>

<script>
export default {
  name: 'BlockedSubmissionUpdResult'
};
</script>
