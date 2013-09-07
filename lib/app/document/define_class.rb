module App
  module Document
    Document.code_for :define_class do
      def self.define_class(name, &block)
        const = name.to_s.camelize
        const_set(const, Class.new)
        c = const_get(const)
        c.class_eval(&block)
      end
    end
  end
end
