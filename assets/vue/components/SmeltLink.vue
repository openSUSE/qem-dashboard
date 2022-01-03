<template>
  <div class="incident-link">
    <a :href="smeltLink" target="_blank"> {{ incident.number }}:{{ packageName }}</a>
    <a v-if="incident.rr_number > 0" :href="obsLink" target="_blank" class="rr-link">
      <i class="fas fa-box" />
    </a>
  </div>
</template>

<script>
export default {
  name: 'SmeltLink',
  props: {incident: {type: Object, required: true}},
  computed: {
    obsLink() {
      return `${this.appConfig.obsUrl}/request/show/${this.incident.rr_number}`;
    },
    smeltLink() {
      return `${this.appConfig.smeltUrl}/incident/${this.incident.number}`;
    },
    packageName() {
      return this.incident.packages[0];
    }
  }
};
</script>

<style>
.rr-link {
  color: #ddd;
}
.rr-link:hover {
  text-decoration: none;
}
</style>
