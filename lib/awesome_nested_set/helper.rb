# -*- coding: utf-8 -*-
module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      # This module provides some helpers for the model classes using acts_as_nested_set.
      # It is included by default in all views.
      #
      module Helper
        # Returns options for select.
        # You can exclude some items from the tree.
        # You can pass a block receiving an item and returning the string displayed in the select.
        #
        # == Params
        #  * +class_or_items+ - Class name or top level items
        #  * +mover+ - The item that is being move, used to exclude impossible moves
        #  * +&block+ - a block that will be used to display: { |item| ... item.name }
        #
        # == Usage
        #
        #   <%= f.select :parent_id, nested_set_options(Category, @category) {|i|
        #       "#{'–' * i.level} #{i.name}"
        #     }) %>
        #
        def nested_set_options(class_or_items, mover = nil)
          if class_or_items.is_a? Array
            items = class_or_items.reject { |e| !e.root? }
          else
            class_or_items = class_or_items.roots if class_or_items.respond_to?(:scope)
            items = Array(class_or_items)
          end
          result = []
          items.each do |root|
            result += root.class.associate_parents(root.self_and_descendants).map do |i|
              if mover.nil? || mover.new_record? || mover.move_possible?(i)
                [yield(i), i.primary_id]
              end
            end.compact
          end
          result
        end
      end
    end
  end
end
