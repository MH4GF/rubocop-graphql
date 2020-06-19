# frozen_string_literal: true

module RuboCop
  module Cop
    module GraphQL
      # This cop checks consistency of field definitions
      #
      # EnforcedStyle supports two modes:
      #
      # `group_definitions` : all field definitions should be grouped together.
      #
      # `define_resolver_after_definition` : if resolver method exists it should
      # be defined right after the field definition.
      #
      # @example EnforcedStyle: group_definitions (default)
      #   # good
      #
      #   class UserType < BaseType
      #     field :first_name, String, null: true
      #     field :last_name, String, null: true
      #
      #     def first_name
      #       object.contact_data.first_name
      #     end
      #
      #     def last_name
      #       object.contact_data.last_name
      #     end
      #   end
      #
      # @example EnforcedStyle: define_resolver_after_definition
      #   # good
      #
      #   class UserType < BaseType
      #     field :first_name, String, null: true
      #
      #     def first_name
      #       object.contact_data.first_name
      #     end
      #
      #     field :last_name, String, null: true
      #
      #     def last_name
      #       object.contact_data.last_name
      #     end
      #   end
      class FieldDefinitions < Cop
        include ConfigurableEnforcedStyle
        include RuboCop::GraphQL::NodePattern

        def_node_matcher :field_kwargs, <<~PATTERN
          (send nil? :field
            ...
            (hash
              $...
            )
          )
        PATTERN

        def on_send(node)
          return if !field_definition?(node) || style != :define_resolver_after_definition

          field = RuboCop::GraphQL::Field.new(node)
          check_resolver_is_defined_after_definition(field)
        end

        def on_class(node)
          return if style != :group_definitions

          schema_member = RuboCop::GraphQL::SchemaMember.new(node)

          if (body = schema_member.body)
            check_grouped_field_declarations(body)
          end
        end

        private

        GROUP_DEFS_MSG = "Group all field definitions together."

        def check_grouped_field_declarations(body)
          fields = body.select { |node| field?(node) }

          first_field = fields.first

          fields.each_with_index do |node, idx|
            next if node.sibling_index == first_field.sibling_index + idx

            add_offense(node, message: GROUP_DEFS_MSG)
          end
        end

        RESOLVER_AFTER_FIELD_MSG = "Define resolver method after field definition."

        def check_resolver_is_defined_after_definition(field)
          return if field.kwargs.resolver || field.kwargs.method || field.kwargs.hash_key

          method_definition = field.schema_member.find_method_definition(field.resolver_method_name)
          return unless method_definition

          field_sibling_index = if field_definition_with_body?(field.parent)
            field.parent.sibling_index
          else
            field.sibling_index
          end

          return if method_definition.sibling_index - field_sibling_index == 1

          add_offense(field.node, message: RESOLVER_AFTER_FIELD_MSG)
        end
      end
    end
  end
end
