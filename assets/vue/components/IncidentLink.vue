<template>
  <div>
    <router-link class="incident-link" :to="{name: 'incident', params: {id: incident.number}}">
      {{ incident.number }}:{{ packageName }}
    </router-link>
  </div>
</template>

<script>
export default {
  name: 'IncidentLink',
  props: {incident: {type: Object, required: true}},
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
