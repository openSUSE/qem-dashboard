<script setup>
import {computed} from 'vue';
import {useConfigStore} from '@/stores/config';

const props = defineProps({
  incident: {type: Object, required: true}
});

const configStore = useConfigStore();

const packageName = computed(() =>
  props.incident.packages && props.incident.packages.length > 0 ? props.incident.packages[0] : ''
);

const sourceUrl = computed(() => {
  if (props.incident.type === 'git' || !props.incident.rr_number) {
    return props.incident.url;
  }
  return `${configStore.obsUrl}/request/show/${props.incident.rr_number}`;
});

const linkText = computed(() => {
  if (props.incident.rr_number) {
    return `${props.incident.rr_number}:${packageName.value}`;
  }
  return packageName.value || 'Source';
});

const sourceIcon = computed(() => {
  if (props.incident.type === 'git') {
    return 'fab fa-github'; // Gitea often uses github icon or git-alt
  }
  return 'fas fa-box-open';
});
</script>

<template>
  <div class="submission-link">
    <a :href="sourceUrl" target="_blank" class="rr-link">
      <i :class="sourceIcon"></i>
      {{ linkText }}
    </a>
  </div>
</template>

<script>
export default {
  name: 'RequestLink'
};
</script>
