function backToTop () {
  $(document).ready(function () {
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
  });
}

function fromNow() {
  $('.from-now').each(function () {
    var date = $(this);
    date.text(jQuery.timeago(new Date(date.text() * 1000)));
  });
 }

$(function () {
  $('[data-toggle="tooltip"]').tooltip({trigger : 'hover'})
})
