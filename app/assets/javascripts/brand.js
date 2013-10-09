if(!window.Brand){
  (function(){

    Brand = new Function();

    Brand.contact_form = function(name, type, selector){
      var url = '/' + name + '/forms/rfi?rfi[rfi_type]=' + type;
      var target = jQuery(selector);

      jQuery.ajax({
        'url' : url,
        'type' : 'GET',
        'cache' : 'false',

        'success' : function(html){
          target.append(html);

          target.find('form').each(function(i, form){
            Brand.ajaxify_form(target, form);
          });
        }
      });

      return(true);
    };

    Brand.ajaxify_form = function(target, form){
      form = jQuery(form);

      form.ajaxForm({
        'success' : function(html){
          //form[0].reset();
          form.replaceWith(html);

          target.find('form').each(function(i, form){
            Brand.ajaxify_form(target, form);
          });
        }
      });
    };

    window.Brand = Brand;
  })();
};
