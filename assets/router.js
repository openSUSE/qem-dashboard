import ActiveComponent from './vue/components/Active.vue';
import BlockedComponent from './vue/components/Blocked.vue';
import IncidentComponent from './vue/components/Incident.vue';
import ReposComponent from './vue/components/Repos.vue';
import jQuery from 'jquery';
import {createRouter, createWebHistory} from 'vue-router';

const routes = [
  {
    path: '/',
    name: 'home',
    component: ActiveComponent,
    meta: {title: 'Active Incidents'}
  },
  {
    path: '/blocked',
    name: 'blocked',
    component: BlockedComponent,
    meta: {title: 'Blocked by Tests'}
  },
  {
    path: '/repos',
    name: 'repos',
    component: ReposComponent,
    meta: {title: 'Test Repos'}
  },
  {
    path: '/incident/:id',
    name: 'incident',
    component: IncidentComponent,
    meta: {title: 'Details for Incident'}
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

router.beforeEach((to, from, next) => {
  if (from.name === 'repos') {
    // Make sure not to leave black screens
    jQuery('#update-incidents').modal('hide');
  }
  next();
});

export default router;
