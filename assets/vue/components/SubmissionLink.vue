<template>
  <div class="d-flex align-items-center">
    <router-link
      class="submission-link me-1"
      :to="{name: 'submission', params: {id: incident.number}, query: submissionQuery}"
      :title="highPriority ? 'Submission with priority > 650: Focus on review and consider manual approval' : ''"
    >
      {{ incident.number }}:{{ packageName }}
      <i v-if="highPriority" class="fas fa-triangle-exclamation"></i>
    </router-link>
    <button
      class="btn btn-link btn-sm p-0 text-muted"
      @click="copyToClipboard"
      title="Copy submission number to clipboard"
      aria-label="Copy submission number"
    >
      <i :class="['fas', copied ? 'fa-check' : 'fa-copy']" aria-hidden="true"></i>
    </button>
  </div>
</template>

<script setup>
import {ref, computed} from 'vue';

defineOptions({
  name: 'SubmissionLink'
});

const props = defineProps({
  incident: {type: Object, required: true},
  highPriority: {type: Boolean, default: false}
});

const copied = ref(false);

const packageName = computed(() => props.incident.packages[0]);

const submissionQuery = computed(() => {
  const query = {};
  if (props.incident.project) query.project = props.incident.project;
  // Keep an empty type too (the smelt default): omitting it makes the number
  // ambiguous when the same project also has a typed incident.
  if (props.incident.type !== undefined && props.incident.type !== null) query.type = props.incident.type;
  return query;
});

const copyToClipboard = async () => {
  try {
    await navigator.clipboard.writeText(props.incident.number.toString());
    copied.value = true;
    setTimeout(() => {
      copied.value = false;
    }, 2000);
  } catch (err) {
    console.error('Failed to copy: ', err);
  }
};
</script>

<style>
a.submission-link {
  text-decoration: none;
}
</style>
