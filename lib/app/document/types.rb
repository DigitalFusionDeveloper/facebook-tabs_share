module App
  module Document
    if defined?(Mongoid::Fields::Serializable)

      class Type
        include Mongoid::Fields::Serializable

        class Map < Type
          def serialize(object)
            ::Map.for(object)
          end

          def deserialize(object)
            ::Map.for(object)
          end

          class Encrypted < Type
            def serialize(object)
              App.encode(App.json_for(::Map.for(object)))
            end

            def deserialize(object)
              begin
              ::Map.for(App.parse_json(App.decode(object)))
              rescue ::Object => e
                Rails.logger.warn(e)
                object
              end
            end
          end
        end
      end

    else

      class Type
        class Map < ::Map
          class << self
            def mongoize(object)
              case object
                when nil
                  nil
                when Map
                  object.to_hash
                else
                  object
              end
            end

            def demongoize(object)
              case object
                when nil
                  nil
                when Map
                  object
                else
                  Map.for(object)
              end
            end

            def evolve(object)
              mongoize(object)
            end
          end

          def mongoize
            to_hash
          end
        end

        class Encrypted
          class Value
            class << self
              def mongoize(object)
                return nil if object.nil?

                mongoized = App.encrypt(Marshal.dump(object))
              end

              def demongoize(mongoized)
                return nil if mongoized.nil?

                object = Marshal.load(App.decrypt(mongoized))
              end

              def evolve(object)
                mongoize(object)
              end
            end
          end

          class String < ::String
            class << self
              def mongoize(object)
                return nil if object.nil?

                string = Coerce.string(object)
                mongoized = App.encrypt(string)
              end

              def demongoize(mongoized)
                return nil if mongoized.nil?

                string = App.decrypt(mongoized)
              end

              def evolve(object)
                mongoize(object)
              end
            end
          end

          class Integer
            class << self
              def mongoize(object)
                return nil if object.nil?

                integer = Coerce.integer(object)
                string = integer.to_s
                mongoized = App.encrypt(string)
              end

              def demongoize(mongoized)
                return nil if mongoized.nil?

                string = App.decrypt(mongoized)
                integer = Integer(string)
              end

              def evolve(object)
                mongoize(object)
              end
            end
          end

          class Float
            class << self
              def mongoize(object)
                return nil if object.nil?

                float = Coerce.float(object)
                string = float.to_s
                mongoized = App.encrypt(string)
              end

              def demongoize(mongoized)
                return nil if mongoized.nil?

                string = App.decrypt(mongoized)
                float = Float(string)
              end

              def evolve(object)
                mongoize(object)
              end
            end
          end

          class Map < ::Map
            class << self
              def mongoize(object)
                return nil if object.nil?

                src = ::Map.for(object)
                dst = ::Map.new

                src.depth_first_each do |keys, value|
                  dst.set(keys, App.encrypt(Marshal.dump(value)))
                end

                dst
              end

              def demongoize(mongoized)
                return nil if mongoized.nil?

                src = ::Map.for(mongoized)
                dst = ::Map.new

                src.depth_first_each do |keys, value|
                  dst.set(keys, Marshal.load(App.decrypt(value)))
                end

                dst
              end

              def evolve(object)
                mongoize(object)
              end
            end

            def mongoize
              self.class.mongoize(self)
            end
          end
        end
      end

    end

    def Document.type_for(type)
      eval "::#{ Type.name }::#{ type.to_s.camelize }"
    end

    code_for 'app/document/types' do
      def self.type_for(*args, &block)
        ::App::Document.type_for(*args, &block)
      end

      def type_for(*args, &block)
        ::App::Document.type_for(*args, &block)
      end
    end
  end
end
