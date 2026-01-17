<template>
  <tr :class="{'high-priority': incident.priority > 650}">
    <td>
      <div class="d-flex flex-column gap-1">
        <IncidentLink :incident="incident" :high-priority="incident.priority > 650" />
        <IncidentDetailsIcons :incident="incident" />
      </div>
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
import IncidentDetailsIcons from './IncidentDetailsIcons.vue';
import * as filtering from '../helpers/filtering.js';

export default {
  name: 'BlockedIncident',
  components: {
    IncidentLink,
    IncidentDetailsIcons,
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
      if (this.groupFlavors === false) return this.updateResults;
      const results = {};
      const filters = filtering.makeGroupNamesFilters(this.groupNames);
      for (const value of Object.values(this.updateResults)) {
        const {flavor} = value.linkinfo;
        const {version} = value.linkinfo;
        const {groupid} = value.linkinfo;
        const newkey = `${groupid}:${version}`;
        if (this.groupNames === '' || filtering.checkResult(value, filters)) {
          if (results[newkey] === undefined) {
            results[newkey] = {
              name: value.name,
              passed: 0,
              failed: 0,
              stopped: 0,
              waiting: 0,
              linkinfo: {...value.linkinfo, flavor: []}
            };
          }
          const res = results[newkey];
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
      const filters = filtering.makeGroupNamesFilters(this.groupNames);
      for (const value of Object.values(this.incidentResults)) {
        if (filtering.checkResult(value, filters)) results.push(value);
      }
      return results;
    }
  }
};
</script>

<style>
.high-priority {
  background: repeating-linear-gradient(
    45deg,
    transparent,
    transparent 10px,
    var(--bs-warning-bg-subtle) 10px,
    var(--bs-warning-bg-subtle) 20px
  );
}
.high-priority td {
  background-color: initial;
}
.high-priority td:nth-child(1) a {
  font-weight: bold;
}
</style>
