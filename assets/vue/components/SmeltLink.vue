<template>
  <div class="incident-link">
    <a :href="smeltLink" target="_blank">{{ incident.number }}:{{ packageName }}</a>
  </div>
</template>

<script>
export default {
  name: 'SmeltLink',
  props: {incident: {type: Object, required: true}},
  computed: {
    smeltLink() {
      return `${this.appConfig.smeltUrl}/incident/${this.incident.number}`;
    },
    packageName() {
      return this.incident.packages[0];
    }
  }
};
</script>
