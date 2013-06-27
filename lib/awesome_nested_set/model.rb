require 'awesome_nested_set/model/prunable'
require 'awesome_nested_set/model/movable'
require 'awesome_nested_set/model/transactable'
require 'awesome_nested_set/model/rebuildable'
require 'awesome_nested_set/model/validatable'
require 'awesome_nested_set/iterator'

module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:

      module Model
        extend ActiveSupport::Concern

        included do
          delegate :quoted_table_name, :arel_table, :to => self
          extend Validatable
          extend Rebuildable
          include Prunable
          include Movable
          include Transactable
        end

        module ClassMethods
          def associate_parents(objects)
            return objects unless objects.all? {|o| o.respond_to?(:association)}

            id_indexed = objects.index_by(&:id)
            objects.each do |object|
              association = object.association(:parent)
              parent = id_indexed[object.parent_id]

              if !association.loaded? && parent
                association.target = parent
                association.set_inverse_instance(parent)
              end
            end
          end

          def children_of(parent_id)
            where arel_table[parent_column_name].eq(parent_id)
          end

          # Iterates over tree elements and determines the current level in the tree.
          # Only accepts default ordering, odering by an other column than lft
          # does not work. This method is much more efficent than calling level
          # because it doesn't require any additional database queries.
          #
          # Example:
          #    Category.each_with_level(Category.root.self_and_descendants) do |o, level|
          #
          def each_with_level(objects, &block)
            Iterator.new(objects).each_with_level(&block)
          end

          def leaves
            where("#{quoted_right_column_full_name} - #{quoted_left_column_full_name} = 1").order(quoted_order_column_name)
          end

          def left_of(node)
            where arel_table[left_column_name].lt(node)
          end

          def left_of_right_side(node)
            where arel_table[right_column_name].lteq(node)
          end

          def right_of(node)
            where arel_table[left_column_name].gteq(node)
          end

          def primary_key_scope(id)
            where arel_table[primary_key].eq(id)
          end

          def root
            roots.first
          end

          def roots
            children_of(nil).order(quoted_order_column_name)
          end
        end # end class methods

        # Any instance method that returns a collection makes use of Rails 2.1's named_scope (which is bundled for Rails 2.0), so it can be treated as a finder.
        #
        #   category.self_and_descendants.count
        #   category.ancestors.find(:all, :conditions => "name like '%foo%'")
        # Value of the parent column
        def parent_id(target = self)
          target[parent_column_name]
        end

        # Value of the left column
        def left(target = self)
          target[left_column_name]
        end

        # Value of the right column
        def right(target = self)
          target[right_column_name]
        end

        # Returns true if this is a root node.
        def root?
          parent_id.nil?
        end

        # Returns true if this is the end of a branch.
        def leaf?
          persisted? && right.to_i - left.to_i == 1
        end

        # Returns true is this is a child node
        def child?
          !root?
        end

        def has_multiple_children?
          children.many?
        end

        # Returns root
        def root
          return self_and_ancestors.children_of(nil).first if persisted?

          if parent_id && current_parent = nested_set_scope.find(parent_id)
            current_parent.root
          else
            self
          end
        end

        # Returns an collection of all parents
        def ancestors
          without_self self_and_ancestors
        end

        # Returns the collection of all parents and self
        def self_and_ancestors
          nested_set_scope.
            where(arel_table[left_column_name].lteq(left)).
            where(arel_table[right_column_name].gteq(right))
        end

        # Returns the collection of all children of the parent, except self
        def siblings
          without_self self_and_siblings
        end

        # Returns the collection of all children of the parent, including self
        def self_and_siblings
          nested_set_scope.children_of parent_id
        end

        # Returns a set of all of its nested children which do not have children
        def leaves
          descendants.where("#{quoted_right_column_full_name} - #{quoted_left_column_full_name} = 1")
        end

        # Returns the level of this object in the tree
        # root level is 0
        def level
          parent_id.nil? ? 0 : compute_level
        end

        # All nested set queries should use this nested_set_scope, which
        # performs finds on the base ActiveRecord class, using the :scope
        # declared in the acts_as_nested_set declaration.
        def nested_set_scope(options = {})
          options = {:order => quoted_order_column_name}.merge(options)
          scopes = Array(acts_as_nested_set_options[:scope])
          options[:conditions] = scopes.inject({}) do |conditions,attr|
            conditions.merge attr => self[attr]
          end unless scopes.empty?
          self.class.base_class.unscoped.scoped options
        end

        # Returns a collection including all of its children and nested children
        def descendants
          without_self self_and_descendants
        end

        # Returns a collection including itself and all of its nested children
        def self_and_descendants
          # using _left_ for both sides here lets us benefit from an index on that column if one exists
          nested_set_scope.right_of(left).left_of(right)
        end

        def is_descendant_of?(other)
          other.left < self.left && self.left < other.right && same_scope?(other)
        end

        def is_or_is_descendant_of?(other)
          other.left <= self.left && self.left < other.right && same_scope?(other)
        end

        def is_ancestor_of?(other)
          self.left < other.left && other.left < self.right && same_scope?(other)
        end

        def is_or_is_ancestor_of?(other)
          self.left <= other.left && other.left < self.right && same_scope?(other)
        end

        # Check if other model is in the same scope
        def same_scope?(other)
          Array(acts_as_nested_set_options[:scope]).all? do |attr|
            self.send(attr) == other.send(attr)
          end
        end

        # Find the first sibling to the left
        def left_sibling
          siblings.left_of(left).last
        end

        # Find the first sibling to the right
        def right_sibling
          siblings.right_of(left).first
        end

        def to_text
          self_and_descendants.map do |node|
            "#{'*'*(node.level+1)} #{node.id} #{node.to_s} (#{node.parent_id}, #{node.left}, #{node.right})"
          end.join("\n")
        end

        protected
        def compute_level
          node, nesting = self, 0
          while (association = node.association(:parent)).loaded? && association.target
            nesting += 1
            node = node.parent
          end if node.respond_to? :association
          node == self ? ancestors.count : node.level + nesting
        end

        def without_self(scope)
          return scope if new_record?
          scope.where(["#{self.class.quoted_table_name}.#{self.class.primary_key} != ?", self])
        end

        def store_new_parent
          @move_to_new_parent_id = send("#{parent_column_name}_changed?") ? parent_id : false
          true # force callback to return true
        end

        def has_depth_column?
          nested_set_scope.column_names.map(&:to_s).include?(depth_column_name.to_s)
        end

        def set_depth!
          return unless has_depth_column?

          in_tenacious_transaction do
            reload
            nested_set_scope.primary_key_scope(id).
              update_all(["#{quoted_depth_column_name} = ?", level])
          end
          self[depth_column_name.to_sym] = self.level
        end

        # on creation, set automatically lft and rgt to the end of the tree
        def set_default_left_and_right
          right_most = nested_set_scope(:order => "#{quoted_right_column_full_name} desc").first
          right_most && right_most.lock!
          maxright = right_most ? (right_most[right_column_name] || 0) : 0
          # adds the new node to the right of all existing nodes
          self[left_column_name] = maxright + 1
          self[right_column_name] = maxright + 2
        end

        # reload left, right, and parent
        def reload_nested_set
          reload(
            :select => "#{quoted_left_column_full_name}, #{quoted_right_column_full_name}, #{quoted_parent_column_full_name}",
            :lock => true
          )
        end

        def reload_target(target)
          if target.is_a? self.class.base_class
            target.reload
          else
            nested_set_scope.find(target)
          end
        end
      end
    end
  end
end
