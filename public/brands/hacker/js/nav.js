$(document).ready(function() {
    $(function() {
        $('#nav li').mouseover(function() {
            // inactivate all of the links
            $('#nav li').addClass('inactive');
            // activate the one the user is hovering over
            $(this).removeClass('inactive');
            // what's the index of the one the user is hovering over?
            var idx = $('#nav li').index(this);
            // get the html for details of the selected beer
            var detailsHtml = $('#descriptions div').eq(idx).html();
            // replace the visible details section with selected beer details html, ensure visible
            $('#details').html(detailsHtml).show();
            // @TODO - question: is it better to copy html and replace dom contents or do a css display none/block switch?
        });
    });

    // On page load, weisse beer should be selected
    $('#nav li').addClass('inactive');
    $('#nav li.weisse').removeClass('inactive');
    $('#details').html($('#descriptions div.weisse-deets').html()).show();
});
