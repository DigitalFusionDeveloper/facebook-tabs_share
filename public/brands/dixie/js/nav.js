$(document).ready(function() {
    $(function() {
    	$('#nav li').mouseover(
                function() {
        $('#nav li').addClass('inactive');
        $(this).removeClass('inactive');
    		var idx = $('#nav li').index(this);              
        $('#details').html($('#descriptions div').eq(idx).html()).show();
    		$img = $('#images img').eq(idx);
    		$('#main_image').attr('src',$img.attr('src'));
                }
    	);
    });
    $('#nav li.jazz').addClass('inactive');
    $('#nav li.voodoo').addClass('inactive');
    $('#details').html($('#descriptions div.original').html()).show();
});