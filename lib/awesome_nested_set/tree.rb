module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      class Tree
        attr_reader :model, :validate_nodes
        attr_accessor :indices

        delegate :left_column_name, :right_column_name, :quoted_parent_column_full_name,
                 :order_for_rebuild, :scope_for_rebuild,
                 :to => :model

        def initialize(model, validate_nodes)
          @model = model
          @validate_nodes = validate_nodes
          @indices = {}
        end

        def rebuild!
          # Don't rebuild a valid tree.
          return true if model.valid?

          root_nodes.each do |root_node|
            # setup index for this scope
            indices[scope_for_rebuild.call(root_node)] ||= 0
            set_left_and_rights(root_node)
          end
        end

        private

        def set_left_and_rights(node)
          scope_for_node = scope_for_rebuild.call(node)
          # set left
          node[left_column_name] = indices[scope_for_node] += 1
          # find
          model.where(["#{quoted_parent_column_full_name} = ? #{scope_for_node}", node]).
                order(order_for_rebuild).each { |n| set_left_and_rights(n) }
          # set right
          node[right_column_name] = indices[scope_for_node] += 1
          node.save!(:validate => validate_nodes)
        end

        def root_nodes
          model.where("#{quoted_parent_column_full_name} IS NULL").order(order_for_rebuild)
        end
      end
    end
  end
end
