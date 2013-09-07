module App
  module Document
    code_for 'app/document/matching' do

      class << self

        def match(*args, &block)
          options = args.extract_options!.to_options!

          pattern = options[:pattern]
          fields = options[:fields]

          if pattern.blank?
            pattern = match_pattern_for(*args)
          end

          if fields.blank?
            fields = default_match_fields
          end

          conditions = fields.map{|field| {field => pattern}}

          any_of(conditions, &block)
        end

        def default_match_fields
          fields = []

          self.fields.values.each do |field|
            case
              when [String, Array, Object].include?(field.type)
                fields.push(field.name)
              else
                nil
            end
          end

          fields
        end

        def match_pattern_for(*args, &block)
          options = args.extract_options!.to_options!

          terms =
            args.
            join(' ').
            strip.
            split(/\s+/).
            map{|word| word.gsub(/\A [^\w]+ | [^\w]+ \Z/imox, '')}

          words = terms.map{|term| "\\b#{ term }\\b"}

          /#{ words.join('|') }/i
        end

        def grep(pattern, *args, &block)
          options = args.extract_options!.to_options!
          options[:pattern] = pattern
          args.push(options)
          match(*args)
        end

        def =~(*args, &block)
          grep(*args, &block)
        end

      end

    end
  end
end
