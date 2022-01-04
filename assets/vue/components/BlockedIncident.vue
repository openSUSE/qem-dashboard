<template>
  <tr>
    <td>
      <IncidentLink :incident="incident" />
    </td>
    <td>
      <div v-if="Object.keys(incidentResults).length + Object.keys(updateResults).length === 0">No data yet</div>
      <ul v-else class="summary-list">
        <BlockedIncidentIncResult
          v-for="(result, group_id) in incidentResults"
          :key="group_id"
          :group-id="group_id"
          :result="result"
        />
        <BlockedIncidentUpdResult
          v-for="(result, groupId) in updateResultsGrouped"
          :key="groupId"
          :group-id="groupId"
          :result="result"
          :group-flavors="groupFlavors"
        />
      </ul>
    </td>
  </tr>
</template>

<script>
import BlockedIncidentIncResult from './BlockedIncidentIncResult.vue';
import BlockedIncidentUpdResult from './BlockedIncidentUpdResult.vue';
import IncidentLink from './IncidentLink.vue';

export default {
  name: 'BlockedIncident',
  components: {
    IncidentLink,
    BlockedIncidentIncResult,
    BlockedIncidentUpdResult
  },
  props: {
    incident: {type: Object, required: true},
    incidentResults: {type: Object, required: true},
    updateResults: {type: Object, required: true},
    groupFlavors: {type: Boolean, required: true}
  },
  computed: {
    updateResultsGrouped() {
      if (!this.groupFlavors) return this.updateResults;
      const results = {};
      for (const value of Object.values(this.updateResults)) {
        const {flavor} = value.linkinfo;
        const {version} = value.linkinfo;
        const {groupid} = value.linkinfo;
        const newkey = `${groupid}:${version}`;
        if (!(newkey in results)) {
          results[newkey] = {name: value.name, passed: 0, failed: 0, stopped: 0, waiting: 0};
          results[newkey].linkinfo = value.linkinfo;
          results[newkey].linkinfo.flavor = [];
        }
        results[newkey].linkinfo.flavor.push(flavor);
        results[newkey].passed += value.passed || 0;
        results[newkey].stopped += value.stopped || 0;
        results[newkey].waiting += value.waiting || 0;
        results[newkey].failed += value.failed || 0;
      }
      return results;
    }
  }
};
</script>
