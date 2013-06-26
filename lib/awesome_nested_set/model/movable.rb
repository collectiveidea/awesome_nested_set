require 'awesome_nested_set/move'

module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      module Model
        module Movable

          def move_possible?(target)
            self != target && # Can't target self
              same_scope?(target) && # can't be in different scopes
              # !(left..right).include?(target.left..target.right) # this needs tested more
              # detect impossible move
              !((left <= target.left && right >= target.left) or (left <= target.right && right >= target.right))
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

            left_neighbor = find_left_neighbor(parent, order_attribute, ascending)
            self.move_to_child_of(parent)

            return unless parent.has_multiple_children?

            if left_neighbor
              self.move_to_right_of(left_neighbor)
            else # Self is the left most node.
              self.move_to_left_of(parent.children[0])
            end
          end

          # Find the node immediately to the left of this node.
          def find_left_neighbor(parent, order_attribute, ascending)
            left = nil
            parent.children.each do |n|
              if ascending
                left = n if n.send(order_attribute) < self.send(order_attribute)
              else
                left = n if n.send(order_attribute) > self.send(order_attribute)
              end
            end
            left
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

          protected

          def move_to_new_parent
            if @move_to_new_parent_id.nil?
              move_to_root
            elsif @move_to_new_parent_id
              move_to_child_of(@move_to_new_parent_id)
            end
          end
        end
      end
    end
  end
end
