<template>
  <div class="incident-details-icons d-inline-flex gap-2">
    <i
      class="fas"
      :class="incident.approved ? 'fa-stamp text-success' : 'fa-stamp text-secondary opacity-50'"
      :title="incident.approved ? 'Approved' : 'Not Approved'"
    ></i>
    <i
      class="fas"
      :class="incident.isActive ? 'fa-bolt text-warning' : 'fa-bolt text-secondary opacity-50'"
      :title="incident.isActive ? 'Active' : 'Inactive'"
    ></i>
    <i v-if="incident.embargoed" class="fas fa-lock text-danger" title="Embargoed"></i>
    <i v-else class="fas fa-lock-open text-success opacity-50" title="Not Embargoed"></i>
    <i v-if="incident.inReviewQAM" class="fas fa-magnifying-glass text-info" title="In Review QAM"></i>
    <i v-if="incident.emu" class="fas fa-truck-medical text-danger" title="Emergency Maintenance Update"></i>
    <span v-if="incident.priority" :class="priorityClass" :title="'Priority: ' + incident.priority">
      <i class="fas fa-arrow-up-z-a"></i>
      <small>{{ incident.priority }}</small>
    </span>
    <i v-if="incident.type === 'git'" class="fas fa-code-branch text-primary" title="Type: Git"></i>
    <i v-if="incident.type === 'smelt'" class="fas fa-database text-primary" title="Type: Smelt"></i>
    <i
      v-if="incident.project"
      class="fas fa-project-diagram text-secondary"
      :title="'Project: ' + incident.project"
    ></i>
  </div>
</template>

<script>
export default {
  name: 'IncidentDetailsIcons',
  props: {
    incident: {
      type: Object,
      required: true
    }
  },
  computed: {
    priorityClass() {
      if (this.incident.priority > 650) return 'text-danger fw-bold';
      if (this.incident.priority > 300) return 'text-warning';
      return 'text-secondary';
    }
  }
};
</script>

<style scoped>
.incident-details-icons i {
  cursor: help;
}
.incident-details-icons span {
  display: flex;
  align-items: center;
  gap: 2px;
}
</style>
