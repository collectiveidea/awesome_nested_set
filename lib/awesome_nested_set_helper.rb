module CollectiveIdea
  module Acts #:nodoc:

    # This module provides some helpers for the model classes using acts_as_nested_set.
    # It is included by default in all views. If you need to remove it, edit the last line
    # of init.rb.
    #
    module NestedSetHelper
      # Returns options for select.
      # You can exclude some items from the tree.
      # You can pass a block receiving an item and returning the string displayed in the select.
      #
      # == Usage
      # Default is to use the whole tree and to print the first string column of your model.
      # You can tweak this by passing your parameters, or better, pass a block that will receive
      # an item from your nested set tree and that should return the line with the link.
      #
      #   nested_set_options_for_select(Category) {|i| "#{'–' * i.level} #{i.name}" }
      #
      # == Params
      #  * +class_or_item+ - Class name or top level times
      #  * +&block+ - a block that will be used to display: { |item| ... item.name }
      def nested_set_options_for_select(class_or_item)
        class_or_item = class_or_item.roots if class_or_item.is_a?(Class)
        items = Array(class_or_item)
        returning [] do |result|
          items.each {|i| result << i.self_and_descendants.map {|i| [yield(i), i.id] } }
        end
      end  

      # This variation of nested_set_options_for_select takes a mover node and won't show
      # any nodes that the mover can't move to.
      def nested_set_options_for_select_without_impossible_moves(class_or_item, mover)
        class_or_item = class_or_item.roots if class_or_item.is_a?(Class)
        items = Array(class_or_item)
        returning [] do |result|
          items.each {|i| result << i.self_and_descendants.map {|i| [yield(i), i.id] if mover.new_record? || mover.move_possible?(i)}.compact }
        end
      end
    end
  end  
end

