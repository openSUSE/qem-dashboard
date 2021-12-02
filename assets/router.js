import ActiveComponent from './vue/Active.vue';
import BlockedComponent from './vue/Blocked.vue';
import IncidentComponent from './vue/Incident.vue';
import ReposComponent from './vue/Repos.vue';
import jQuery from 'jquery';
import Vue from 'vue';
import Router from 'vue-router';

Vue.use(Router);

const router = new Router({
  mode: 'history',
  routes: [
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
  ]
});

router.beforeEach((to, from, next) => {
  if (from.name === 'repos') {
    // Make sure not to leave black screens
    jQuery('#update-incidents').modal('hide');
  }
  next();
});

export default router;
