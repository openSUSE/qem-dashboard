<script setup>
import {useModalStore} from '@/stores/modal';
import IncidentLink from './IncidentLink.vue';

const modalStore = useModalStore();
</script>

<template>
  <div
    tabindex="-1"
    role="dialog"
    class="modal fade"
    id="update-incidents"
    aria-labelledby="modal-title"
    aria-hidden="true"
  >
    <div class="modal-dialog" role="document">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title" id="modal-title">Incidents for {{ modalStore.title }}</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <div class="modal-body">
          <ul>
            <li v-for="incident in modalStore.incidents" :key="incident.number">
              <IncidentLink :incident="incident" />
            </li>
          </ul>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'RepoIncidentDialog'
};
</script>
