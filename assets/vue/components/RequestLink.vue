<template>
  <div class="incident-link">
    <a :href="sourceUrl" target="_blank" class="rr-link">
      <i :class="sourceIcon"></i>
      {{ linkText }}
    </a>
  </div>
</template>

<script>
export default {
  name: 'RequestLink',
  props: {incident: {type: Object, required: true}},
  computed: {
    sourceUrl() {
      if (this.incident.type === 'git' || !this.incident.rr_number) {
        return this.incident.url;
      }
      return `${this.appConfig.obsUrl}/request/show/${this.incident.rr_number}`;
    },
    linkText() {
      if (this.incident.rr_number) {
        return `${this.incident.rr_number}:${this.packageName}`;
      }
      return this.packageName || 'Source';
    },
    sourceIcon() {
      return this.incident.type === 'git' ? 'fas fa-code-branch' : 'fas fa-box-open';
    },
    packageName() {
      return this.incident.packages && this.incident.packages.length > 0 ? this.incident.packages[0] : '';
    }
  }
};
</script>
