import './sass/app.scss';
import 'bootstrap';
import 'bootstrap/dist/css/bootstrap.css';
import router from './router.js';
import App from './vue/App.vue';
import $ from 'jquery';
import Vue from 'vue';

window.$ = $;

import 'timeago';

const fromNow = function () {
  $('.from-now').each(function () {
    const date = $(this);
    date.text($.timeago(new Date(date.text() * 1000)));
  });
};

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
      Vue.prototype.appConfig = config;

      const vm = new Vue({
        router,
        render: h => h(App),
        components: {App}
      });
      vm.$mount('#app');

      fromNow();
      backToTop();
      $('[data-toggle="tooltip"]').tooltip({trigger: 'hover'});
    });
});
