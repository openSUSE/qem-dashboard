<script setup>
import {computed} from 'vue';
import {useConfigStore} from '@/stores/config';

const props = defineProps({
  incident: {type: Object, required: true}
});

const configStore = useConfigStore();

const smeltLink = computed(() => `${configStore.smeltUrl}/incident/${props.incident.number}`);
const packageName = computed(() => props.incident.packages[0]);
</script>

<template>
  <div class="submission-link">
    <a :href="smeltLink" target="_blank">{{ incident.number }}:{{ packageName }}</a>
  </div>
</template>

<script>
export default {
  name: 'SmeltLink'
};
</script>
