<script setup>
import {computed} from 'vue';
import {useModalStore} from '@/stores/modal';
import ResultSummary from './ResultSummary.vue';
import {Modal} from 'bootstrap';

const props = defineProps({
  repo: {type: Object, required: true},
  name: {type: String, required: true}
});

const modalStore = useModalStore();

const incidentNumber = computed(() => props.repo.incidents.length);

const triggerModal = () => {
  modalStore.showIncidents(props.name, props.repo.incidents);
  const myModal = new Modal(document.getElementById('update-incidents'));
  myModal.show();
};
</script>

<template lang="html">
  <tr>
    <td>
      <div>{{ name }}</div>
      <div class="text-left">
        <button type="button" class="btn btn-primary btn-sm" @click="triggerModal">
          <span class="badge bg-light text-dark">
            {{ incidentNumber }}
          </span>
          Incidents
        </button>
      </div>
    </td>
    <td>
      <ul class="summary-list">
        <li v-for="result in repo.summaries" :key="result.name">
          <ResultSummary :result="result" />
        </li>
      </ul>
    </td>
  </tr>
</template>

<script>
export default {
  name: 'RepoLine'
};
</script>
