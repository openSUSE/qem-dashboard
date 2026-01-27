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
      <span class="badge" :class="priorityBadgeClass">{{ incident.priority }}</span>
    </span>
    <span v-if="incident.type" class="text-primary" :title="'Type: ' + incident.type">
      <i :class="incident.type === 'git' ? 'fas fa-code-branch' : 'fas fa-database'"></i>
      <span class="badge bg-info ms-1">{{ incident.type }}</span>
    </span>
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
    },
    priorityBadgeClass() {
      if (this.incident.priority > 650) return 'bg-danger';
      if (this.incident.priority > 300) return 'bg-warning text-dark';
      return 'bg-secondary';
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
}
</style>
