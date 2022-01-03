<template>
  <div class="card mb-3">
    <div class="card-header">
      Build {{ build }} <span class="badge badge-secondary">{{ NumberOfPassed }} passed</span>
    </div>
    <div class="card-body text-left">
      <p v-for="group of interestingGroups" :key="group.build">
        <strong>
          <a :href="group.link">{{ group.build }}</a>
        </strong>
        -
        <span v-for="(element, index) in group.summary" :key="element">
          <span v-if="index != 0">, </span>
          <mark>{{ element }}</mark>
        </span>
      </p>
    </div>
  </div>
</template>

<script>
export default {
  name: 'IncidentBuildSummary',
  props: {build: {type: String, required: true}, jobs: {type: Array, required: true}},
  computed: {
    NumberOfPassed() {
      return this.jobs.filter(job => job.status === 'passed').length;
    },
    interestingGroups() {
      const groups = new Map(),
        links = new Map();
      for (const job of this.jobs) {
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
      for (const [build, stat] of groups) {
        const summary = [];
        for (const [key, value] of stat.entries()) {
          summary.push(`${value} ${key}`);
        }
        const searchParams = new URLSearchParams(links.get(build));
        ret.push({build, link: `${this.appConfig.openqaUrl}?${searchParams.toString()}`, summary: summary.sort()});
      }
      return ret.sort((a, b) => a.build.localeCompare(b.build));
    }
  }
};
</script>
