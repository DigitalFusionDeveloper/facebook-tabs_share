if(!window['s3Uploader']){

//
  var s3Uploader = new Function();

//
  s3Uploader.urls = [];

//
  s3Uploader.ify = function(options){
    options = options || {};

    var scope = options.scope || 'body';
    var selector = options.selector || 'input[type=file].s3uploader';

    var results = [];

    $(scope).find(selector).each(function(){
      results.push(s3Uploader.initialize(this, options));
    });

    return(results);
  };

//
  s3Uploader.initialize = function(input, options){
    input = $(input);
    options = options || {};

    s3uploader = input.data('s3uploader');

    if(!s3uploader){
      s3uploader = new s3Uploader();
      s3uploader.initialize(input, options);
      input.data('s3uploader', s3uploader);
    };

    return s3uploader;
  };

//
  s3Uploader.prototype.initialize = function(input, options){
    var s3uploader = this;
    
    s3uploader.options = options || {};
    s3uploader._uploading = {};
    s3uploader.fields = [];
    s3uploader.ajax = true;

    if(options['ajax'] == false){
      s3uploader.ajax = false;
    };

    s3uploader.set_input(input);

    s3uploader.set_name(input.attr('name') || 's3uploads');

    s3uploader.add_inputs();
    
    s3uploader.configure_form();

    window.s3uploader = s3uploader;

    return(s3uploader);
  };

//
  s3Uploader.prototype.uploading = function(input){
    var s3uploader = this;

    var keys = [];

    for(var k in s3uploader._uploading){ keys.push(k) };

    return(keys);
  };

//
  s3Uploader.prototype.set_input = function(input){
    var s3uploader = this;

    input = $(input);

    input.addClass('s3');

    s3uploader.input = input;

    input.data('s3uploader', s3uploader);

    input.change(function(){ s3uploader.submit() });
  };

//
  s3Uploader.prototype.set_name = function(name){
    var s3uploader = this;

    s3uploader.name = name.slice(-2) == '[]' ? name : (name + '[]');

    return(s3uploader.name);
  };

//
  s3Uploader.prototype.add_inputs = function(){
    var s3uploader = this;

    s3uploader.inputs = $('<div class="s3uploader-inputs" style="display:none;"></div>');
    s3uploader.input.after(s3uploader.inputs);

    return(s3uploader);
  };

//
  s3Uploader.prototype.add_input = function(){
    var s3uploader = this;
    var args = Array.prototype.slice.apply(arguments);

    var name = args.shift();
    var value = args.shift();
    var input = $('<input type="hidden">').attr('name', name).val(value);

    s3uploader.inputs.prepend(input);

    return(input);
  };

//
  s3Uploader.prototype.configure_form = function(){
    var s3uploader = this;

    var form = s3uploader.input.closest('form');

    if(form){
      form.submit(function(){
        if(s3uploader.uploading().length > 0){
          return(confirm('kill the current upload(s)?'))
        } else {
          s3uploader.input.prop('disabled', true);
          return(true);
        };
      });
    }

    s3uploader.form = form;

    return(form);
  };

//
  s3Uploader.prototype.submit = function(callback){
    var s3uploader = this;

    var submitter = s3uploader.build_submitter_for(callback);

    s3uploader.submitter = submitter;

    submitter.submit();

    return(submitter);
  };

//
  s3Uploader.prototype.build_submitter_for = function(callback){
    var s3uploader   = this;
    var input        = s3uploader.input;

    var filename     = s3Uploader.basename(input.val());
    var form         = s3uploader.form;

    var name         = input.attr('name');
    var id           = 'file-' + s3Uploader.uuid();

    var action       = form.attr('action');
    var enctype      = form.attr('enctype');
    var method       = form.attr('method');

    var submitter    = {};
    submitter.submit = function(){};

    if(!form){ return(submitter) };

    var setup = function(){};
    var teardown = function(){};
    var configure_non_ajax_post = function(){};


    submitter.submit = function(){
      //
        var inputs = {};
        var params = {
          'filename' : filename,
          'inputs'   : inputs 
        };
        s3Uploader.merge_data_attributes(input, params);

      //
        $.ajax({
          'type'     : 'GET',
          'url'      : '/s3',
          'data'     : params,
          'dataType' : 'json',
          'async'    : false,
          'cache'    : false,


          'success'  : function(data) {
            //$.fn.ajaxSubmit.debug=true;
            data['s3uploader'] = s3uploader;
            data['input'] = input;

          //
            var setup = function(){
              form.attr('enctype', 'multipart/form-data');
              form.attr('method', 'post');
              form.attr('action', data.action);

              input.attr('name', id);

              s3uploader._uploading[filename] = data.url;
            };

          //
            var teardown = function(){
              enctype ? form.attr('enctype', enctype) : form.removeAttr('enctype');
              method ? form.attr('method', method) : form.removeAttr('method');
              action ? form.attr('action', action) : form.removeAttr('action');

              input.attr('name', name);

              delete(s3uploader._uploading[filename]);
            };

          //
            var configure_non_ajax_post = function(callback){
              input.attr('name', name);
              s3uploader._uploading = {};

              var inputs = {};
              var fields = form.formToArray();

              for(var i = 0; i < fields.length; i++){
                if(fields[i].type != 'file'){ inputs[fields[i].name] = fields[i].value };
              };

              params['inputs'] = inputs;
              params['success_action_status'] = '303';
              params['success_action_redirect'] = action || window.location.href;

              s3uploader.non_ajax_post = function(data){
                form.css({'opacity' : '0.50'});

                var s3_inputs = s3uploader.add_s3_inputs(form, data.inputs);

                input.attr('name', 'file');
                input.addClass('s3');

                var last = fields[fields.length - 1];

                if(last && last.name != 'file'){
                  input.detach();
                  form.append(input);
                };
              }

              $.ajax({
                'type'     : 'GET',
                'url'      : '/s3',
                'data'     : params,
                'dataType' : 'json',
                'async'    : false,
                'cache'    : false,

                'success'  : function(data){
                  form.submit(function(){
                    s3uploader.non_ajax_post(data);
                    return(true);
                  });
                  callback && callback(data);
                }
              });
            };

          //
            setup();

          //
            if(!s3uploader.ajax){
              configure_non_ajax_post();
              return(true);
            };

          //
            form.ajaxSubmit({
              'complete' :
                teardown,

              'beforeSubmit' :
                function(){
                  var args = Array.prototype.slice.apply(arguments);
                  args.push(s3uploader);

                  var field, file, fields = args[0];

                  while((field = fields.shift())){ if(!file && field.name == id){ file = field } };

                  input.attr('name', name);

                  if(!file){ return(false) };

                  for(var name in data.inputs){
                    var value = data.inputs[name];
                    fields.push({'name' : name, 'value' : value, 'type' : 'text'});
                  };

                  file.name = 'file';
                  fields.push(file);

                  s3uploader.fields = fields;

                  s3Uploader.callbacks['ajax.beforeSubmit'].apply(input, args);
                  s3Uploader.callbacks['before'](data);

                  return(true);
                },

              'uploadProgress' :
                function(){
                  var args = Array.prototype.slice.apply(arguments);
                  args.push(s3uploader);

                  var event = args[0];
                  var position = args[1];
                  var total = args[2];
                  var percent = args[3];

                  data['position'] = position;
                  data['total'] = total;
                  data['percent'] = percent;

                  s3Uploader.callbacks['ajax.uploadProgress'].apply(input, args);
                  s3Uploader.callbacks['progress'](data);

                  return(true);
                },

              'success' :
                function(){
                  var args = Array.prototype.slice.apply(arguments);
                  args.push(s3uploader);

                  delete(s3uploader._uploading[filename]);

                  s3uploader.add_input(s3uploader.name, data.url);
                  s3Uploader.urls.push(data.url);

                  s3Uploader.callbacks['ajax.success'].apply(input, args);
                  s3Uploader.callbacks['success'](data);

                  return(true);
                },
              
              'error' : function(){
                //if(!$.browser.msie){ return(false) };

                if(confirm('blargh: ajax upload failed! try without?')){
                  configure_non_ajax_post(
                    function(){ form.submit() }
                  );
                };
              }
            });
          }
        });
    };

    return(submitter);
  };

//
  s3Uploader.prototype.add_s3_inputs = function(form, inputs){
    var s3uploader = this;
    var input = s3uploader.input;

    if(s3uploader.s3_inputs){
      for(var i = 0; i < s3uploader.inputs; i++){
        s3uploader.inputs[i].remove();
      }
    };

    var s3_inputs = [];

    for(var name in inputs){
      var value = inputs[name];

      var input = $('<input type="hidden"/>');
        input.attr('name', name);
        input.attr('value', value);
        input.addClass('s3');

      s3_inputs.push(input);
    };

    var div = $('<div style="display:none;"></div>');

    form.prepend(div);

    for(var i = 0; i < s3_inputs.length; i++){
      var s3_input = s3_inputs[s3_inputs.length - (i + 1)];
      div.prepend(s3_input);
      div.prepend('<br>');
    };

    s3uploader.s3_inputs = s3_inputs;

    return(s3_inputs);
  };

//
  s3Uploader.callbacks = {};

  s3Uploader.callbacks['ajax.beforeSubmit'] =
    function(arr, form, options){
      var input = $(this);
    };

  s3Uploader.callbacks['ajax.uploadProgress'] =
    function(event, position, total, percent) {
      var input = $(this);
    };

  s3Uploader.callbacks['ajax.success'] =
    function(responseText, statusText, xhr, form){
      var input = $(this);
    };

  s3Uploader.callbacks['before'] =
    function(data){
    };

  s3Uploader.callbacks['progress'] =
    function(data){
    };

  s3Uploader.callbacks['success'] =
    function(data){
    };

//
  s3Uploader.basename = function(filename){
    var pos = filename.lastIndexOf("\\");
    if(pos != -1) { filename = filename.substr(pos + 1); }

    var pos = filename.lastIndexOf("/");
    if(pos != -1) { filename = filename.substr(pos + 1); }

    return(filename);
  };

//
  s3Uploader.uuid = function(){
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8);
      return v.toString(16);
    });
  };

//
  s3Uploader.merge_data_attributes = function(input, params){
    for(var k in input.data()){
      var v = input.data(k);

      var parts = k.split('_');

      if(parts[0] == 's3'){
        parts.shift();
        k = parts.join('_');
        params[k] = v;
      };
    };
  };

//
  s3Uploader.log = function(label, object){
    try{
      try{
        console.log(label + ' : ' + JSON.stringify(object));
      } catch(e){
        console.log(label + ' : ');
        console.dir(object);
      };
    } catch(e){};
  };


  window['s3Uploader'] = s3Uploader;
};
