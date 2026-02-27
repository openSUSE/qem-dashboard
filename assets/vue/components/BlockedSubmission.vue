<script setup>
import {computed} from 'vue';
import BlockedSubmissionSubResult from './BlockedSubmissionSubResult.vue';
import BlockedSubmissionUpdResult from './BlockedSubmissionUpdResult.vue';
import SubmissionLink from './SubmissionLink.vue';
import SubmissionDetailsIcons from './SubmissionDetailsIcons.vue';
import * as filtering from '../helpers/filtering.js';

const props = defineProps({
  submission: {type: Object, required: true},
  submissionResults: {type: Object, required: true},
  updateResults: {type: Object, required: true},
  groupFlavors: {type: Boolean, required: true},
  groupFilters: {type: Array, required: true},
  selectedStates: {type: Array, required: true}
});

const filterByTextAndState = result =>
  filtering.checkResult(result, props.groupFilters) && filtering.checkState(result, props.selectedStates);

const updateResultsGrouped = computed(() => {
  const filtered = Object.values(props.updateResults).filter(res => filtering.checkResult(res, props.groupFilters));

  if (props.groupFlavors === false) {
    return filtered.filter(res => filtering.checkState(res, props.selectedStates));
  }

  const grouped = filtered.reduce((acc, value) => {
    const {flavor, version, groupid} = value.linkinfo;
    const key = `${groupid}:${version}`;

    if (!acc[key]) {
      acc[key] = {
        name: value.name,
        passed: 0,
        failed: 0,
        stopped: 0,
        waiting: 0,
        linkinfo: {...value.linkinfo, flavor: []}
      };
    }

    const res = acc[key];
    res.linkinfo.flavor.push(flavor);
    res.passed += value.passed || 0;
    res.stopped += value.stopped || 0;
    res.waiting += value.waiting || 0;
    res.failed += value.failed || 0;
    return acc;
  }, {});

  return Object.fromEntries(
    Object.entries(grouped).filter(([, res]) => filtering.checkState(res, props.selectedStates))
  );
});

const submissionResultsGrouped = computed(() => Object.values(props.submissionResults).filter(filterByTextAndState));
</script>

<template>
  <tr :class="{'high-priority': submission.priority > 650}">
    <td>
      <div class="d-flex flex-column gap-1">
        <SubmissionLink :incident="submission" :high-priority="submission.priority > 650" />
        <SubmissionDetailsIcons :incident="submission" />
      </div>
    </td>
    <td>
      <div v-if="Object.keys(submissionResults).length + Object.keys(updateResults).length === 0">No data yet</div>
      <ul v-else class="summary-list">
        <BlockedSubmissionSubResult
          v-for="(result, group_id) in submissionResultsGrouped"
          :key="group_id"
          :group-id="group_id"
          :result="result"
        />
        <BlockedSubmissionUpdResult
          v-for="(result, groupId) in updateResultsGrouped"
          :key="groupId"
          :group-id="groupId"
          :result="result"
          :group-flavors="groupFlavors"
        />
      </ul>
    </td>
  </tr>
</template>

<script>
export default {
  name: 'BlockedSubmission'
};
</script>

<style>
.high-priority {
  background: repeating-linear-gradient(
    45deg,
    transparent,
    transparent 10px,
    var(--bs-warning-bg-subtle) 10px,
    var(--bs-warning-bg-subtle) 20px
  );
}
.high-priority td {
  background-color: initial;
}
.high-priority td:nth-child(1) a {
  font-weight: bold;
}
</style>
