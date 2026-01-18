<script setup>
import {computed} from 'vue';
import {useSubmissionStore} from '@/stores/submissions';
import {useConfigStore} from '@/stores/config';
import {usePolling} from '../composables/polling';
import SubmissionLink from './SubmissionLink.vue';

const submissionStore = useSubmissionStore();
const configStore = useConfigStore();

usePolling(() => submissionStore.fetchSubmissions());

const testingSubmissions = computed(() =>
  submissionStore.submissions.filter(submission => submission.rr_number > 0 && !submission.approved)
);
const stagedSubmissions = computed(() =>
  submissionStore.submissions.filter(submission => !submission.rr_number && !submission.approved)
);
const approvedSubmissions = computed(() => submissionStore.submissions.filter(submission => submission.approved));
const smelt = computed(() => configStore.smeltUrl);
</script>

<template>
  <div v-if="submissionStore.isLoading && submissionStore.submissions.length === 0" aria-hidden="true">
    <table class="table placeholder-glow">
      <thead>
        <tr>
          <th><span class="placeholder col-4"></span></th>
          <th><span class="placeholder col-2"></span></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="i in 5" :key="i">
          <td><span class="placeholder col-8"></span></td>
          <td><span class="placeholder col-4"></span></td>
        </tr>
      </tbody>
    </table>
  </div>
  <table class="table" v-else-if="submissionStore.submissions.length > 0">
    <thead>
      <tr>
        <th>Submission</th>
        <th>State</th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="submission in testingSubmissions" :key="submission.number">
        <td><SubmissionLink :incident="submission" /></td>
        <td>
          <a :href="'/blocked#' + submission.number">
            <span class="badge bg-primary">testing</span>
          </a>
        </td>
      </tr>
      <tr v-for="submission in stagedSubmissions" :key="submission.number">
        <td><SubmissionLink :incident="submission" /></td>
        <td><span class="badge bg-secondary">staged</span></td>
      </tr>
      <tr v-for="submission in approvedSubmissions" :key="submission.number">
        <td><SubmissionLink :incident="submission" /></td>
        <td><span class="badge bg-success">approved</span></td>
      </tr>
    </tbody>
  </table>
  <div v-else>No active submissions, maybe take a look at <a :href="smelt">Smelt</a>.</div>
</template>

<script>
export default {
  name: 'PageActive'
};
</script>
