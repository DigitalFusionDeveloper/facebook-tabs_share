if(!window.Brand){
  (function(){

    Brand = new Function();

    Brand.rfi_form = function(name, selector){
      var url = '/' + name + '/forms/rfi';
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

    Brand.locator_form = function(name, selector){
      var url = '/' + name + '/forms/locator';
      var target = jQuery(selector);
      jQuery.ajax({
        'url' : url,
        'type' : 'GET',
        'cache' : 'false',

        'success' : function(html){
          target.append(html);
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

    Brand.geo_locate = function(options){
      var url = '//maps.google.com/maps/api/geocode/json';
      var address = options['address'];
      var async = options['async']==false ? false : true;

      options['success'] = options['success'] || function(){};
      options['error'] = options['error'] || function(){};
      options['complete'] = options['complete'] || function(){};


      jQuery.ajax({
        'url'   : url,
        'type'  : 'GET',
        'cache' : false,
        'async' : async,

        'data' : {'sensor' : false, 'address' : address},

        'success'  : options['success'],
        'error'    : options['error'],
        'complete' : options['complete']
      });
    };

    window.Brand = Brand;
  })();
};
