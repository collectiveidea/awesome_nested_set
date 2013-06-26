module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      class Tree
        attr_reader :klass, :validate_nodes, :scope
        attr_accessor :indices

        delegate :left_column_name, :right_column_name, :quoted_parent_column_full_name, :to => :klass

        def initialize(klass, validate_nodes)
          @klass = klass
          @scope = klass.scope_for_rebuild
          @validate_nodes = validate_nodes
          @indices = {}
        end

        def rebuild!
          # Don't rebuild a valid tree.
          return true if klass.valid?

          root_nodes.each do |root_node|
            # setup index for this scope
            indices[scope.call(root_node)] ||= 0
            set_left_and_rights(root_node)
          end
        end

        private

        def set_left_and_rights(node)
          # set left
          node[left_column_name] = indices[scope.call(node)] += 1
          # find
          klass.where(["#{quoted_parent_column_full_name} = ? #{scope.call(node)}", node]).order(klass.order_for_rebuild).each { |n| set_left_and_rights(n) }
          # set right
          node[right_column_name] = indices[scope.call(node)] += 1
          node.save!(:validate => validate_nodes)
        end

        def root_nodes
          klass.where("#{quoted_parent_column_full_name} IS NULL").order(klass.order_for_rebuild)
        end
      end
    end
  end
end
