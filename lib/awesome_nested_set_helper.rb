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
      # == Examples
      #
      #   nested_set_options_for_select(Category)
      #
      #   # show only a part of the tree, and exclude a category and its subtree
      #   nested_set_options_for_select(selected_category, :exclude => category)
      #
      #   # add a custom string
      #   nested_set_options_for_select(Category, :exclude => category) { |item| "#{'&nbsp;' * item.level}#{item.name} (#{item.url})" }
      #
      # == Params
      #  * +class_or_item+ - Class name or item to start the display with
      #  * +text_column+ - the title column, defaults to the first string column of the model
      #  * +&block+ - a block { |item| ... item.name }
      #    If no block passed, uses {|item| "#{'··' * item.level}#{item[text_column]}"}
      def nested_set_options_for_select(item)
        # find class
        item = item.root if item.is_a?(Class)
        raise 'Not a nested set model !' if !item.respond_to? :acts_as_nested_set_options
        item.self_and_descendants.map {|i| [yield(i), i.id] }
      end  
    end
  end  
end

