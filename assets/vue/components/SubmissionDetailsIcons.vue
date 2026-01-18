<script setup>
import {computed} from 'vue';

const props = defineProps({
  incident: {
    type: Object,
    required: true
  }
});

const priorityClass = computed(() => {
  if (props.incident.priority > 650) return 'text-danger fw-bold';
  if (props.incident.priority > 300) return 'text-warning';
  return 'text-secondary';
});

const priorityBadgeClass = computed(() => {
  if (props.incident.priority > 650) return 'bg-danger';
  if (props.incident.priority > 300) return 'bg-warning text-dark';
  return 'bg-secondary';
});
</script>

<template>
  <div class="submission-details-icons d-inline-flex gap-2">
    <i
      class="fas"
      :class="incident.approved ? 'fa-stamp text-success' : 'fa-stamp text-secondary opacity-50'"
      :title="incident.approved ? 'Approved' : 'Not Approved'"
      :aria-label="incident.approved ? 'Approved' : 'Not Approved'"
      role="img"
    ></i>
    <i
      class="fas"
      :class="incident.isActive ? 'fa-bolt text-warning' : 'fa-bolt text-secondary opacity-50'"
      :title="incident.isActive ? 'Active' : 'Inactive'"
      :aria-label="incident.isActive ? 'Active' : 'Inactive'"
      role="img"
    ></i>
    <i
      v-if="incident.embargoed"
      class="fas fa-lock text-danger"
      title="Embargoed"
      aria-label="Embargoed"
      role="img"
    ></i>
    <i
      v-else
      class="fas fa-lock-open text-success opacity-50"
      title="Not Embargoed"
      aria-label="Not Embargoed"
      role="img"
    ></i>
    <i
      v-if="incident.inReviewQAM"
      class="fas fa-magnifying-glass text-info"
      title="In Review QAM"
      aria-label="In Review QAM"
      role="img"
    ></i>
    <i
      v-if="incident.emu"
      class="fas fa-truck-medical text-danger"
      title="Emergency Maintenance Update"
      aria-label="Emergency Maintenance Update"
      role="img"
    ></i>
    <span
      v-if="incident.priority"
      :class="priorityClass"
      :title="'Priority: ' + incident.priority"
      :aria-label="'Priority: ' + incident.priority"
      role="img"
    >
      <i class="fas fa-arrow-up-z-a" aria-hidden="true"></i>
      <span class="badge" :class="priorityBadgeClass" aria-hidden="true">{{ incident.priority }}</span>
    </span>
    <span
      v-if="incident.type"
      class="text-primary"
      :title="'Type: ' + incident.type"
      :aria-label="'Type: ' + incident.type"
      role="img"
    >
      <i :class="incident.type === 'git' ? 'fas fa-code-branch' : 'fas fa-database'" aria-hidden="true"></i>
      <span class="badge bg-info ms-1" aria-hidden="true">{{ incident.type }}</span>
    </span>
    <i
      v-if="incident.project"
      class="fas fa-project-diagram text-secondary"
      :title="'Project: ' + incident.project"
      :aria-label="'Project: ' + incident.project"
      role="img"
    ></i>
  </div>
</template>

<script>
export default {
  name: 'SubmissionDetailsIcons'
};
</script>

<style scoped>
.submission-details-icons i {
  cursor: help;
}
.submission-details-icons span {
  display: flex;
  align-items: center;
}
</style>
