// find and pre-compile all templates on the page. cache them by name.
//
// Template('flash-list-item',  {message:'foobar'} )
//
// or
//
// Template('flash-list-item').render({message:'foobar'})
//
// or
//
// template = Template('flash-list-item')
// template.render({message:'foobar'})
//
//
  if(!window.Template){

    var Template = function(){
      var args = Array.prototype.slice.apply(arguments);

      if(args.length == 2){
        if(typeof(args[1]) === 'string'){
          this.name = Template.strip(args.shift());
          this.template = Template.strip(args.shift());
        } else {
          name = args.shift();
          var template = Template.cache[name];
          return template.render.apply(template, args);
        };
      } else {
        name = args.shift();
        var template = Template.cache[name];
        return(template);
      }
    };

    Template.prototype.compile = function() {
      return { 
        compiled: Handlebars.compile(this.template),
        render: function(context) {
          return this.compiled(context);
        }
      }
    };

    Template.prototype.render = function(view){
      return (Handlebars.compile(this.template)(view)).replace(/^\s+/,'').replace(/\s+$/,'');
    };

    Template.cache = {};

    Template.compile = function(selector){
      var scope = jQuery(selector || 'body');
      var templates = [];

      scope.find('.template').each(function(){
        var j = jQuery(this);
        var name = j.attr('name');
        var html = j.html();
        var template = new Template(name, html);
        Template.cache[name] = Template.cache[name] || template.compile();
        templates.push(template);
      });

      return(templates);
    };

    Template.strip = function(string){
      return( ('' + string).trim(/^\s+/).trim(/\s+$/) );
    };

    jQuery(function(){
      Template.compile();
    });

    window.Template = Template;
  }
