import './sass/app.scss';
import 'bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
import $ from 'jquery';

window.jQuery = $;
window.$ = $;

import 'timeago';

function fromNow() {
  $('.from-now').each(function () {
    var date = $(this);
    date.text(jQuery.timeago(new Date(date.text() * 1000)));
  });
}

function backToTop() {
  $(window).scroll(function () {
    if ($(this).scrollTop() > 50) {
      $('#back-to-top').fadeIn();
    } else {
      $('#back-to-top').fadeOut();
    }
  });
  $('#back-to-top').click(function () {
    $('body, html').animate({scrollTop: 0}, 800);
    return false;
  });
}

window.addEventListener('load', function () {
  fromNow();
  backToTop();
  $('[data-toggle="tooltip"]').tooltip({trigger: 'hover'});
});
