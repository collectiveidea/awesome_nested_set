require 'awesome_nested_set/model/prunable'

module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:

      module Model
        extend ActiveSupport::Concern

        included do
          delegate :quoted_table_name, :to => self
          include Prunable
        end

        module ClassMethods
          # Returns the first root
          def root
            roots.first
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
            joins("LEFT OUTER JOIN #{quoted_table_name}" +
                  alias_keyword_for_adapter +
                  "parent ON " +
                  "#{quoted_parent_column_full_name} = parent.#{primary_key}").
              where(
                    "#{quoted_left_column_full_name} IS NULL OR " +
                    "#{quoted_right_column_full_name} IS NULL OR " +
                    "#{quoted_left_column_full_name} >= " +
                    "#{quoted_right_column_full_name} OR " +
                    "(#{quoted_parent_column_full_name} IS NOT NULL AND " +
                    "(#{quoted_left_column_full_name} <= parent.#{quoted_left_column_name} OR " +
                    "#{quoted_right_column_full_name} >= parent.#{quoted_right_column_name}))"
                    ).count == 0
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
              # Don't rebuild a valid tree.
              return true if valid?

              scope = lambda{|node|}
              if acts_as_nested_set_options[:scope]
                scope = lambda{|node|
                  scope_column_names.inject(""){|str, column_name|
                    str << "AND #{connection.quote_column_name(column_name)} = #{connection.quote(node.send(column_name.to_sym))} "
                  }
                }
              end
              indices = {}

              set_left_and_rights = lambda do |node|
                # set left
                node[left_column_name] = indices[scope.call(node)] += 1
                # find
                where(["#{quoted_parent_column_full_name} = ? #{scope.call(node)}", node]).order("#{quoted_left_column_full_name}, #{quoted_right_column_full_name}, #{primary_key}").each{|n| set_left_and_rights.call(n) }
                # set right
                node[right_column_name] = indices[scope.call(node)] += 1
                node.save!(:validate => validate_nodes)
              end

              # Find root node(s)
              root_nodes = where("#{quoted_parent_column_full_name} IS NULL").order("#{quoted_left_column_full_name}, #{quoted_right_column_full_name}, #{primary_key}").each do |root_node|
                # setup index for this scope
                indices[scope.call(root_node)] ||= 0
                set_left_and_rights.call(root_node)
              end
            end
          end

          # Iterates over tree elements and determines the current level in the tree.
          # Only accepts default ordering, odering by an other column than lft
          # does not work. This method is much more efficent than calling level
          # because it doesn't require any additional database queries.
          #
          # Example:
          #    Category.each_with_level(Category.root.self_and_descendants) do |o, level|
          #
          def each_with_level(objects)
            path = [nil]
            objects.each do |o|
              if o.parent_id != path.last
                # we are on a new level, did we descend or ascend?
                if path.include?(o.parent_id)
                  # remove wrong wrong tailing paths elements
                  path.pop while path.last != o.parent_id
                else
                  path << o.parent_id
                end
              end
              yield(o, path.length - 1)
            end
          end

          # Same as each_with_level - Accepts a string as a second argument to sort the list
          # Example:
          #    Category.each_with_level(Category.root.self_and_descendants, :sort_by_this_column) do |o, level|
          def sorted_each_with_level(objects, order)
            path = [nil]
            children = []
            objects.each do |o|
              children << o if o.leaf?
              if o.parent_id != path.last
                if !children.empty? && !o.leaf?
                  children.sort_by! &order
                  children.each { |c| yield(c, path.length-1) }
                  children = []
                end
                # we are on a new level, did we decent or ascent?
                if path.include?(o.parent_id)
                  # remove wrong wrong tailing paths elements
                  path.pop while path.last != o.parent_id
                else
                  path << o.parent_id
                end
              end
              yield(o,path.length-1) if !o.leaf?
            end
            if !children.empty?
              children.sort_by! &order
              children.each { |c| yield(c, path.length-1) }
            end
          end

          def associate_parents(objects)
            if objects.all?{|o| o.respond_to?(:association)}
              id_indexed = objects.index_by(&:id)
              objects.each do |object|
                if !(association = object.association(:parent)).loaded? && (parent = id_indexed[object.parent_id])
                  association.target = parent
                  association.set_inverse_instance(parent)
                end
              end
            else
              objects
            end
          end

          private
          ## AS clause not supported in Oracle in FROM clause for aliasing table name
          def alias_keyword_for_adapter
            (connection.adapter_name.match(/Oracle/).nil? ?  " AS " : " ")
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

        # Shorthand method for finding the left sibling and moving to the left of it.
        def move_left
          move_to_left_of left_sibling
        end

        # Shorthand method for finding the right sibling and moving to the right of it.
        def move_right
          move_to_right_of right_sibling
        end

        # Move the node to the left of another node
        def move_to_left_of(node)
          move_to node, :left
        end

        # Move the node to the left of another node
        def move_to_right_of(node)
          move_to node, :right
        end

        # Move the node to the child of another node
        def move_to_child_of(node)
          move_to node, :child
        end

        # Move the node to the child of another node with specify index
        def move_to_child_with_index(node, index)
          if node.children.empty?
            move_to_child_of(node)
          elsif node.children.count == index
            move_to_right_of(node.children.last)
          else
            move_to_left_of(node.children[index])
          end
        end

        # Move the node to root nodes
        def move_to_root
          move_to_right_of(root)
        end

        # Order children in a nested set by an attribute
        # Can order by any attribute class that uses the Comparable mixin, for example a string or integer
        # Usage example when sorting categories alphabetically: @new_category.move_to_ordered_child_of(@root, "name")
        def move_to_ordered_child_of(parent, order_attribute, ascending = true)
          self.move_to_root and return unless parent
          left = nil # This is needed, at least for the tests.
          parent.children.each do |n| # Find the node immediately to the left of this node.
            if ascending
              left = n if n.send(order_attribute) < self.send(order_attribute)
            else
              left = n if n.send(order_attribute) > self.send(order_attribute)
            end
          end
          self.move_to_child_of(parent)
          return unless parent.children.count > 1 # Only need to order if there are multiple children.
          if left # Self has a left neighbor.
            self.move_to_right_of(left)
          else # Self is the left most node.
            self.move_to_left_of(parent.children[0])
          end
        end

        def to_text
          self_and_descendants.map do |node|
            "#{'*'*(node.level+1)} #{node.id} #{node.to_s} (#{node.parent_id}, #{node.left}, #{node.right})"
          end.join("\n")
        end

        def move_possible?(target)
          self != target && # Can't target self
            same_scope?(target) && # can't be in different scopes
            # !(left..right).include?(target.left..target.right) # this needs tested more
            # detect impossible move
            !((left <= target.left && right >= target.left) or (left <= target.right && right >= target.right))
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
          scope.where(["#{self.class.quoted_table_name}.#{self.class.primary_key} != ?", self])
        end

        def store_new_parent
          @move_to_new_parent_id = send("#{parent_column_name}_changed?") ? parent_id : false
          true # force callback to return true
        end

        def move_to_new_parent
          if @move_to_new_parent_id.nil?
            move_to_root
          elsif @move_to_new_parent_id
            move_to_child_of(@move_to_new_parent_id)
          end
        end

        def set_depth!
          if nested_set_scope.column_names.map(&:to_s).include?(depth_column_name.to_s)
            in_tenacious_transaction do
              reload

              nested_set_scope.where(self.class.base_class.primary_key.to_sym => id).update_all(["#{quoted_depth_column_name} = ?", level])
            end
            self[depth_column_name.to_sym] = self.level
          end
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

        def in_tenacious_transaction(&block)
          retry_count = 0
          begin
            transaction(&block)
          rescue ActiveRecord::StatementInvalid => error
            raise unless connection.open_transactions.zero?
            raise unless error.message =~ /Deadlock found when trying to get lock|Lock wait timeout exceeded/
            raise unless retry_count < 10
            retry_count += 1
            logger.info "Deadlock detected on retry #{retry_count}, restarting transaction"
            sleep(rand(retry_count)*0.1) # Aloha protocol
            retry
          end
        end

        # reload left, right, and parent
        def reload_nested_set
          reload(
                 :select => "#{quoted_left_column_full_name}, #{quoted_right_column_full_name}, #{quoted_parent_column_full_name}",
                 :lock => true
                 )
        end

        def move_to(target, position)
          raise ActiveRecord::ActiveRecordError, "You cannot move a new node" if self.new_record?
          run_callbacks :move do
            in_tenacious_transaction do
              target = reload_target(target)
              self.reload_nested_set

              Move.new(target, position, self).move
            end
            target.reload_nested_set if target
            self.set_depth!
            self.descendants.each(&:save)
            self.reload_nested_set
          end
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
