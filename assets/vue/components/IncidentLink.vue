<template>
  <div>
    <router-link
      class="incident-link"
      :to="{name: 'incident', params: {id: incident.number}}"
      :title="highPriority ? 'Incident with priority > 650: Focus on review and consider manual approval' : ''"
    >
      {{ incident.number }}:{{ packageName }}
      <i v-if="highPriority" class="fas fa-triangle-exclamation"></i>
    </router-link>
  </div>
</template>

<script>
export default {
  name: 'IncidentLink',
  props: {incident: {type: Object, required: true}, highPriority: {type: Boolean, default: false}},
  computed: {
    packageName() {
      return this.incident.packages[0];
    }
  }
};
</script>

<style>
a.incident-link {
  text-decoration: none;
}
</style>
