<script setup>
import {computed} from 'vue';
import {useRoute} from 'vue-router';
import {useSubmissionDetailStore} from '@/stores/submission_detail';
import {usePolling} from '../composables/polling';
import SubmissionBuildSummary from './SubmissionBuildSummary.vue';
import StatusBadge from './StatusBadge.vue';
import RequestLink from './RequestLink.vue';
import SmeltLink from './SmeltLink.vue';
import SubmissionDetailsIcons from './SubmissionDetailsIcons.vue';

const route = useRoute();
const submissionDetailStore = useSubmissionDetailStore();

usePolling(() => submissionDetailStore.fetchSubmission(route.params.id));

const results = computed(() => {
  if (!submissionDetailStore.summary) return [];
  const parts = [];

  if (submissionDetailStore.summary.passed) {
    parts.push({
      count: submissionDetailStore.summary.passed,
      status: 'passed'
    });
  }
  for (const [key, value] of Object.entries(submissionDetailStore.summary)) {
    if (key === 'passed') continue;
    parts.push({
      count: value,
      status: key
    });
  }
  return parts;
});

const baseParams = computed(() => ({build: submissionDetailStore.submission?.buildNr}));

const sortedBuilds = computed(() => {
  return Object.keys(submissionDetailStore.jobs).sort().reverse();
});
</script>

<template>
  <div v-if="submissionDetailStore.exists === false"><p>Submission does not exist.</p></div>
  <div v-else-if="submissionDetailStore.exists === true">
    <div class="d-flex align-items-center justify-content-between mb-3" v-if="submissionDetailStore.submission">
      <SubmissionDetailsIcons :incident="submissionDetailStore.submission" class="fs-4" />
    </div>

    <div class="external-links" v-if="submissionDetailStore.submission">
      <div class="packages">
        <h2>Packages</h2>
        <ul>
          <li v-for="pkg in submissionDetailStore.submission.packages" :key="pkg">
            {{ pkg }}
          </li>
        </ul>
      </div>
      <div class="smelt-link" v-if="(submissionDetailStore.submission.type || 'smelt') === 'smelt'">
        <h2>Link to Smelt</h2>
        <p>
          <SmeltLink :incident="submissionDetailStore.submission" />
        </p>
      </div>
      <div class="request-link">
        <h2>Source Link</h2>
        <p>
          <RequestLink :incident="submissionDetailStore.submission" />
        </p>
      </div>
    </div>

    <div class="submission-results" v-if="submissionDetailStore.submission">
      <h2>Per Submission Results</h2>
      <p v-if="!submissionDetailStore.submission.buildNr">No submission build found</p>
      <p v-else>
        <StatusBadge
          v-for="part in results"
          :key="part.status"
          :status="part.status"
          :count="part.count"
          :base-params="baseParams"
        />
      </p>
    </div>

    <div class="submission-aggregates" v-if="!!sortedBuilds.length">
      <h2>Aggregate Runs Including This Submission</h2>
      <SubmissionBuildSummary
        v-for="build in sortedBuilds"
        :key="build"
        :build="build"
        :jobs="submissionDetailStore.jobs[build]"
      />
    </div>

    <div class="details" v-if="submissionDetailStore.submission?.scminfo">
      <h2>Further details</h2>
      <table class="table table-sm">
        <tr>
          <th>SCM Info</th>
          <td>{{ submissionDetailStore.submission.scminfo }}</td>
        </tr>
      </table>
    </div>
  </div>
  <div v-else><i class="fas fa-sync fa-spin"></i> Loading submission...</div>
</template>
