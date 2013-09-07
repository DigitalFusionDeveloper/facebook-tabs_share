module App
  module Document
    module CodeBlocks
      def code(*args, &block)
        @code ||= Map.new
        if !args.empty? and !block.nil?
          key = args.first
          @code[key] ||= Array.new
          @code[key].push(block)
          @code[key]
        else
          @code
        end
      end

      def code_for(*args, &block)
        code(*args, &block)
      end
    end

    Document.extend(CodeBlocks)
    Embedded.extend(CodeBlocks)
  end
end
