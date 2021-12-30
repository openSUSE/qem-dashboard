import './sass/app.scss';
import 'bootstrap';
import 'bootstrap/dist/css/bootstrap.css';
import router from './router.js';
import App from './vue/App.vue';
import $ from 'jquery';
import {createApp} from 'vue';

window.$ = $;

const backToTop = function () {
  $(window).scroll(function () {
    if ($(this).scrollTop() > 50) {
      $('#back-to-top').fadeIn();
    } else {
      $('#back-to-top').fadeOut();
    }
  });
  $('#back-to-top').click(() => {
    $('body, html').animate({scrollTop: 0}, 800);
    return false;
  });
};

window.addEventListener('load', () => {
  const url = new URL(window.location.href);
  url.pathname = '/app-config';

  fetch(url)
    .then(res => res.json())
    .then(config => {
      const app = createApp(App);
      app.config.globalProperties.appConfig = config;
      app.use(router).mount('#app');

      backToTop();
      $('[data-toggle="tooltip"]').tooltip({trigger: 'hover'});
    });
});
