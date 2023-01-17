module ActiveRecord
  module JSONB
    module Associations
      module AssociationScope #:nodoc:
        def next_chain_scope(scope, reflection, next_reflection)
          options = reflection.instance_variable_get(:@association)&.options || {}

          return super unless options.key?(:foreign_store)

          join_keys     = reflection.join_keys
          key           = join_keys.key
          foreign_key   = join_keys.foreign_key
          table         = reflection.aliased_table
          foreign_table = next_reflection.aliased_table
          klass         = reflection.klass
          key_type      = klass.type_for_attribute(key).type

          type =
            case key_type
              when :integer then 'bigint'
              else ActiveRecord::Base.connection.class::NATIVE_DATABASE_TYPES[key_type][:name]
            end

          constraint =
            table[key].eq(
              Arel::Nodes::NamedFunction.new('CAST', [ Arel::Nodes::JSONBDashDoubleArrow.new(foreign_table, foreign_table[options[:foreign_store]], foreign_key).as(type)])
            )

          # TODO: It is necessary to fix the logic for polymorphic associations, taking into account changes in the `store_base_sti_class` library
          if reflection.type
            value = transform_value(next_reflection.klass.polymorphic_name)
            scope = apply_scope(scope, table, reflection.type, value)
          end

          scope.joins!(join(foreign_table, constraint))
        end

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def last_chain_scope(scope, reflection, owner)
          return super unless reflection

          join_keys = reflection.join_keys
          key = join_keys.key
          foreign_key = join_keys.foreign_key
          table = reflection.aliased_table
          value = transform_value(owner[foreign_key])
          association = reflection&.instance_variable_get(:@association)
          options = association&.options || reflection.try(:options)

          if options&.key?(:foreign_store)
            apply_jsonb_scope(
              scope,
              jsonb_equality(
                table, options[:foreign_store], key, value
              )
            )
          elsif options&.key?(:store)
            return super if association.is_a?(ActiveRecord::Associations::BelongsToAssociation)

            apply_jsonb_scope(
              scope,
              jsonb_containment(
                table, options[:store], key.pluralize, value
              )
            )
          else
            super
          end
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        def apply_jsonb_scope(scope, predicate)
          scope.where!(predicate)
        end

        def jsonb_equality(table, jsonb_column, key, value)
          Arel::Nodes::JSONBDashDoubleArrow.new(
            table, table[jsonb_column], key
          ).eq(Relation::QueryAttribute.new(key, value, ActiveModel::Type::String.new))
        end

        def jsonb_containment(table, jsonb_column, key, value)
          Arel::Nodes::JSONBHashArrow.new(
            table, table[jsonb_column], key
          ).contains(Relation::QueryAttribute.new(key, value, ActiveModel::Type::String.new))
        end
      end
    end
  end
end
