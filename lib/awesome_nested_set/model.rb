require 'awesome_nested_set/model/prunable'
require 'awesome_nested_set/model/movable'
require 'awesome_nested_set/model/transactable'
require 'awesome_nested_set/tree'
require 'awesome_nested_set/iterator'
require 'awesome_nested_set/set_validator'

module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:

      module Model
        extend ActiveSupport::Concern

        included do
          delegate :quoted_table_name, :to => self
          include Prunable
          include Movable
          include Transactable
        end

        module ClassMethods
          # Returns the first root
          def root
            roots.first
          end

          def primary_key_scope(id)
            where(primary_key.to_sym => id)
          end

          def roots
            where(parent_column_name => nil).order(quoted_left_column_full_name)
          end

          def leaves
            where("#{quoted_right_column_full_name} - #{quoted_left_column_full_name} = 1").order(quoted_left_column_full_name)
          end

          def valid?
            left_and_rights_valid? && no_duplicates_for_columns? && all_roots_valid?
          end

          def left_of_right_side(node)
            where(["#{quoted_right_column_full_name} <= ?", node])
          end

          def right_of(node)
            where(["#{quoted_left_column_full_name} >= ?", node])
          end

          def left_and_rights_valid?
            SetValidator.new(self).valid?
          end

          def no_duplicates_for_columns?
            scope_string = Array(acts_as_nested_set_options[:scope]).map do |c|
              connection.quote_column_name(c)
            end.push(nil).join(", ")
            [quoted_left_column_full_name, quoted_right_column_full_name].all? do |column|
              # No duplicates
              select("#{scope_string}#{column}, COUNT(#{column})").
                group("#{scope_string}#{column}").
                having("COUNT(#{column}) > 1").
                first.nil?
            end
          end

          # Wrapper for each_root_valid? that can deal with scope.
          def all_roots_valid?
            if acts_as_nested_set_options[:scope]
              roots.group_by {|record| scope_column_names.collect {|col| record.send(col.to_sym) } }.all? do |scope, grouped_roots|
                each_root_valid?(grouped_roots)
              end
            else
              each_root_valid?(roots)
            end
          end

          def each_root_valid?(roots_to_validate)
            left = right = 0
            roots_to_validate.all? do |root|
              (root.left > left && root.right > right).tap do
                left = root.left
                right = root.right
              end
            end
          end

          # Rebuilds the left & rights if unset or invalid.
          # Also very useful for converting from acts_as_tree.
          def rebuild!(validate_nodes = true)
            # default_scope with order may break database queries so we do all operation without scope
            unscoped do
              Tree.new(self, validate_nodes).rebuild!
            end
          end

          def scope_for_rebuild
            scope = lambda {|node|}

            if acts_as_nested_set_options[:scope]
              scope = lambda {|node|
                scope_column_names.inject("") {|str, column_name|
                  str << "AND #{connection.quote_column_name(column_name)} = #{connection.quote(node.send(column_name.to_sym))} "
                }
              }
            end
            scope
          end

          def order_for_rebuild
            "#{quoted_left_column_full_name}, #{quoted_right_column_full_name}, #{primary_key}"
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

          # Same as each_with_level - Accepts a string as a second argument to sort the list
          # Example:
          #    Category.sorted_each_with_level(Category.root.self_and_descendants, :sort_by_this_column) do |o, level|
          def sorted_each_with_level(objects, order, &block)
            Iterator.new(objects).sorted_each_with_level(order, &block)
          end

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
          children.count > 1
        end

        # Returns root
        def root
          return self_and_ancestors.where(parent_column_name => nil).first if persisted?

          if parent_id && current_parent = nested_set_scope.find(parent_id)
            current_parent.root
          else
            self
          end
        end

        # Returns the array of all parents and self
        def self_and_ancestors
          nested_set_scope.where([
                                  "#{quoted_left_column_full_name} <= ? AND #{quoted_right_column_full_name} >= ?", left, right
                                 ])
        end

        # Returns an array of all parents
        def ancestors
          without_self self_and_ancestors
        end

        # Returns the array of all children of the parent, including self
        def self_and_siblings
          nested_set_scope.where(parent_column_name => parent_id)
        end

        # Returns the array of all children of the parent, except self
        def siblings
          without_self self_and_siblings
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

        # Returns a set of itself and all of its nested children
        def self_and_descendants
          # using _left_ for both sides here lets us benefit from an index on that column if one exists
          nested_set_scope.right_of(left).
            where(["#{quoted_left_column_full_name} < ?", right])
        end

        # Returns a set of all of its children and nested children
        def descendants
          without_self self_and_descendants
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
          siblings.where(["#{quoted_left_column_full_name} < ?", left]).last
        end

        # Find the first sibling to the right
        def right_sibling
          siblings.where(["#{quoted_left_column_full_name} > ?", left]).first
        end

        def to_text
          self_and_descendants.map do |node|
            "#{'*'*(node.level+1)} #{node.id} #{node.to_s} (#{node.parent_id}, #{node.left}, #{node.right})"
          end.join("\n")
        end

        # All nested set queries should use this nested_set_scope, which performs finds on
        # the base ActiveRecord class, using the :scope declared in the acts_as_nested_set
        # declaration.
        def nested_set_scope(options = {})
          options = {:order => quoted_order_column_name}.merge(options)
          scopes = Array(acts_as_nested_set_options[:scope])
          options[:conditions] = scopes.inject({}) do |conditions,attr|
            conditions.merge attr => self[attr]
          end unless scopes.empty?
          self.class.base_class.unscoped.scoped options
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
          highest_right_row = nested_set_scope(:order => "#{quoted_right_column_full_name} desc").first
          highest_right_row && highest_right_row.lock!
          maxright = highest_right_row ? (highest_right_row[right_column_name] || 0) : 0
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
