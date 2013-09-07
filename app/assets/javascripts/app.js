//
//
  if(!window.App){
    window.App = {};
  }

  if(!window.jq && window.jQuery){
    var jq = jQuery;
    App.jq = jQuery;
  }

  App.log = function(){
    try {
      if(window.console){
        if(window.console.log){
          window.console.log.apply(window.console, arguments);
        }
      }
    } catch(e) {}
  };

// setup script loader
//
  if(!App.require_javascript){
    App.require_javascript = function(id, src, callback){
      var head = document.getElementsByTagName('head')[0];
      var script = document.createElement('script');
      script.id = id;
      script.src = src;
      script.type = 'text/javascript';

      // Attach handlers for all browsers
      //
      var done = false;
      script.onload = script.onreadystatechange = function() {
        if ( !done && (!this.readyState || this.readyState === "loaded" || this.readyState === "complete") ) {
          done = true;
          callback && callback();
          // Handle memory leak in IE
          script.onload = script.onreadystatechange = null;
          if ( head && script.parentNode ) {
            head.removeChild( script );
          }
        }
      };

    // Use insertBefore instead of appendChild  to circumvent an IE6 bug.
    // This arises when a base node is used (#2709 and #4378).
    //
      head.insertBefore(script, head.firstChild);
    };
  }

// run code when a feature becomes available
//
//   run_when_available('window.feature', function(){ ... });
//
  if(!App.run_when_available){
    App.run_when_available = function(){
    // parse args + options looking for two functions and a timeout
    //
      var args = Array.prototype.slice.apply(arguments);

      var options = null;
      var test = null;
      var callback = null;
      var milliseconds = null;

      for(var i = 0; i < args.length; i++){
        var value = args[i];

        var type = typeof(value);

        if(type === 'object'){
          options = options || value;
          continue;
        }

        if(type === 'function' || type === 'string'){
          if(test){
            callback = callback || value;
          } else {
            test = test || value;
          }
          continue;
        }

        milliseconds = value;
      }

      options = options || {};
      callback = callback || options.callback || function(){ return false; };
      test = test || options.test || function(){ return true; };
      milliseconds = milliseconds || options.milliseconds || 42;

      if(typeof(test)==='string'){
        var code = test;
        test = function(){ return(eval(code)); };
      }

      if(typeof(callback)==='string'){
        var code = callback;
        callback = function(){ return(eval(callback)); };
      }

      if(test()){
        callback();
      } else {
        var id = null;
        id = setInterval( function(){ if(test()){ clearInterval(id); callback(); } }, milliseconds);
      }
    };
  }
