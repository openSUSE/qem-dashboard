<script setup>
import {computed} from 'vue';
import StatusBadge from './StatusBadge.vue';

const props = defineProps({
  build: {type: String, required: true},
  jobs: {type: Array, required: true}
});

const NumberOfPassed = computed(() => props.jobs.filter(job => job.status === 'passed').length);

const passedBaseParams = computed(() => {
  const firstJob = props.jobs[0];
  if (!firstJob) return {};
  return {
    version: firstJob.version,
    groupid: firstJob.group_id,
    flavor: firstJob.flavor,
    distri: firstJob.distri,
    build: firstJob.build
  };
});

const interestingGroups = computed(() => {
  const groups = new Map();
  const links = new Map();
  for (const job of props.jobs) {
    if (job.status === 'passed') continue;
    const key = `${job.job_group}@${job.flavor}`;
    if (!groups.get(key)) {
      groups.set(key, new Map());
      links.set(key, {
        version: job.version,
        groupid: job.group_id,
        flavor: job.flavor,
        distri: job.distri,
        build: job.build
      });
    }
    groups.get(key).set(job.status, (groups.get(key).get(job.status) || 0) + 1);
  }
  const ret = [];
  for (const [groupBuild, stat] of groups) {
    const summary = [];
    for (const [status, count] of stat.entries()) {
      summary.push({count, status});
    }
    ret.push({
      build: groupBuild,
      baseParams: links.get(groupBuild),
      summary: summary.sort((a, b) => a.status.localeCompare(b.status))
    });
  }
  return ret.sort((a, b) => a.build.localeCompare(b.build));
});
</script>

<template>
  <div class="card mb-3">
    <div class="card-header">
      Build {{ build }}
      <StatusBadge v-if="NumberOfPassed" status="passed" :count="NumberOfPassed" :base-params="passedBaseParams" />
    </div>
    <div class="card-body text-left">
      <p v-for="group of interestingGroups" :key="group.build">
        {{ group.build }} -
        <StatusBadge
          v-for="part in group.summary"
          :key="part.status"
          :status="part.status"
          :count="part.count"
          :base-params="group.baseParams"
        />
      </p>
    </div>
  </div>
</template>

<script>
export default {
  name: 'SubmissionBuildSummary'
};
</script>
