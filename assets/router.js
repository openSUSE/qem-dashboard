import {createRouter, createWebHistory} from 'vue-router';

const routes = [
  {
    path: '/',
    name: 'home',
    component: () => import('./vue/components/PageActive.vue'),
    meta: {title: 'Active Incidents'}
  },
  {
    path: '/blocked',
    name: 'blocked',
    component: () => import('./vue/components/PageBlocked.vue'),
    meta: {title: 'Blocked by Tests'}
  },
  {
    path: '/repos',
    name: 'repos',
    component: () => import('./vue/components/PageRepos.vue'),
    meta: {title: 'Test Repos'}
  },
  {
    path: '/incident/:id',
    name: 'incident',
    component: () => import('./vue/components/PageIncident.vue'),
    meta: {title: 'Details for Incident'}
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

export default router;
