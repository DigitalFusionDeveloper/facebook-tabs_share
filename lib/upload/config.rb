class Upload
  class Config < ::Map
    def Config.defaults
      Config.new({
        'strategy'   => 'grid_fs',

        'stable_for' => (Rails.stage && Rails.stage.production? ? 1.hour : 1.second),

        'fs' => {
          'root'  => Rails.root.join('public').to_s,
          'op'    => :cp
        },

        'sizes' => {
          'large'  => '640x',
          'medium' => '320x',
          'small'  => '50x'
        },
      })
    end
  end

# yes yes, the global variable seems weird, but it preserves the config across a console 'reload!'
#
  class << self
    def config
      config = eval("$upload_configs ||= Map.new")

      unless config.has_key?(name)
        if self == Upload
          config[name] = Config.defaults
        else
          inherited_defaults = Map.new

          upload_ancestors = ancestors.select{|ancestor| ancestor != self && ancestor <= Upload}

          upload_ancestors.reverse.each do |ancestor|
            inherited_defaults.update(ancestor.config)
          end

          config[name] = inherited_defaults 
        end
      end

      config[name]
    end
  end
end
