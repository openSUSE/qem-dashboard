<template>
  <div class="d-flex align-items-center">
    <router-link
      class="incident-link me-1"
      :to="{name: 'incident', params: {id: incident.number}}"
      :title="highPriority ? 'Incident with priority > 650: Focus on review and consider manual approval' : ''"
    >
      {{ incident.number }}:{{ packageName }}
      <i v-if="highPriority" class="fas fa-triangle-exclamation"></i>
    </router-link>
    <button
      class="btn btn-link btn-sm p-0 text-muted"
      @click="copyToClipboard"
      title="Copy incident number to clipboard"
      aria-label="Copy incident number"
    >
      <i :class="['fas', copied ? 'fa-check' : 'fa-copy']" aria-hidden="true"></i>
    </button>
  </div>
</template>

<script setup>
import {ref, computed} from 'vue';

const props = defineProps({
  incident: {type: Object, required: true},
  highPriority: {type: Boolean, default: false}
});

const copied = ref(false);

const packageName = computed(() => props.incident.packages[0]);

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

<script>
export default {
  name: 'IncidentLink'
};
</script>

<style>
a.incident-link {
  text-decoration: none;
}
</style>
