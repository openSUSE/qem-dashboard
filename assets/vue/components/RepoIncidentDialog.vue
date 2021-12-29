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
          <h5 class="modal-title" id="modal-title">Incidents for {{ title }}</h5>
          <button type="button" class="close" data-dismiss="modal" aria-label="Close">
            <span aria-hidden="true">&times;</span>
          </button>
        </div>
        <div class="modal-body">
          <ul>
            <li v-for="incident in incidents" :key="incident.number">
              <incident-link :incident="incident" />
            </li>
          </ul>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import IncidentLinkComponent from './IncidentLink.vue';

export default {
  name: 'RepoIncidentDialogComponent',
  components: {'incident-link': IncidentLinkComponent},
  data() {
    return {
      incidents: [],
      title: ''
    };
  }
};
</script>
