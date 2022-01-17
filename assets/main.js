import './sass/app.scss';
import 'bootstrap';
import 'bootstrap/dist/css/bootstrap.css';
import router from './router.js';
import App from './vue/App.vue';
import axios from 'axios';
import {createApp} from 'vue';

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

window.addEventListener('load', () => {
  axios('/app-config').then(response => {
    const config = response.data;
    const app = createApp(App);
    app.config.globalProperties.appConfig = config;
    app.use(router).mount('#app');

    backToTop();
  });
});
