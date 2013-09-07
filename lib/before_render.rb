module BeforeRender
  module ClassMethods
    def append_before_render_filter(*names, &blk)
      _insert_callbacks(names, blk) do |name, options| 
        set_callback(:render, :before, name, options) 
      end                                                             
    end

    def prepend_before_render_filter(*names, &blk)
      _insert_callbacks(names, blk) do |name, options| 
        set_callback(:render, :before, name, options.merge(:prepend => true)) 
      end                                                             
    end  
    
    def skip_before_render_filter(*names, &blk)
      _insert_callbacks(names, blk) do |name, options| 
        skip_callback(:render, :before, name, options)
      end                                                             
    end 
      
    alias_method :before_render, :append_before_render_filter
    alias_method :prepend_before_render, :prepend_before_render_filter
    alias_method :skip_before_render, :skip_before_render_filter
  end

  module InstancMethods
    def self.included klass
      klass.send :alias_method_chain, :render, :before_render_filter
      klass.send :define_callbacks, :render
    end

    def render_with_before_render_filter *opts, &blk
      run_callbacks :render, action_name do
        render_without_before_render_filter(*opts, &blk)
      end
    end
  end
end

AbstractController::Base.send(:extend,  BeforeRender::ClassMethods)
ActionController::Base.send(:include,  BeforeRender::InstancMethods)
