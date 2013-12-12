if(!window.Brand){
  (function(){

    Brand = new Function();

    Brand.rfi_form = function(name, selector){
      var url = '/' + name + '/forms/rfi';
      var target = jQuery(selector);
      var tab = Brand.current_tab();

      jQuery.ajax({
        'url' : url,
        'type' : 'GET',
        'cache' : 'false',

        'success' : function(html){
          target.append(html);

          target.find('form').each(function(i, form){
            Brand.ajaxify_form(tab, target, form);
          });
        }
      });

      return(true);
    };

    Brand.locator_form = function(name, selector){
      var url = '/' + name + '/forms/locator';
      var target = jQuery(selector);
      var tab = Brand.current_tab();

      jQuery.ajax({
        'url' : url,
        'type' : 'GET',
        'cache' : 'false',

        'success' : function(html){
          target.append(html);

          target.find('form').each(function(i, form){
            Brand.ajaxify_form(tab, target, form);
          });
        }
      });

      return(true);
    };

    Brand.current_tab = function(){
      var current_tab = ('' + window.location).replace(/[#].*/, '').replace(/[?].*/, '');
      return(current_tab);
    };

    Brand.ajaxify_form = function(tab, target, form){
      form = jQuery(form);

      form.ajaxForm({
        'success' : function(html){
          //form[0].reset();
          form.replaceWith(html);

          target.find('form').each(function(i, form){
            Brand.ajaxify_form(tab, target, form);
          });
        }
      });

      var input = jQuery('<input name="tab" type="hidden"/>');
      input.val(tab);
      form.append(input);
      form.find('a.tab').attr('href', tab);
    };

    Brand.geo_locate = function(options){
      var address = options['address'];
      var success = options['success'] || function(){};

      window.load_google_maps(function(){
        var geocoder = new google.maps.Geocoder()
        geocoder.geocode({'address':address}, success);
      });
    };

    Brand.initialize_google_maps = function(){

      if(!window.load_google_maps){
        window.load_google_maps = function(cb){
          if(cb){
            window.google_maps_callbacks.push(cb);
          }

          try{
            google.maps.Geocoder
            window.google_maps_loaded();
          } catch(e) {
            var script = document.createElement('script');
            script.type = 'text/javascript';
            script.src = 'https://maps.googleapis.com/maps/api/js?v=3.exp&sensor=false&' +
                'callback=google_maps_loaded';
            document.body.appendChild(script);
          }
        };

        window.load_google_maps();
      };

      if(!window.google_maps_loaded){
        window.google_maps_loaded = function(){
          for(var i = 0; i < google_maps_callbacks.length; i++){
            var cb = google_maps_callbacks[i];
            try{ cb() } catch(e) {};
          }
        };
      };

      if(!window.google_maps_callbacks){
        window.google_maps_callbacks = []; 
      };

    };

    jQuery(function(){ Brand.initialize_google_maps() });


    window.Brand = Brand;
  })();
};
