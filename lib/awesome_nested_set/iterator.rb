module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      class Iterator
        attr_reader :objects

        def initialize(objects)
          @objects = objects
        end

        def each_with_level
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

        #FIXME this code is not tested, does it even work?
        def sorted_each_with_level(order)
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
              # we are on a new level, did we descend or ascend?
              if path.include?(o.parent_id)
                # remove wrong wrong tailing paths elements
                path.pop while path.last != o.parent_id
              else
                path << o.parent_id
              end
            end
            yield(o, path.length-1) if !o.leaf?
          end
          if !children.empty?
            children.sort_by! &order
            children.each { |c| yield(c, path.length-1) }
          end
        end
      end
    end
  end
end
