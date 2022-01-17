import PageActive from './vue/components/PageActive.vue';
import PageBlocked from './vue/components/PageBlocked.vue';
import PageIncident from './vue/components/PageIncident.vue';
import PageRepos from './vue/components/PageRepos.vue';
import {Modal} from 'bootstrap';
import {createRouter, createWebHistory} from 'vue-router';

const routes = [
  {
    path: '/',
    name: 'home',
    component: PageActive,
    meta: {title: 'Active Incidents'}
  },
  {
    path: '/blocked',
    name: 'blocked',
    component: PageBlocked,
    meta: {title: 'Blocked by Tests'}
  },
  {
    path: '/repos',
    name: 'repos',
    component: PageRepos,
    meta: {title: 'Test Repos'}
  },
  {
    path: '/incident/:id',
    name: 'incident',
    component: PageIncident,
    meta: {title: 'Details for Incident'}
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

// Remove the modal backdrop if one was left behind
router.beforeEach((to, from, next) => {
  const el = document.getElementById('update-incidents');
  if (el !== null) Modal.getInstance(el).dispose();
  next();
});

export default router;
