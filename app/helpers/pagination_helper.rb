module PaginationHelper
  include Kaminari::ActionViewExtension
  alias_method(:kamanari_paginate, :paginate)

  def paginate(collection, options = {})
  #
    options.to_options!

    placeholder = ( options.has_key?(:placeholder) ? options[:placeholder] : '#' ).to_s
    readonly = !!( options.has_key?(:readonly) ? options[:readonly] : false )

  #
    css = Map.new
    css[:class] = String(options.delete(:class) || 'pagination')
    css[:class] << ' pagination' unless css[:class] =~ /\Apagination\Z/

  #
    disabled = readonly

  #
    num_pages = collection.num_pages
    current_page = collection.current_page
    max_digits = [placeholder.size, num_pages > 0 ? Math.log(num_pages, 11).ceil : 0].max

  #
    params = controller.params.merge(options[:params] || {})

  #
    page_url_for = proc do |pageno|
      url_for(params.merge(:page => pageno))
    end

  #
    if num_pages <= 1
      return nav_(css){}
    end

  #
    nav_(css){
      ul_{
        pageno = 1
        li_(:class => (:disabled if current_page == pageno)){
          a_(:href => page_url_for[pageno], :title => "first page"){ pageno }
        }

        pageno = [1, current_page - 1].max
        li_(:class => (:disabled if current_page == pageno)){
          a_(:href => page_url_for[pageno], :title => "previous page"){ '&larr;'.html_safe }
        }

        pageno = current_page
        li_(:class => :active){
          a_(:href => 'javascript:void(42)', :title => "jump to page 1-#{ num_pages - 1 }"){
            style = style_for(
              'padding' => '0',
              'margin'  => '0',
              'border'  => '0',
              'outline' => '0',
              'display' => 'inline',
              'color' => 'inherit'
            )

            form_(:style => style, :method => :GET, :url => url_for(params)){
              id = "pagination-#{ App.uuid }"

              url, query_string = request.fullpath.split('?')

              attrs = {
                'id'           => id,
                'name'         => :page,
                'value'        => current_page,
                'placeholder'  => placeholder,
                'autocomplete' => :off,

                'style' => style_for(
                  'padding'          => '0',
                  'margin'           => '0',
                  'border'           => '0',
                  'outline'          => '0',

                  'font-family'      => 'inherit',
                  'font-size'        => 'inherit',
                  'line-height'      => 'inherit',
                  'vertical-align'   => 'top',
                  'text-align'       => 'center',
                  'height'           => '1.1em',
                  'width'            => "#{ max_digits }em",
                  'color'            => 'inherit',
                  'cursor'           => (readonly ? 'inherit' : 'pointer'),
                  'background-color' => 'inherit'
                ),

                'data-minimum_page' => 1,
                'data-current_page' => current_page,
                'data-maximum_page' => [num_pages - 1, 1].max
              }

              attrs[:readonly] = attrs[:disabled] = true if readonly

              blacklist = %w( action controller utf8 )
              params.each do |key, val|
                name, value = {key => val}.to_param.split(/=/, 2)
                next if blacklist.include?(name)
                input_(:type => :hidden, :name => name, :value => value){}
              end

              input_(attrs){}

              unless readonly
                script_{
                  pagination_script_for("##{ id }")
                }
              end
            }
          }
        }


        pageno = [[current_page + 1, num_pages].min, 1].max
        li_(:class => (:disabled if current_page == pageno)){
          a_(:href => page_url_for[pageno], :title => "next page"){ '&rarr;'.html_safe }
        }

        pageno = [num_pages, 1].max
        li_(:class => (:disabled if current_page == pageno)){
          a_(:href => page_url_for[pageno], :title => "last page"){ pageno }
        }
      }
    }
  end

  def pagination_script_for(selector)
    %`

      jq(function(){
        var input = jq(#{ selector.to_json });
        var _form = input.get(0).form;
        var form = jq(_form);

        var color = form.closest('ul').find('a:first').css('color');

        input.css('color', color);

        //var link = form.find('a:first');
        //window.link = link;

        var minimum_page = input.data('minimum_page');
        var current_page = input.data('current_page');
        var maximum_page = input.data('maximum_page');

        var normalize = function(){
          var page = parseInt(input.attr('value')) || current_page;
          page = Math.min(maximum_page, Math.max(minimum_page, page));
          input.attr('value', page);
          return(page);
        };

        var focus = function(){
          var value = '' + input.attr('value').trim();
          input.attr('value', '');
          return(true);
        };

        var blur = function(){
          var page = input.normalize();
          if(page != current_page){ form.submit(); };
          return(true);
        };

        var submit = function(){
          input.normalize();
          return(true);
        };

        form.submit(submit);

        input.normalize = normalize;
        input.focus(focus);
        input.blur(blur);
        //input.hover(function(){ input.focus() }, function(){ input.blur() });
      });

    `
  end
end
