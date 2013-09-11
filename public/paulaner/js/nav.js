$(document).ready(function() {
    $(function() {
	$('#paulaner_nav img').mouseover(
            function() {
		var idx = $('#paulaner_nav img').index(this);              
                $('#details').html($('#descriptions div').eq(idx).html()).show();
		$img = $('#images img').eq(idx);
		$('#main_image').attr('src',$img.attr('src'));
            }
	);
    });
});
