import './sass/app.scss';
import 'bootstrap';
import router from './router.js';
import App from './vue/App.vue';
import {createApp} from 'vue';
import {createPinia} from 'pinia';
import {useConfigStore} from './stores/config';

const backToTop = function () {
  const mybutton = document.getElementById('back-to-top');

  const scrollFunction = function () {
    if (document.body.scrollTop > 50 || document.documentElement.scrollTop > 50) {
      mybutton.style.display = 'block';
    } else {
      mybutton.style.display = 'none';
    }
  };

  // When the user scrolls down 20px from the top of the document, show the button
  window.onscroll = function () {
    scrollFunction();
  };

  const scrollUp = function () {
    document.body.scrollTop = 0;
    document.documentElement.scrollTop = 0;
  };

  // When the user clicks on the button, scroll to the top of the document
  mybutton.addEventListener('click', scrollUp);
};

const initApp = async () => {
  const app = createApp(App);
  const pinia = createPinia();
  app.use(pinia);

  const configStore = useConfigStore();
  await configStore.fetchConfig();

  router.beforeEach(async (to, from, next) => {
    // Only check if we are already loaded and moving between routes
    if (configStore.isLoaded && from.name) {
      try {
        const config = await fetch('/app-config').then(res => res.json());
        if (config.bootId && config.bootId !== configStore.bootId) {
          console.log('Server restart detected, reloading...');
          window.location.reload();
          return;
        }
      } catch (e) {
        console.error('Failed to check bootId', e);
      }
    }
    next();
  });

  app.use(router).mount('#app');
  backToTop();
};

initApp();
