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
    path: '/submission/:id',
    name: 'submission',
    component: () => import('./vue/components/PageSubmission.vue'),
    meta: {title: 'Details for Submission'}
  },
  {
    path: '/incident/:id',
    redirect: to => {
      return {name: 'submission', params: {id: to.params.id}};
    }
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

export default router;
