module ActiveRecord
  module JSONB
    module Associations
      module Builder
        module BelongsTo #:nodoc:
          def valid_options(options)
            super + [:store]
          end

          def define_accessors(mixin, reflection)
            add_association_accessor_methods(mixin, reflection) if reflection.options.key?(:store)

            super
          end

          def add_association_accessor_methods(mixin, reflection)
            foreign_key = reflection.foreign_key.to_s

            mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
              @@jsonb_foreign_key_store ||= {}

              @@jsonb_foreign_key_store[foreign_key] = reflection.options[:store]

              def #{foreign_key}=(value)
                public_send(self.class.jsonb_foreign_key_store['#{foreign_key}'])['#{foreign_key}'] = value
              end

              if @@jsonb_foreign_key_store.size < 2
                class << self
                  def jsonb_foreign_key_store
                    @@jsonb_foreign_key_store
                  end
                end

                def _read_attribute(attr_name)
                  key   = attr_name.to_s
                  store = self.class.jsonb_foreign_key_store[key]

                  if store && has_attribute?(store)
                    public_send(store)[key]
                  else
                    super
                  end
                end

                def []=(key, value)
                  key = key.to_s

                  if self.class.jsonb_foreign_key_store.keys.include?(key)
                    public_send("\#{key}=", value)
                  else
                    super
                  end
                end
              end
            CODE
          end
        end
      end
    end
  end
end
