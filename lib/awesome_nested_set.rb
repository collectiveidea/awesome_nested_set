module CollectiveIdea
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      def self.included(base)
        base.extend(SingletonMethods)
      end

      # This acts provides Nested Set functionality. Nested Set is a smart way to implement
      # an _ordered_ tree, with the added feature that you can select the children and all of their
      # descendants with a single query. The drawback is that insertion or move need some complex
      # sql queries. But everything is done here by this module!
      #
      # Nested sets are appropriate each time you want either an orderd tree (menus,
      # commercial categories) or an efficient way of querying big trees (threaded posts).
      #
      # == API
      #
      # Methods names are aligned with acts_as_tree as much as possible, to make replacment from one
      # by another easier, except for the creation:
      #
      # in acts_as_tree:
      #   item.children.create(:name => "child1")
      #
      # in acts_as_nested_set:
      #   # adds a new item at the "end" of the tree, i.e. with child.left = max(tree.right)+1
      #   child = MyClass.new(:name => "child1")
      #   child.save
      #   # now move the item to its right place
      #   child.move_to_child_of my_item
      #
      # You can pass an id or an object to:
      # * <tt>#move_to_child_of</tt>
      # * <tt>#move_to_right_of</tt>
      # * <tt>#move_to_left_of</tt>
      #
      module SingletonMethods
        # Configuration options are:
        #
        # * +parent_column+ - specifies the column name to use for keeping the position integer (default: parent_id)
        # * +left_column+ - column name for left boundry data, default "lft"
        # * +right_column+ - column name for right boundry data, default "rgt"
        # * +scope+ - restricts what is to be considered a list. Given a symbol, it'll attach "_id"
        #   (if that hasn't been already) and use that as the foreign key restriction. It's also possible
        #   to give it an entire string that is interpolated if you need a tighter scope than just a foreign key.
        #   Example: <tt>acts_as_nested_set :scope => 'todo_list_id = #{todo_list_id} AND completed = 0'</tt>
        #
        # See CollectiveIdea::Acts::NestedSet::ClassMethods for a list of class methods and
        # CollectiveIdea::Acts::NestedSet::InstanceMethods for a list of instance methods added 
        # to acts_as_nested_set models
        def acts_as_nested_set(options = {})
          options = {
            :parent_column => 'parent_id',
            :left_column => 'lft',
            :right_column => 'rgt'
          }.merge(options)
          
          if options[:scope].is_a?(Symbol) && options[:scope].to_s !~ /_id$/
            options[:scope] = "#{options[:scope]}_id".intern
          end

          write_inheritable_attribute :acts_as_nested_set_options, options
          class_inheritable_reader :acts_as_nested_set_options
          
          include InstanceMethods
          include Comparable
          include Columns
          extend Columns
          extend ClassMethods

          # no bulk assignment
          attr_protected  left_column_name.intern,
                          right_column_name.intern, 
                          parent_column_name.intern
                          
          before_create :set_default_left_and_right
          before_destroy :prune_from_tree
                          
          # no assignment to structure fields
          [left_column_name, right_column_name, parent_column_name].each do |column|
            module_eval <<-"end_eval", __FILE__, __LINE__
              def #{column}=(x)
                raise ActiveRecord::ActiveRecordError, "Unauthorized assignment to #{column}: it's an internal field handled by acts_as_nested_set code, use move_to_* methods instead."
              end
            end_eval
          end
          
          named_scope :roots, :conditions => {parent_column_name => nil}, :order => left_column_name
          named_scope :leaves, :conditions => "#{right_column_name} - #{left_column_name} = 1", :order => left_column_name
          
        end
        
      end
      
      module ClassMethods
        
        # Returns the first root
        def root
          roots.find(:first)
        end
        
        def valid?
          left_and_rights_valid? && 
            no_duplicates_for_column?(quoted_left_column_name) &&
            no_duplicates_for_column?(quoted_right_column_name) &&                                                        
            all_roots_valid?
        end
        
        def left_and_rights_valid?
          !find(:all).any? do |node|
            node.left.blank? ||
            node.right.blank? ||
            node.left >= node.right ||
            (!node.parent.blank? &&
              (node.parent.left.blank? || node.parent.right.blank? || 
              node.left <= node.parent.left ||
              node.right >= node.parent.right))
          end
          
          # No invalid left/right values  
          # find(:first, :select => "#{quoted_table_name}.*", 
          #   :joins => "JOIN #{quoted_table_name} AS parent ON #{quoted_table_name}.#{quoted_parent_column_name} = parent.#{primary_key}", 
          #   :conditions => "#{quoted_table_name}.#{quoted_left_column_name} IS NULL OR #{quoted_table_name}.#{quoted_right_column_name} IS NULL OR #{quoted_table_name}.#{quoted_left_column_name} <= parent.#{quoted_left_column_name} OR
          #   #{quoted_table_name}.#{quoted_right_column_name} >= parent.#{quoted_right_column_name} OR #{quoted_table_name}.#{quoted_left_column_name} <= #{quoted_table_name}.#{quoted_right_column_name}").nil? &&
        end
        
        # pass in quoted_left_column_name or quoted_right_column_name
        def no_duplicates_for_column?(column)
          scope_string = acts_as_nested_set_options[:scope] ?  "#{quoted_scope_column_name}, " : ''
          # No duplicates
          find(:first, 
            :select => "#{scope_string}#{column}, COUNT(#{column})", 
            :group => "#{scope_string}#{column} 
              HAVING COUNT(#{column}) > 1").nil?
        end
        
        # Wrapper for each_root_valid? that can deal with scope.
        def all_roots_valid?
          if acts_as_nested_set_options[:scope]
            roots.group_by(&scope_column_name.to_sym).all? do |scope, grouped_roots|
              each_root_valid?(grouped_roots)
            end
          else
            each_root_valid?(roots)
          end
        end
        
        def each_root_valid?(roots_to_validate)
          left = right = 0
          roots_to_validate.all? do |root|
            returning(root.left > left && root.right > right) do
              left = root.left
              right = root.right
            end
          end
        end
                
        # Rebuilds the left & rights if unset or invalid.  Also very useful for converting from acts_as_tree.
        def rebuild!
          # Don't rebuild a valid tree.
          return true if valid?
          
          scope = lambda{}
          if acts_as_nested_set_options[:scope]
            scope = lambda{|node| "AND #{node.scope_column_name} = #{node.send(:scope_column_name)}"}
          end
          indices = {}
          
          set_left_and_rights = lambda do |node|
            # set left
            node[left_column_name] = indices[scope.call(node)] += 1
            # find
            find(:all, :conditions => ["parent_id = ? #{scope.call(node)}", node], :order => "#{left_column_name}, #{right_column_name}, id").each{|n| set_left_and_rights.call(n) }
            # set right
            node[right_column_name] = indices[scope.call(node)] += 1    
            node.save!    
          end
                              
          # Find root node(s)
          root_nodes = find(:all, :conditions => "parent_id IS NULL", :order => "#{left_column_name}, #{right_column_name}, id").each do |root_node|
            # setup index for this scope
            indices[scope.call(root_node)] ||= 0
            set_left_and_rights.call(root_node)
          end
        end
      end
      
      # Mixed into both classes and instances to provide easy access to the column names
      module Columns
        def left_column_name
          acts_as_nested_set_options[:left_column]
        end
        
        def right_column_name
          acts_as_nested_set_options[:right_column]
        end
        
        def parent_column_name
          acts_as_nested_set_options[:parent_column]
        end
        
        def scope_column_name
          acts_as_nested_set_options[:scope]
        end
        
        def quoted_left_column_name
          connection.quote_column_name(left_column_name)
        end
        
        def quoted_right_column_name
          connection.quote_column_name(right_column_name)
        end
        
        def quoted_parent_column_name
          connection.quote_column_name(parent_column_name)
        end
        
        def quoted_scope_column_name
          connection.quote_column_name(scope_column_name)
        end
      end

      # Any instance method that returns a collection makes use of Rails 2.1's named_scope (which is bundled for Rails 2.0), so it can be treated as a finder.
      #
      #   category.self_and_descendants.count
      #   category.ancestors.find(:all, :conditions => "name like '%foo%'")
      module InstanceMethods
        # alias ActiveRecord::Base::Scope so we don't always have to refer to it with the long name
        Scope = ActiveRecord::Base::Scope
        
        # Value of the parent column
        def parent_id
          self[parent_column_name]
        end
        
        # Value of the left column
        def left
          self[left_column_name]
        end
        
        # Value of the right column
        def right
          self[right_column_name]
        end

        # Returns true if this is a root node.
        def root?
          parent_id.nil?
        end
        
        def leaf?
          right - left == 1
        end

        # Returns true is this is a child node
        def child?
          !parent_id.nil?
        end

        # order by left column
        def <=>(x)
          left <=> x.left
        end

        # Adds a child to this object in the tree.  If this object hasn't been initialized,
        # it gets set up as a root node.  Otherwise, this method will update all of the
        # other elements in the tree and shift them to the right, keeping everything
        # balanced.
        #
        # Deprecated, will be removed in next versions
        def add_child( child )
          self.reload
          child.reload

          if child.root?
            raise ActiveRecord::ActiveRecordError, "Adding sub-tree isn\'t currently supported"
          else
            if ( (self[left_column_name] == nil) || (right == nil) )
              # Looks like we're now the root node!  Woo
              self[left_column_name] = 1
              self[right_column_name] = 4

              # What do to do about validation?
              return nil unless self.save

              child[acts_as_nested_set_options[:parent_column]] = self.id
              child[left_column_name] = 2
              child[right_column_name]= 3
              return child.save
            else
              # OK, we need to add and shift everything else to the right
              child[acts_as_nested_set_options[:parent_column]] = self.id
              right_bound = right
              child[left_column_name] = right_bound
              child[right_column_name] = right_bound + 1
              self[right_column_name] += 2
              self.class.base_class.transaction {
                self.class.base_class.update_all( "#{left_column_name} = (#{left_column_name} + 2)",  "#{acts_as_nested_set_options[:scope]} AND #{left_column_name} >= #{right_bound}" )
                self.class.base_class.update_all( "#{right_column_name} = (#{right_column_name} + 2)",  "#{acts_as_nested_set_options[:scope]} AND #{right_column_name} >= #{right_bound}" )
                self.save
                child.save
              }
            end
          end
        end

        # Returns root
        def root
          self_and_ancestors.find(:first)
        end

        # Returns the immediate parent
        def parent
          nested_set_scope.find_by_id(parent_id) if parent_id
        end

        # Returns the array of all parents and self
        def self_and_ancestors
          Scope.new(nested_set_scope, :conditions => "#{left_column_name} <= #{left} AND #{right_column_name} >= #{right}")
        end

        # Returns an array of all parents
        def ancestors
          without_self self_and_ancestors
        end

        # Returns the array of all children of the parent, including self
        def self_and_siblings
          parent.children
        end

        # Returns the array of all children of the parent, except self
        def siblings
          without_self self_and_siblings
        end

        # Returns a set of all of its nested children which do not have children  
        def leaves
          Scope.new(descendants, :conditions => "#{right_column_name} - #{left_column_name} = 1")
        end    

        # Returns the level of this object in the tree
        # root level is 0
        def level
          if parent_id.nil?
            0 
          else
            nested_set_scope.count(:conditions => "(#{left_column_name} < #{left} AND #{right_column_name} > #{right})")
          end
        end

        # Returns a set of itself and all of its nested children
        def self_and_descendants
          Scope.new(nested_set_scope,
            :conditions => "#{left_column_name} >= #{left} AND #{right_column_name} <= #{right}")
        end

        # Returns a set of all of its children and nested children
        def descendants
          without_self self_and_descendants
        end

        # Returns a set of only this entry's immediate children
        def children
          Scope.new(nested_set_scope, :conditions => {parent_column_name => self})
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
          !acts_as_nested_set_options[:scope] ||
            self.send(scope_column_name) == other.send(scope_column_name)
        end

        # Find the first sibling to the right
        def left_sibling
          nested_set_scope.find(:first,
            :conditions => ["#{quoted_left_column_name} < ? AND #{quoted_parent_column_name} = ?",
              left, parent_id],
            :order => "#{left_column_name} DESC"
          )
        end

        # Find the first sibling to the right
        def right_sibling
          nested_set_scope.find(:first,
            :conditions => ["#{quoted_left_column_name} > ? AND #{quoted_parent_column_name} = ?",
              left, parent_id],
            :order => left_column_name
          )
        end

        # Shorthand method for finding the left sibling and moving to the left of it.
        def move_left
          move_to_left_of left_sibling
        end

        # Shorthand method for finding the right sibling and moving to the right of it.
        def move_right
          move_to_right_of right_sibling
        end

        # Move the node to the left of another node (you can pass id only)
        def move_to_left_of(node)
          move_to node, :left
        end

        # Move the node to the left of another node (you can pass id only)
        def move_to_right_of(node)
          move_to node, :right
        end

        # Move the node to the child of another node (you can pass id only)
        def move_to_child_of(node)
          move_to node, :child
        end
        
        def move_possible?(target)
          # Can't target self
          self != target && 
          # can't be in different scopes
          same_scope?(target) &&
          # detect impossible move
          # !(left..right).include?(target.left..target.right) # this needs tested more
          !((left <= target.left && right >= target.left) or (left <= target.right && right >= target.right))
        end
        
        def to_text
          self_and_descendants.map do |node|
            "#{'*'*(node.level+1)} #{node.id} #{node.to_s} (#{node.parent_id}, #{node.left}, #{node.right})"
          end.join("\n")
        end
        
      protected
      
        def without_self(scope)
          Scope.new(scope, :conditions => ["#{self.class.primary_key} != ?", self])
        end
        
        # All nested set queries should use this nested_set_scope, which performs finds on
        # the base ActiveRecord class, using the :scope declared in the acts_as_nested_set
        # declaration.
        def nested_set_scope
          options = {:order => left_column_name}
          if scope_column = acts_as_nested_set_options[:scope]
            options[:conditions] = {scope_column => self[scope_column]}
          end
          Scope.new(self.class.base_class, options)
        end
        
        # on creation, set automatically lft and rgt to the end of the tree
        def set_default_left_and_right
          maxright = nested_set_scope.maximum(right_column_name) || 0
          # adds the new node to the right of all existing nodes
          self[left_column_name] = maxright + 1
          self[right_column_name] = maxright + 2
        end
      
        # Prunes a branch off of the tree, shifting all of the elements on the right
        # back to the left so the counts still work.
        def prune_from_tree
          return if right.nil? || left.nil?
          diff = right - left + 1

          self.class.base_class.transaction do
            nested_set_scope.delete_all("#{left_column_name} > #{left} AND #{right_column_name} < #{right}")
            nested_set_scope.update_all("#{left_column_name} = (#{left_column_name} - #{diff})",
              "#{left_column_name} >= #{right}")
            nested_set_scope.update_all("#{right_column_name} = (#{right_column_name} - #{diff} )",
              "#{right_column_name} >= #{right}" )
          end
        end
        
        def move_to(target, position)
          raise ActiveRecord::ActiveRecordError, "You cannot move a new node" if self.new_record?

          # extent is the width of the tree self and children
          extent = right - left + 1

          # load object if node is not an object
          target = self.class.base_class.find(target) if !(self.class.base_class === target)
          
          unless move_possible?(target)
            raise ActiveRecord::ActiveRecordError, "Impossible move, target node cannot be inside moved tree."
          end
          
          # compute new left/right for self
          case position
          when :child
            if target.left < left
              new_left  = target.left + 1
              new_right = target.left + extent
            else
              new_left  = target.left - extent + 1
              new_right = target.left
            end
          when :left
            if target.left < left
              new_left  = target.left
              new_right = target.left + extent - 1
            else
              new_left  = target.left - extent
              new_right = target.left - 1
            end
          when :right
            if target.right < right
              new_left  = target.right + 1
              new_right = target.right + extent
            else
              new_left  = target.right - extent + 1
              new_right = target.right
            end
          else
            raise ActiveRecord::ActiveRecordError, "Position should be either left, right or child ('#{position}' received)."
          end

          # boundaries of update action
          b_left, b_right = [left, new_left].min, [right, new_right].max

          # Shift value to move self to new position
          shift = new_left - left

          # Shift value to move nodes inside boundaries but not under self_and_children
          updown = (shift > 0) ? -extent : extent

          # change nil to NULL for new parent
          if position == :child
            new_parent = target.id
          else
            new_parent = target[acts_as_nested_set_options[:parent_column]].nil? ? 'NULL' : target[acts_as_nested_set_options[:parent_column]]
          end

          # update and that rules
          self.class.base_class.update_all( "#{left_column_name} = CASE \
                WHEN #{left_column_name} BETWEEN #{left} AND #{right} \
                  THEN #{left_column_name} + #{shift} \
                WHEN #{left_column_name} BETWEEN #{b_left} AND #{b_right} \
                  THEN #{left_column_name} + #{updown} \
                ELSE #{left_column_name} END, \
            #{right_column_name} = CASE \
                WHEN #{right_column_name} BETWEEN #{left} AND #{right} \
                  THEN #{right_column_name} + #{shift} \
                WHEN #{right_column_name} BETWEEN #{b_left} AND #{b_right} \
                  THEN #{right_column_name} + #{updown} \
                ELSE #{right_column_name} END, \
            #{acts_as_nested_set_options[:parent_column]} = CASE \
                WHEN #{self.class.base_class.primary_key} = #{self.id} \
                  THEN #{new_parent} \
                ELSE #{acts_as_nested_set_options[:parent_column]} END",
            acts_as_nested_set_options[:scope] )
          self.reload
        end

      end
      
    end
  end
end
