$(document).ready(function() {
    $('#nav li').addClass('inactive');
    $('#nav').hide();
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
        $('#landing-nav li').click(
            function() {
                $('#landing_wrap').hide();
                $('#nav').show();
                var lin = $(this).attr('class');
                var mnli = '#nav li.nav-' + lin;
                var ddiv = '#descriptions div.desc-' + lin;
                $(mnli).removeClass('inactive');
                $('#details').html($(ddiv).html()).show();
            }
        );
    });
});
