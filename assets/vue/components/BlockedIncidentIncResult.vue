<script setup>
import ResultSummary from './ResultSummary.vue';

defineProps({
  result: {type: Object, required: true},
  groupId: {type: String, required: true}
});
</script>

<template>
  <li :data-group-id="groupId">
    <ResultSummary :result="result" />
  </li>
</template>

<script>
export default {
  name: 'BlockedIncidentIncResult'
};
</script>
