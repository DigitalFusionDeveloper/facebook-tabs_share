if(!window.Beer){
  (function(){

    Beer = new Function();

    Beer.contact_form = function(name, selector){
      var url = '/' + name + '/forms' + '/rfi';
      var target = jQuery(selector);

      jQuery.ajax({
        'url' : url,
        'type' : 'GET',
        'cache' : 'false',

        'success' : function(html){
          target.append(html);

          target.find('form').each(function(i, form){
            Beer.ajaxify_form(target, form);
          });
        }
      });

      return(true);
    };

    Beer.ajaxify_form = function(target, form){
      form = jQuery(form);

      form.ajaxForm({
        'success' : function(html){
          //form[0].reset();
          form.replaceWith(html);

          target.find('form').each(function(i, form){
            Beer.ajaxify_form(target, form);
          });
        }
      });
    };

    window.Beer = Beer;

  })();
};
