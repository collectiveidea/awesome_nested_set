module CollectiveIdea
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      def self.included(base)
        base.extend(SingletonMethods)
      end

      # better_nested_set ehances the core nested_set tree functionality provided in ruby_on_rails.
      #
      # awesome_nested_set goes further, first with a major refactoring
      # Features:
      # * almost API-compatible (some broken bits had to be changed)
      # * allow it to work with a tree that spans across STI classes 
      # * removed roots instance method, which was an impossible method.
      #
      # This acts provides Nested Set functionality. Nested Set is a smart way to implement
      # an _ordered_ tree, with the added feature that you can select the children and all of their
      # descendants with a single query. The drawback is that insertion or move need some complex
      # sql queries. But everything is done here by this module!
      #
      # Nested sets are appropriate each time you want either an orderd tree (menus,
      # commercial categories) or an efficient way of querying big trees (threaded posts).
      #
      # == API
      # Methods names are aligned on Tree's ones as much as possible, to make replacment from one
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
      # You can use:
      # * move_to_child_of
      # * move_to_right_of
      # * move_to_left_of
      # and pass them an id or an object.
      #
      # Other methods added by this mixin are:
      # * +root+ - root item of the tree (the one that has a nil parent; should have left_column = 1 too)
      # * +roots+ - root items, in case of multiple roots (the ones that have a nil parent)
      # * +level+ - number indicating the level, a root being level 0
      # * +ancestors+ - array of all parents, with root as first item
      # * +self_and_ancestors+ - array of all parents and self
      # * +siblings+ - array of all siblings, that are the items sharing the same parent and level
      # * +self_and_siblings+ - array of itself and all siblings
      # * +children_count+ - count of all immediate children
      # * +children+ - array of all immediate childrens
      # * +all_children+ - array of all children and nested children
      # * +full_set+ - array of itself and all children and nested children
      #
      # These should not be useful, except if you want to write direct SQL:
      # * +left_column_name+ - name of the left column passed on the declaration line
      # * +right_column_name+ - name of the right column passed on the declaration line
      # * +parent_column_name+ - name of the parent column passed on the declaration line
      #
      # recommandations:
      # Don't name your left and right columns 'left' and 'right': these names are reserved on most of dbs.
      # Usage is to name them 'lft' and 'rgt' for instance.
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
        def acts_as_nested_set(options = {})
          options = {
            :parent_column => 'parent_id',
            :left_column => 'lft',
            :right_column => 'rgt'
          }.merge(options)
          
          if options[:scope].is_a?(Symbol) && options[:scope].to_s !~ /_id$/
            options[:scope] = "#{options[:scope]}_id".intern
          end

          write_inheritable_attribute(:acts_as_nested_set_options, options)
          class_inheritable_reader :acts_as_nested_set_options

          # no bulk assignment
          attr_protected  acts_as_nested_set_options[:left_column].intern,
                          acts_as_nested_set_options[:right_column].intern,
                          acts_as_nested_set_options[:parent_column].intern
          # no assignment to structure fields
          module_eval <<-"end_eval", __FILE__, __LINE__
            def #{acts_as_nested_set_options[:left_column]}=(x)
              raise ActiveRecord::ActiveRecordError, "Unauthorized assignment to #{acts_as_nested_set_options[:left_column]}: it's an internal field handled by acts_as_nested_set code, use move_to_* methods instead."
            end
            def #{acts_as_nested_set_options[:right_column]}=(x)
              raise ActiveRecord::ActiveRecordError, "Unauthorized assignment to #{acts_as_nested_set_options[:right_column]}: it's an internal field handled by acts_as_nested_set code, use move_to_* methods instead."
            end
            def #{acts_as_nested_set_options[:parent_column]}=(x)
              raise ActiveRecord::ActiveRecordError, "Unauthorized assignment to #{acts_as_nested_set_options[:parent_column]}: it's an internal field handled by acts_as_nested_set code, use move_to_* methods instead."
            end
          end_eval

          include InstanceMethods
          include Comparable
          include Helpers
          extend Helpers
          extend ClassMethods
        end
        
      end
      
      module ClassMethods
        
        def roots(multiplicity = :all, *args)
          with_scope(:find => {
              :conditions => {acts_as_nested_set_options[:parent_column] => nil},
              :order => acts_as_nested_set_options[:left_column] }) do
            find(multiplicity, *args)
          end
        end
        
        # Returns the first root
        def root
          roots(:first)
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
          scope_string = "#{quoted_scope_column_name+', ' if acts_as_nested_set_options[:scope]}"
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
            find(:all, :conditions => ["parent_id = ? #{scope.call(node)}", node], :order => "#{left_column_name}, #{right_column_name}").each{|n| set_left_and_rights.call(n) }
            # set right
            node[right_column_name] = indices[scope.call(node)] += 1    
            node.save!    
          end
                              
          # Find root node(s)
          root_nodes = find(:all, :conditions => "parent_id IS NULL", :order => "#{left_column_name}, #{right_column_name}").each do |root_node|
            # setup index for this scope
            indices[scope.call(root_node)] ||= 0
            set_left_and_rights.call(root_node)
          end
        end
        
        def scope_for(node)
          node.send(:scope_column_name)
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
      
      # Mixed into both classes and instances
      module Helpers
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
      end

      module InstanceMethods
        
        def quoted_left_column_name
          self.class.connection.quote_column_name(left_column_name)
        end
        
        def quoted_right_column_name
          self.class.connection.quote_column_name(right_column_name)
        end
        
        def quoted_parent_column_name
          self.class.connection.quote_column_name(parent_column_name)
        end
        
        def parent_id
          self[parent_column_name]
        end
        
        def left
          self[left_column_name]
        end
        
        def right
          self[right_column_name]
        end

        # Returns true if this is a root node.
        def root?
          parent_id.nil? && left == 1
        end

        # Returns true is this is a child node
        def child?
          !parent_id.nil? && left > 1
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
          self_and_ancestors(:first)
        end

        # Returns the parent
        def parent
          self.class.base_class.find_by_id(parent_id) if parent_id
        end

        # Returns the array of all parents and self
        def self_and_ancestors(multiplicity = :all, *args)
          with_nested_set_scope do
            with_find_scope(:conditions => "#{left_column_name} <= #{left} AND #{right_column_name} >= #{right}") { self.class.base_class.find(multiplicity, *args) }
          end
        end

        # Returns an array of all parents
        def ancestors(*args)
          without_self { self_and_ancestors(*args) }
        end

        # Returns the array of all children of the parent, included self
        def self_and_siblings(multiplicity = :all, *args)
          with_nested_set_scope do
            scope = if parent_id.nil?
              {self.class.base_class.primary_key => self}
            else
              {parent_column_name => parent_id}
            end
            with_find_scope(:conditions => scope) { self.class.base_class.find(multiplicity, *args) }
          end
        end

        # Returns the array of all children of the parent, except self
        def siblings(*args)
          without_self { self_and_siblings(*args) }
        end

        # Returns the level of this object in the tree
        # root level is 0
        def level
          if parent_id.nil?
            0 
          else
            with_nested_set_scope do
              self.class.base_class.count(:conditions => "(#{left_column_name} < #{left} AND #{right_column_name} > #{right})")
            end
          end
        end

        # Returns the number of nested children of this object.
        # FIXME: rename to descendants.count
        def children_count
          (right - left - 1) / 2
        end

        # Returns a set of itself and all of its nested children
        def self_and_descendants(multiplicity = :all, *args)
          with_nested_set_scope do
            with_find_scope(:conditions => "#{left_column_name} >= #{left}
                AND #{right_column_name} <= #{right}"
            ) { self.class.base_class.find(multiplicity, *args) }
          end
        end

        # Returns a set of all of its children and nested children
        def descendants(*args)
          without_self { self_and_descendants(*args) }
        end

        # Returns a set of only this entry's immediate children
        def children(multiplicity = :all, *args)
          with_nested_set_scope do
            with_find_scope(:conditions => {parent_column_name => self}) do
              self.class.base_class.find(multiplicity, *args)
            end
          end
        end

        def is_or_is_descendant_of?(other)
          other.left <= self.left && self.left < other.right
        end

        def is_or_is_ancestor_of?(other)
          self.left <= other.left && other.left < self.right
        end

        # Find the first sibling to the right
        def left_sibling
          if parent_id.nil?
            nil
          else
            with_nested_set_scope do
              self.class.base_class.find(:first, :conditions => "#{left_column_name} < #{left}
                  AND #{parent_column_name} = #{parent_id}",
                :order => "#{left_column_name} DESC")
            end
          end
        end

        # Find the first sibling to the right
        def right_sibling
          if parent_id.nil?
            nil
          else
            with_nested_set_scope do
              self.class.base_class.find(:first, :conditions => "#{left_column_name} > #{left}
                  AND #{parent_column_name} = #{parent_id}"
              )
            end
          end
        end

        # Shorthand method for finding the left sibling and moving to the left of it.
        def move_left
          self.move_to_left_of(self.left_sibling)
        end

        # Shorthand method for finding the right sibling and moving to the right of it.
        def move_right
          self.move_to_right_of(self.right_sibling)
        end

        # Move the node to the left of another node (you can pass id only)
        def move_to_left_of(node)
            self.move_to node, :left
        end

        # Move the node to the left of another node (you can pass id only)
        def move_to_right_of(node)
            self.move_to node, :right
        end

        # Move the node to the child of another node (you can pass id only)
        def move_to_child_of(node)
            self.move_to node, :child
        end
        
        def move_possible?(target)
          # Can't target self
          self != target && 
          # can't be in different scopes
          (!acts_as_nested_set_options[:scope] || self.send(scope_column_name) == target.send(scope_column_name)) && 
          # detect impossible move
          !((left <= target.left && target.left <= right) or (left <= target.right && target.right <= right))
        end
        
        def to_text
          returning "" do |string|
            self.recurse do |node, block|
              string << "#{'*'*(node.level+1)} #{node.id} #{node.name} (#{node.parent_id}, #{node.left}, #{node.right})\n"
              block.call
            end
          end
        end

      protected
      
        def without_self
          with_find_scope(:conditions => ["#{self.class.base_class.primary_key} != ?", self]) do
            yield
          end
        end
        
        def with_find_scope(scope)
          self.class.base_class.send(:with_scope, :find => scope) { yield }
        end
      
        def with_nested_set_scope
          scope = {:order => left_column_name}
          if scope_column = acts_as_nested_set_options[:scope]
            scope[:conditions] = {scope_column => self[scope_column]}
          end
          self.class.base_class.send(:with_scope, :find => scope) { yield }
        end
      
        # on creation, set automatically lft and rgt to the end of the tree
        def before_create
          maxright = with_nested_set_scope { self.class.base_class.maximum(right_column_name) } || 0
          # adds the new node to the right of all existing nodes
          self[left_column_name] = maxright + 1
          self[right_column_name] = maxright + 2
        end
      
        # Prunes a branch off of the tree, shifting all of the elements on the right
        # back to the left so the counts still work.
        def before_destroy
          return if right.nil? || left.nil?
          diff = right - left + 1

          with_nested_set_scope do
            self.class.base_class.transaction do
              self.class.base_class.delete_all("#{left_column_name} > #{left} AND #{right_column_name} < #{right}")
              self.class.base_class.update_all("#{left_column_name} = (#{left_column_name} - #{diff})",
                "#{left_column_name} >= #{right}")
              self.class.base_class.update_all("#{right_column_name} = (#{right_column_name} - #{diff} )",
                "#{right_column_name} >= #{right}" )
            end
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
