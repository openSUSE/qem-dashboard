<script setup>
import {computed} from 'vue';
import {useConfigStore} from '@/stores/config';
import {firstPackage, getGitSmeltUrl} from '../utils/smelt';

const props = defineProps({
  incident: {type: Object, required: true}
});

const configStore = useConfigStore();

const packageName = computed(() => firstPackage(props.incident));

const sourceUrl = computed(() =>
  props.incident.type === 'git' || !props.incident.rr_number
    ? props.incident.url
    : `${configStore.obsUrl}/request/show/${props.incident.rr_number}`
);

const linkText = computed(() =>
  props.incident.type === 'git'
    ? `PR #${props.incident.number}`
    : props.incident.rr_number
      ? `${props.incident.rr_number}:${packageName.value}`
      : packageName.value || 'Source'
);

const sourceIcon = computed(() => (props.incident.type === 'git' ? 'fas fa-code-branch' : 'fas fa-box-open'));

const gitSmeltUrl = computed(() => getGitSmeltUrl(props.incident, configStore.smeltUrl));
</script>

<template>
  <div class="submission-link d-flex align-items-center gap-2">
    <a :href="sourceUrl" target="_blank" class="rr-link">
      <i :class="sourceIcon"></i>
      {{ linkText }}
    </a>
    <a
      v-if="gitSmeltUrl"
      :href="gitSmeltUrl"
      target="_blank"
      class="badge bg-secondary text-decoration-none"
      title="Link to SMELT (SLFO-Beta)"
    >
      SMELT
    </a>
  </div>
</template>

<script>
export default {
  name: 'RequestLink'
};
</script>
