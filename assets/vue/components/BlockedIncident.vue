<template>
  <tr>
    <td>
      <IncidentLink :incident="incident" />
    </td>
    <td>
      <div v-if="Object.keys(incidentResults).length + Object.keys(updateResults).length === 0">No data yet</div>
      <ul v-else class="summary-list">
        <BlockedIncidentIncResult
          v-for="(result, group_id) in incidentResultsGrouped"
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
    groupFlavors: {type: Boolean, required: true},
    groupNames: {type: String, required: true}
  },
  computed: {
    updateResultsGrouped() {
      if (!this.groupFlavors) return this.updateResults;
      const results = {};
      const groupNamesList = this.groupNames.toLowerCase().split(',');
      for (const value of Object.values(this.updateResults)) {
        const {flavor} = value.linkinfo;
        const {version} = value.linkinfo;
        const {groupid} = value.linkinfo;
        const newkey = `${groupid}:${version}`;
        if (groupNamesList.includes(value.name.toLowerCase()) || this.groupNames === '') {
          const res = (results[newkey] = {
            name: value.name,
            passed: 0,
            failed: 0,
            stopped: 0,
            waiting: 0,
            linkinfo: {...value.linkinfo, flavor: []}
          });
          res.linkinfo.flavor.push(flavor);
          res.passed += value.passed || 0;
          res.stopped += value.stopped || 0;
          res.waiting += value.waiting || 0;
          res.failed += value.failed || 0;
        }
      }
      return results;
    },
    incidentResultsGrouped() {
      if (this.groupNames === '') return this.incidentResults;
      const results = [];
      const groupNamesList = this.groupNames.toLowerCase().split(',');
      for (const value of Object.values(this.incidentResults)) {
        if (groupNamesList.includes(value.name.toLowerCase())) results.push(value);
      }
      return results;
    }
  }
};
</script>
