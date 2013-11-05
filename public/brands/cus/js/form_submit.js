$(document).ready(function() {
  setTimeout(function(){
    $('form').submit(function(){
      $('#rfi_intro').hide();
    });
  }, 1000);

  $('#rfi_intro').show();
});