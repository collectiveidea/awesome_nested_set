require File.dirname(__FILE__) + '/test_helper'
require 'ruby-debug'

class AwesomeNestedSetTest < Test::Unit::TestCase
  fixtures :categories

  class Default < ActiveRecord::Base
    acts_as_nested_set
  end
  class Scoped < ActiveRecord::Base
    acts_as_nested_set :scope => :organization
  end
  
  def test_left_column_default
    assert_equal 'lft', Default.acts_as_nested_set_options[:left_column]
  end

  def test_right_column_default
    assert_equal 'rgt', Default.acts_as_nested_set_options[:right_column]
  end

  def test_parent_column_default
    assert_equal 'parent_id', Default.acts_as_nested_set_options[:parent_column]
  end

  def test_scope_default
    assert_nil Default.acts_as_nested_set_options[:scope]
  end

  def test_left_column_protected_from_assignment
    assert_raises(ActiveRecord::ActiveRecordError) { Category.new.lft = 1 }
  end
  
  def test_right_column_protected_from_assignment
    assert_raises(ActiveRecord::ActiveRecordError) { Category.new.rgt = 1 }
  end
  
  def test_parent_column_protected_from_assignment
    assert_raises(ActiveRecord::ActiveRecordError) { Category.new.parent_id = 1 }
  end
  
  def test_scoped_appends_id
    assert_equal :organization_id, Scoped.acts_as_nested_set_options[:scope]
  end
  
  def test_roots_class_method
    assert_equal Category.find_all_by_parent_id(nil), Category.roots
  end
  
  def test_root_class_method
    assert_equal categories(:top_level), Category.root
  end
  
  def test_root
    assert_equal categories(:top_level), categories(:child_3).root
  end
  
  def test_parent
    @fixture_cache = {}
    assert_equal categories(:child_2), categories(:child_2_1).parent
  end
  
  def test_self_and_ancestors
    child = categories(:child_2_1)
    self_and_ancestors = [categories(:top_level), categories(:child_2), child]
    assert_equal self_and_ancestors, child.self_and_ancestors
  end

  def test_ancestors
    child = categories(:child_2_1)
    ancestors = [categories(:top_level), categories(:child_2)]
    assert_equal ancestors, child.ancestors
  end
  
  def test_self_and_siblings
    child = categories(:child_2)
    self_and_siblings = [categories(:child_1), child, categories(:child_3)]
    assert_equal self_and_siblings, child.self_and_siblings
  end

  def test_siblings
    child = categories(:child_2)
    siblings = [categories(:child_1), categories(:child_3)]
    assert_equal siblings, child.siblings
  end
  
  def test_level
    assert_equal 0, categories(:top_level).level
    assert_equal 1, categories(:child_1).level
    assert_equal 2, categories(:child_2_1).level
  end
  
  def test_child_count
    assert_equal categories(:top_level).descendants.size, categories(:top_level).children_count
  end
  
  def test_self_and_descendents
    parent = categories(:top_level)
    self_and_descendants = [parent, categories(:child_1), categories(:child_2),
      categories(:child_2_1), categories(:child_3)]
    assert_equal self_and_descendants, parent.self_and_descendants
  end
  
  def test_self_and_descendents
    parent = categories(:top_level)
    descendants = [categories(:child_1), categories(:child_2),
      categories(:child_2_1), categories(:child_3)]
    assert_equal descendants, parent.descendants
  end
  
  def test_children
    category = categories(:top_level)
    category.children.each {|c| assert_equal category.id, c.parent_id }
  end
  
  def test_is_or_is_ancestor_of?
    assert categories(:top_level).is_or_is_ancestor_of?(categories(:child_1))
    assert categories(:top_level).is_or_is_ancestor_of?(categories(:child_2_1))
    assert categories(:child_2).is_or_is_ancestor_of?(categories(:child_2_1))
    assert !categories(:child_2_1).is_or_is_ancestor_of?(categories(:child_2))
    assert !categories(:child_1).is_or_is_ancestor_of?(categories(:child_2))
  end
  
  def test_is_or_is_descendant_of?
    assert categories(:child_1).is_or_is_descendant_of?(categories(:top_level))
    assert categories(:child_2_1).is_or_is_descendant_of?(categories(:top_level))
    assert categories(:child_2_1).is_or_is_descendant_of?(categories(:child_2))
    assert !categories(:child_2).is_or_is_descendant_of?(categories(:child_2_1))
    assert !categories(:child_2).is_or_is_descendant_of?(categories(:child_1))
  end
  
  def test_left_sibling
    assert_equal categories(:child_1), categories(:child_2).left_sibling
    assert_equal categories(:child_2), categories(:child_3).left_sibling
  end

  def test_left_sibling_of_root
    assert_nil categories(:top_level).left_sibling
  end

  def test_left_sibling_without_siblings
    assert_nil categories(:child_2_1).left_sibling
  end

  def test_left_sibling_of_leftmost_node
    assert_nil categories(:child_1).left_sibling
  end

  def test_right_sibling
    assert_equal categories(:child_3), categories(:child_2).right_sibling
    assert_equal categories(:child_2), categories(:child_1).right_sibling
  end

  def test_right_sibling_of_root
    assert_nil categories(:top_level).right_sibling
  end

  def test_right_sibling_without_siblings
    assert_nil categories(:child_2_1).right_sibling
  end

  def test_right_sibling_of_rightmost_node
    assert_nil categories(:child_3).right_sibling
  end
  
  def test_move_left
    categories(:child_2).move_left
    assert_nil categories(:child_2).left_sibling
    assert_equal categories(:child_1), categories(:child_2).right_sibling
    assert Category.valid?
  end

  def test_move_right
    categories(:child_2).move_right
    assert_nil categories(:child_2).right_sibling
    assert_equal categories(:child_3), categories(:child_2).left_sibling
    assert Category.valid?
  end

  def test_move_to_left_of
    categories(:child_3).move_to_left_of(categories(:child_1))
    assert_nil categories(:child_3).left_sibling
    categories(:child_1).reload
    assert_equal categories(:child_1), categories(:child_3).right_sibling
    assert Category.valid?
  end

  def test_move_to_right_of
    categories(:child_1).move_to_right_of(categories(:child_3))
    assert_nil categories(:child_1).right_sibling
    categories(:child_3).reload
    assert_equal categories(:child_3), categories(:child_1).left_sibling
    assert Category.valid?
  end

  def test_move_to_child_of
    categories(:child_1).move_to_child_of(categories(:child_3))
    assert_equal categories(:child_3).id, categories(:child_1).parent_id
    assert Category.valid?
  end

  def test_subtree_move_to_child_of
    assert_equal 4, categories(:child_2).left
    assert_equal 7, categories(:child_2).right
    
    assert_equal 2, categories(:child_1).left
    assert_equal 3, categories(:child_1).right
    
    categories(:child_2).move_to_child_of(categories(:child_1))
      categories(:child_1).reload
    assert_equal categories(:child_1).id, categories(:child_2).parent_id
    
    assert_equal 3, categories(:child_2).left
    assert_equal 6, categories(:child_2).right
    assert_equal 2, categories(:child_1).left
    assert_equal 7, categories(:child_1).right    
  end
  
  def test_slightly_difficult_move_to_child_of
    assert_equal 11, categories(:top_level_2).left
    assert_equal 12, categories(:top_level_2).right
    
    # create a new top-level node and move single-node top-level tree inside it.
    new_top = Category.create(:name => 'New Top')
    assert_equal 13, new_top.left
    assert_equal 14, new_top.right
    
    categories(:top_level_2).move_to_child_of(new_top)
      new_top.reload
    
    assert_equal new_top.id, categories(:top_level_2).parent_id
    
    assert_equal 12, categories(:top_level_2).left
    assert_equal 13, categories(:top_level_2).right
    assert_equal 11, new_top.left
    assert_equal 14, new_top.right    
  end
  
  def test_difficult_move_to_child_of
    assert_equal 1, categories(:top_level).left
    assert_equal 10, categories(:top_level).right
    assert_equal 5, categories(:child_2_1).left
    assert_equal 6, categories(:child_2_1).right
    
    # create a new top-level node and move an entire top-level tree inside it.
    new_top = Category.create(:name => 'New Top')
    categories(:top_level).move_to_child_of(new_top)
      new_top.reload
      categories(:top_level).reload
      categories(:child_2_1).reload
      
    assert_equal new_top.id, categories(:top_level).parent_id
    
    assert_equal 4, categories(:top_level).left
    assert_equal 13, categories(:top_level).right
    assert_equal 8, categories(:child_2_1).left
    assert_equal 9, categories(:child_2_1).right    
  end
end
