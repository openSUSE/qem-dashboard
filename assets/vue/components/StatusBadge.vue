<template>
  <a :href="link" target="_blank" :class="['badge', badgeClass, 'me-1', 'text-decoration-none']">
    <i :class="['fas', iconClass, 'me-1']" aria-hidden="true"></i>
    {{ count }} {{ text || status }}
  </a>
</template>

<script setup>
import {computed} from 'vue';
import {useConfigStore} from '@/stores/config';
import {statusClasses, statusIcons} from '@/vue/constants/status';
import {getOpenQALink} from '@/vue/utils/openqa';

const props = defineProps({
  status: {type: String, required: true},
  count: {type: [Number, String], required: true},
  text: {type: String, default: ''},
  baseParams: {type: Object, required: true}
});

const configStore = useConfigStore();
const badgeClass = computed(() => statusClasses[props.status] || 'bg-dark');
const iconClass = computed(() => statusIcons[props.status] || 'fa-exclamation-triangle');
const link = computed(() => getOpenQALink(configStore.openqaUrl, props.baseParams, props.status));
</script>

<script>
export default {
  name: 'StatusBadge'
};
</script>
