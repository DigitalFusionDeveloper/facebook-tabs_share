module App
  module Document
    code_for 'app/document/markdown' do
      def self.markdown(*args, &block)
        key = args.flatten

        unless field_names.any?{|_| _.to_s == 'raw'}
          field(:raw, :type => type_for(:map), :default => proc{ Map.new })
        end

        unless field_names.any?{|_| _.to_s == 'markdown'}
          field(:markdown, :type => type_for(:map), :default => proc{ Map.new })

          class_eval do
            def markdown!(*args)
              args.flatten!
              content = args.pop
              key = args
              raw.set(key => content.to_s.strip)
            end

            alias_method(:md, :markdown)
          end
        end

        before_validation do |doc|
          markdown_raw!(key)
        end

        if key.size == 1
          class_eval do
            define_method("#{ key.first }="){|val| raw.set(key, val)}
            define_method("#{ key.first }"){ markdown.get(key)}
          end
        end
      end

      def markdown_raw!(keys = [])
        doc = self

        if keys.blank?
          keys = raw.keys
        end

        keys = Array(keys)

        keys.each do |key|
          value = raw.get(key)

          unless value.blank?
            markdown = Util.markdown(value)
            doc.markdown.set(key, markdown)
          else
            doc.markdown.set(key, nil)
          end
        end
      end
    end
  end
end
