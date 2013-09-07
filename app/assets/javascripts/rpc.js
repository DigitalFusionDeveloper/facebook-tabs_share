if(!window.RPC){

  RPC = function(url){
    this.url = url || '/rpc';
  };

  RPC.prototype.call = function(){
    var rpc = this;
    var args = Array.prototype.slice.call(arguments);
    var ajax;
    var method;

    if(args.length == 1 && typeof(args[0]) == 'object'){
      ajax = args.shift();
    } else {
      ajax = {};

      for(var i = 0; i < args.length; i++){
        var arg = args[i];

        switch (typeof(arg)) {
          case 'object':
            ajax['data'] = ajax['data'] || arg;
            break;
          case 'function':
            ajax['success'] = ajax['success'] || arg;
            break;
          case 'string':
            method = method || arg;
            break;
        };
      }
    };

    ajax['url'] = ajax['url'] || rpc['url'] || (window.location.pathname + '/rpc'); 

    method = method || ajax['method'];
    delete ajax['method'];

    ajax['data'] = ajax['data'] || {};
    ajax['data']['method'] = method;

    ajax['async']          = true;
    ajax['type']           = 'GET';
    ajax['dataType']       = 'json';
    ajax['cache']          = false;
    ajax['contentType']    = 'application/json; charset = utf-8';

    var result = ajax;

    if(!ajax['success']){
      ajax['async'] = false;
      ajax['success'] = function(response){ result = response };
    };

    jQuery.ajax(ajax);

    return(result);
  };

};


