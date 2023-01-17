module ActiveRecord
  module JSONB
    module Associations
      module JoinDependency
        module JoinAssociation #:nodoc:
          def join_constraints(foreign_table, foreign_klass, join_type, alias_tracker)
            joins = []

            # The chain starts with the target table, but we want to end with it here (makes
            # more sense in this context), so we reverse
            reflection.chain.reverse_each.with_index(1) do |reflection, i|
              table = tables[-i]
              klass = reflection.klass

              if reflection.respond_to?(:options) && (reflection.options.keys & %i[foreign_store store]).any?
                join_keys   = reflection.join_keys
                key         = join_keys.key
                foreign_key = join_keys.foreign_key

                nodes = build_constraint(klass, table, key, foreign_table, foreign_key)

                joins << table.create_join(table, table.create_on(nodes), join_type)
              else
                join_scope = reflection.join_scope(table, foreign_table, foreign_klass)

                arel = join_scope.arel(alias_tracker.aliases)
                nodes = arel.constraints.first

                others, children = nodes.children.partition do |node|
                  !fetch_arel_attribute(node) { |attr| attr.relation.name == table.name }
                end

                nodes = table.create_and(children)

                joins << table.create_join(table, table.create_on(nodes), join_type)

                unless others.empty?
                  joins.concat arel.join_sources
                  append_constraints(joins.last, others)
                end
              end

              # The current table in this iteration becomes the foreign table in the next
              foreign_table, foreign_klass = table, klass
            end

            joins
          end

          # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          def build_constraint(klass, table, key, foreign_table, foreign_key)
            if reflection.options.key?(:foreign_store) && reflection.options.key?(:through)
              build_eq_constraint(
                klass,
                foreign_table, foreign_table[reflection.options[:foreign_store]],
                foreign_key, table, key
              )
            elsif reflection.options.key?(:foreign_store)
              build_eq_constraint(
                klass,
                table, table[reflection.options[:foreign_store]],
                key, foreign_table, foreign_key
              )
            elsif reflection.options.key?(:store) && reflection.belongs_to?
              build_eq_constraint(
                klass,
                foreign_table, foreign_table[reflection.options[:store]],
                foreign_key, table, key
              )
            elsif reflection.options.key?(:store) # && reflection.has_one?
              build_contains_constraint(
                table, table[reflection.options[:store]],
                key.pluralize, foreign_table, foreign_key
              )
            else
              super
            end
          end
          # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

          def build_eq_constraint(klass, table, jsonb_column, key, foreign_table, foreign_key)
            foreign_key_type = klass.type_for_attribute(foreign_key).type

            type =
              case foreign_key_type
              when :integer then 'bigint'
              else ActiveRecord::Base.connection.class::NATIVE_DATABASE_TYPES[foreign_key_type][:name]
              end

            foreign_table[foreign_key].eq(
              Arel::Nodes::NamedFunction.new('CAST', [Arel::Nodes::JSONBDashDoubleArrow.new(table, jsonb_column, key).as(type)])
            )
          end

          def build_contains_constraint(
            table, jsonb_column, key, foreign_table, foreign_key
          )
            Arel::Nodes::JSONBHashArrow.new(table, jsonb_column, key).contains(
              ::Arel::Nodes::SqlLiteral.new(
                "jsonb_build_array(#{foreign_table.name}.#{foreign_key})"
              )
            )
          end
        end
      end
    end
  end
end
