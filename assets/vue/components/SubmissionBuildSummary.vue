<script setup>
import {computed} from 'vue';
import {useConfigStore} from '@/stores/config';

const props = defineProps({
  build: {type: String, required: true},
  jobs: {type: Array, required: true}
});

const configStore = useConfigStore();

const NumberOfPassed = computed(() => props.jobs.filter(job => job.status === 'passed').length);

const interestingGroups = computed(() => {
  const groups = new Map();
  const links = new Map();
  const statusClasses = {
    passed: 'bg-success',
    failed: 'bg-danger',
    stopped: 'bg-secondary',
    waiting: 'bg-primary'
  };
  const statusIcons = {
    passed: 'fa-check-circle',
    failed: 'fa-times-circle',
    stopped: 'fa-stop-circle',
    waiting: 'fa-clock'
  };
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
    for (const [key, value] of stat.entries()) {
      summary.push({
        count: value,
        text: key,
        class: statusClasses[key] || 'bg-dark',
        icon: statusIcons[key] || 'fa-exclamation-triangle'
      });
    }
    const searchParams = new URLSearchParams(links.get(groupBuild));
    ret.push({
      build: groupBuild,
      link: `${configStore.openqaUrl}?${searchParams.toString()}`,
      summary: summary.sort((a, b) => a.text.localeCompare(b.text))
    });
  }
  return ret.sort((a, b) => a.build.localeCompare(b.build));
});
</script>

<template>
  <div class="card mb-3">
    <div class="card-header">
      Build {{ build }}
      <span class="badge bg-success">
        <i class="fas fa-check-circle me-1" aria-hidden="true"></i>{{ NumberOfPassed }} passed
      </span>
    </div>
    <div class="card-body text-left">
      <p v-for="group of interestingGroups" :key="group.build">
        <a :href="group.link" target="_blank">{{ group.build }}</a>
        -
        <span v-for="part in group.summary" :key="part.text" :class="['badge', part.class, 'me-1']">
          <i :class="['fas', part.icon, 'me-1']" aria-hidden="true"></i>
          {{ part.count }} {{ part.text }}
        </span>
      </p>
    </div>
  </div>
</template>

<script>
export default {
  name: 'SubmissionBuildSummary'
};
</script>
