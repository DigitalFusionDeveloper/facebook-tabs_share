//= require 'jquery'
//= require 'jquery_ujs'
//= require 'jquery.json-2.3.min.js'
//= require 'jquery.validate'
//= require 'handlebars-1.0.0.beta.6.js'
//= require 'underscore-min.js'
//= require 'sprintf'
//= require 'dao'
//
//= require 'bootstrap.js'
//= require 'template.js'
//= require 'fileuploader.js'
//= require 'jquery.colorbox'
//= require 'sugar-edge-full.development.js'
//= require 'jquery.cookie.js'
//= require 'categorizr.js'
//
//= require 'jquery.form.js'
//= require 's3uploader.js'
//= require 'rpc.js'
//
//= require 'brand.js'
//
//= require 'app'


jq(function(){

// underscore template settings
//
   _.templateSettings = { start : '{{', end : '}}', interpolate : /{{(.+?)}}/g };

// template shortcuts
//
  App.template = window.Template;
  App.templates = window.Template.cache;

// device detection
//
  try{
    App.device = categorizr() || 'desktop';
    App.mobile = (App.device != 'desktop') ? true : false;
  } catch(e){};

// flash message support
//
  if(!App.mobile){

    App.flash = function(msg, options){
      options = options || {};
      var flash = jq('.flash');
      flash.show();

      var template = App.templates['flash-list-item'];
      var data = {'message' : msg};
      var message = jq(template.render(data));

      var dismiss = message.find('.dismiss');
      dismiss.click(function(){ message.remove(); });

      var close = message.find('.close');
      close.click(function(){ message.remove(); });

      message.addClass(
        options['css.class'] ||
        options['class'] ||
        options['kind'] ||
        'notice'
      );
      flash.append(message);
      return(message);
    };

  } else {

    App.flash = function(msg, options){
      options = options || {};
      var label = options['css.class'] || options['class'] || options['kind'] || 'info'
      var message = label + ': ' + msg;
      alert(msg);
      return(message);
    };

  }

  App.message = App.flash;


// new skool <blink>
//
  App.blink = function(){
    var element = arguments[0];
    var options = arguments[1] || {};
    var n = options.n || App.blink.n;
    var speed = options.speed || App.blink.speed;
    element = jq(element);
    element.fadeout = function(){ element.fadeTo(speed, 0.50, element.fadein); };
    element.fadein = function(){ element.fadeTo(speed, 1.00); --n > 0 && element.fadeout(); };
    var id = setTimeout( element.fadeout, speed );
    return(id);
  };
  App.blink.n = 2;
  App.blink.speed = 2000;

// initializers
//
  App.initialize = function(){
    var scope = arguments[0];
    scope = scope ? jq(scope) : jq('html');

    //App.initialize_type_classes(scope);
    //App.initialize_submits(scope);
    App.initialize_focus(scope);
  };

// apply a type class to each input to get around shitty IE css selectors.
// fuck you IE.
//
  App.initialize_type_classes = function(){
    var scope = arguments[0];
    scope = scope ? jq(scope) : jq('html');
    scope.find('input').each(function(){
      var input = jq(this);
      var type = input.attr('type');
      input.addClass(type);
    });
  };

  App.initialize_maps = function(){
    var scope = arguments[0];
    scope = scope ? jq(scope) : jq('html');

    scope.find('.gmap').each(function(){
      var element = jq(this);

      if(App.mobile && (element.data('mobile-expand') == true)){
        var width = element.parent().width();
        var height = width;
        element.css({'width' : width, 'height' : height});
      };

      var lat = element.data('lat');
      var lng = element.data('lng');
      var zoom = element.data('zoom') || 9;

      var lat_lng = new google.maps.LatLng(lat, lng);
      var map;

      var options = {
        zoom: zoom,
        center: lat_lng,
        mapTypeId: google.maps.MapTypeId.ROADMAP,
        draggable: false,
        disableDefaultUI: true
      };
      map = new google.maps.Map(this, options);

    //
    // http://code.google.com/apis/maps/documentation/javascript/styling.html#styling_the_default_map
    // http://gmaps-samples-v3.googlecode.com/svn/trunk/styledmaps/wizard/index.html
    //
      var style = [ { stylers: [ { saturation: -100 } ] },{ } ];

      map.setOptions({styles: style});

      var marker = new google.maps.Marker({
        'position': lat_lng
      });

      marker.setMap(map);
    });
  };

  App.initialize_focus = function(){
    var scope = arguments[0];
    scope = scope ? jq(scope) : jq('html');
    //scope.find('.focus:first').focus().click();
    //scope.find('#focus:first').focus().click();
    scope.find('[autofocus]').focus().click();
  };

  App.initialize_submits = function(){
    var scope = arguments[0];
    scope = scope ? jq(scope) : jq('html');
    //scope.find('.date').date_input();

    scope.find('input[type=submit].once,button[type=submit].once').click(function(){
      if(jQuery.data(this, 'clicked')){
        return(confirm('Are you sure you want to submit this form again?'));
      }
      else{
        jQuery.data(this, 'clicked', true);
        return true;
      }
      return true;
    });
  };

//
//
  App.initialize();

// app ajax shortcuts
//
  App.ajax = function(){
    var args = Array.prototype.slice.call(arguments);
    var options = App.ajax.parse.apply(App, args);

    var ajax = {};
    ajax.type = options.type || App.ajax.defaults.type;
    ajax.url = options.url || App.ajax.defaults.url;
    ajax.dataType = 'json';
    ajax.cache = false;

    if(ajax.type.match(/^(post|put|delete)$/i)){
      ajax.data = jQuery.toJSON(options.data || {});
    } else {
      ajax.data = (options.data || {});
    }

    ajax.contentType = (options.contentType || 'application/json; charset=utf-8');

    if(options.success){
      ajax.success = options.success;
    }

    var result = ajax;

    if(typeof(ajax.async) === 'undefined' && typeof(ajax.success) === 'undefined'){
      ajax.async = false;
      result = undefined;

      ajax.success = function(){
        var args = Array.prototype.slice.call(arguments);
        result = args[0];
        App.ajax.results.push(result);
        App.ajax.result = result;
      };
    }

    jQuery.ajax(ajax);

    return(result);
  };

  App.ajax.parse = function(){
    var args = Array.prototype.slice.call(arguments);
    var options = {};

    if(args.length === 1){
      var arg = args[0];

      if(typeof(arg)==='string'){
        options.url = arg;
      } else {
        options = arg;
      }
    }

    if(args.length > 1){
      options.url = args[0];

      if(typeof(args[1])==='function'){
        options.success = args[1];
        options.data = args[2];
      } else {
        options.data = args[1];
        options.success = args[2];
      }
    }

    return options;
  };

  App.ajax.modes = ["options", "get", "head", "post", "put", "delete", "trace", "connect"];
  App.ajax.result = null;
  App.ajax.results = [];
  App.ajax.defaults = {};
  App.ajax.defaults.type = 'get';
  App.ajax.defaults.url = '/';

// meta-program App.ajax.get(...), App.ajax.post(...)
//
  for(var i = 0; i < App.ajax.modes.length; i++){
    (function(){
      var mode = App.ajax.modes[i];

      App.ajax[mode] = function(){
        var args = Array.prototype.slice.call(arguments);
        var options = App.ajax.parse.apply(App, args);
        options.type = mode.toUpperCase();
        return App.ajax(options);
      };
    })();
  }

// ref: http://dense13.com/blog/2009/05/03/converting-string-to-slug-javascript/
//
  App.slug_for = function(str){
    str = str.replace(/^\s+|\s+$/g, ''); // trim
    str = str.toLowerCase();
    
  // remove accents, swap n for n, etc
    var from = "aaaaeeeeiiiioooouuuunc/_,:;";
    var to   = "aaaaeeeeiiiioooouuuunc------";
    for (var i=0, l=from.length ; i<l ; i++) {
      str = str.replace(new RegExp(from.charAt(i), 'g'), to.charAt(i));
    }

    str = str.replace(/[^a-z0-9]/g, '-') // remove invalid chars
      .replace(/-+/g, '-'); // collapse dashes

    return str;
  };
});
