module App
  module Document
  ##
  #
    module Embedded
    end

  ##
  #
    load File.join('lib/app/document/code_blocks.rb')
    load File.join('lib/app/document/base.rb')
    load File.join('lib/app/document/field_names.rb')
    load File.join('lib/app/document/string_ids.rb')
    load File.join('lib/app/document/types.rb')
    load File.join('lib/app/document/transaction.rb')
    load File.join('lib/app/document/timestamps.rb')
    load File.join('lib/app/document/logger.rb')
    load File.join('lib/app/document/to_csv.rb')
    load File.join('lib/app/document/archive.rb')
    load File.join('lib/app/document/name_fields.rb')
    load File.join('lib/app/document/to_map.rb')
    load File.join('lib/app/document/markdown.rb')
    load File.join('lib/app/document/cache.rb')
    load File.join('lib/app/document/enum_cache.rb')
    load File.join('lib/app/document/define_class.rb')
    load File.join('lib/app/document/sequence.rb')
    load File.join('lib/app/document/filtered_fields.rb')
    load File.join('lib/app/document/routing.rb')
    load File.join('lib/app/document/matching.rb')


  ##
  #
    Code = proc do
      Document.code.each do |name, blocks|
        blocks.each do |block|
          module_eval(&block)
        end
      end
    end

  ##
  #
    def Document.models
      @models ||= []
    end

  ##
  #
    def Document.included(other)
      super
    ensure
      other.module_eval(&Code.to_proc)
      models.delete_if{|model| model.name == other.name}
      models.push(other)
    end

  ##
  #
    def Embedded.models
      @models ||= []
    end

  ##
  #
    def Embedded.included(other)
      super
    ensure
      other.module_eval(&Code.to_proc)
      models.push(other)
      models.uniq!
    end
  end
end
