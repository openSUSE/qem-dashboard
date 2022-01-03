<template>
  <div class="incident-link">
    <a :href="obsLink" target="_blank" class="rr-link">{{ incident.rr_number }}:{{ packageName }}</a>
  </div>
</template>

<script>
export default {
  name: 'RequestLink',
  props: {incident: {type: Object, required: true}},
  computed: {
    obsLink() {
      return `${this.appConfig.obsUrl}/request/show/${this.incident.rr_number}`;
    },
    packageName() {
      return this.incident.packages[0];
    }
  }
};
</script>
