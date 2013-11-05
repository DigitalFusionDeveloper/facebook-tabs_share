$(document).ready(function() {
  setTimeout(function(){
    $('form').submit(function(){
      $('#rfi_intro').hide();
      $('#rfi_disclaimer').hide();
    });
  }, 1000);

  $('#rfi_intro').show();
  $('#rfi_disclaimer').show();
});