<script setup>
import {computed} from 'vue';
import {useConfigStore} from '@/stores/config';
import {firstPackage, getGitSmeltUrl} from '../utils/smelt';

const props = defineProps({
  incident: {type: Object, required: true}
});

const configStore = useConfigStore();

const smeltLink = computed(
  () =>
    getGitSmeltUrl(props.incident, configStore.smeltUrl) ?? `${configStore.smeltUrl}/incident/${props.incident.number}`
);

const linkText = computed(() =>
  props.incident.type === 'git' ? 'SMELT' : `${props.incident.number}:${firstPackage(props.incident)}`
);
</script>

<template>
  <div class="submission-link">
    <a :href="smeltLink" target="_blank">{{ linkText }}</a>
  </div>
</template>

<script>
export default {
  name: 'SmeltLink'
};
</script>
