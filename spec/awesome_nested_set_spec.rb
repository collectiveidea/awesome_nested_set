require 'spec_helper'

# these were copied from Test::Unit, so are named poorly.
# Also, we're use Test::Unit's assertions until someone takes the time to remove them.
# Patches welcome!
require 'test/unit/assertions'
include Test::Unit::Assertions

describe "AwesomeNestedSet" do
  before(:all) do
    self.class.fixtures :categories, :departments, :notes
  end
  
  describe "defaults" do
    it "should have left_column_default" do
      assert_equal 'lft', Default.acts_as_nested_set_options[:left_column]
    end

    it "should have right_column_default" do
      assert_equal 'rgt', Default.acts_as_nested_set_options[:right_column]
    end

    it "should have parent_column_default" do
      assert_equal 'parent_id', Default.acts_as_nested_set_options[:parent_column]
    end

    it "should have scope_default" do
      assert_nil Default.acts_as_nested_set_options[:scope]
    end

    it "should have left_column_name" do
      assert_equal 'lft', Default.left_column_name
      assert_equal 'lft', Default.new.left_column_name
      assert_equal 'red', RenamedColumns.left_column_name
      assert_equal 'red', RenamedColumns.new.left_column_name
    end

    it "should have right_column_name" do
      assert_equal 'rgt', Default.right_column_name
      assert_equal 'rgt', Default.new.right_column_name
      assert_equal 'black', RenamedColumns.right_column_name
      assert_equal 'black', RenamedColumns.new.right_column_name
    end

    it "should have parent_column_name" do
      assert_equal 'parent_id', Default.parent_column_name
      assert_equal 'parent_id', Default.new.parent_column_name
      assert_equal 'mother_id', RenamedColumns.parent_column_name
      assert_equal 'mother_id', RenamedColumns.new.parent_column_name
    end
  end

  it "creation_with_altered_column_names" do
    assert_nothing_raised do 
      RenamedColumns.create!()
    end
  end

  it "quoted_left_column_name" do
    quoted = Default.connection.quote_column_name('lft')
    assert_equal quoted, Default.quoted_left_column_name
    assert_equal quoted, Default.new.quoted_left_column_name
  end

  it "quoted_right_column_name" do
    quoted = Default.connection.quote_column_name('rgt')
    assert_equal quoted, Default.quoted_right_column_name
    assert_equal quoted, Default.new.quoted_right_column_name
  end

  it "left_column_protected_from_assignment" do
    assert_raises(ActiveRecord::ActiveRecordError) { Category.new.lft = 1 }
  end

  it "right_column_protected_from_assignment" do
    assert_raises(ActiveRecord::ActiveRecordError) { Category.new.rgt = 1 }
  end

  it "colums_protected_on_initialize" do
    c = Category.new(:lft => 1, :rgt => 2)
    assert_nil c.lft
    assert_nil c.rgt
  end

  it "scoped_appends_id" do
    assert_equal :organization_id, ScopedCategory.acts_as_nested_set_options[:scope]
  end

  it "roots_class_method" do
    assert_equal Category.find_all_by_parent_id(nil), Category.roots
  end

  it "root_class_method" do
    assert_equal categories(:top_level), Category.root
  end

  it "root" do
    assert_equal categories(:top_level), categories(:child_3).root
  end

  it "root?" do
    assert categories(:top_level).root?
    assert categories(:top_level_2).root?
  end

  it "leaves_class_method" do
    assert_equal Category.find(:all, :conditions => "#{Category.right_column_name} - #{Category.left_column_name} = 1"), Category.leaves
    assert_equal Category.leaves.count, 4
    assert (Category.leaves.include? categories(:child_1))
    assert (Category.leaves.include? categories(:child_2_1))
    assert (Category.leaves.include? categories(:child_3))
    assert (Category.leaves.include? categories(:top_level_2))
  end

  it "leaf" do
    assert categories(:child_1).leaf?
    assert categories(:child_2_1).leaf?
    assert categories(:child_3).leaf?
    assert categories(:top_level_2).leaf?

    assert !categories(:top_level).leaf?
    assert !categories(:child_2).leaf?
    assert !Category.new.leaf?
  end


  it "parent" do
    assert_equal categories(:child_2), categories(:child_2_1).parent
  end

  it "self_and_ancestors" do
    child = categories(:child_2_1)
    self_and_ancestors = [categories(:top_level), categories(:child_2), child]
    assert_equal self_and_ancestors, child.self_and_ancestors
  end

  it "ancestors" do
    child = categories(:child_2_1)
    ancestors = [categories(:top_level), categories(:child_2)]
    assert_equal ancestors, child.ancestors
  end

  it "self_and_siblings" do
    child = categories(:child_2)
    self_and_siblings = [categories(:child_1), child, categories(:child_3)]
    assert_equal self_and_siblings, child.self_and_siblings
    assert_nothing_raised do
      tops = [categories(:top_level), categories(:top_level_2)]
      assert_equal tops, categories(:top_level).self_and_siblings
    end
  end

  it "siblings" do
    child = categories(:child_2)
    siblings = [categories(:child_1), categories(:child_3)]
    assert_equal siblings, child.siblings
  end

  it "leaves" do
    leaves = [categories(:child_1), categories(:child_2_1), categories(:child_3)]
    assert_equal categories(:top_level).leaves, leaves
  end

  it "level" do
    assert_equal 0, categories(:top_level).level
    assert_equal 1, categories(:child_1).level
    assert_equal 2, categories(:child_2_1).level
  end

  it "has_children?" do
    assert categories(:child_2_1).children.empty?
    assert !categories(:child_2).children.empty?
    assert !categories(:top_level).children.empty?
  end

  it "self_and_descendents" do
    parent = categories(:top_level)
    self_and_descendants = [parent, categories(:child_1), categories(:child_2),
      categories(:child_2_1), categories(:child_3)]
    assert_equal self_and_descendants, parent.self_and_descendants
    assert_equal self_and_descendants.count, parent.self_and_descendants.count
  end

  it "descendents" do
    lawyers = Category.create!(:name => "lawyers")
    us = Category.create!(:name => "United States")
    us.move_to_child_of(lawyers)
    patent = Category.create!(:name => "Patent Law")
    patent.move_to_child_of(us)
    lawyers.reload

    assert_equal 1, lawyers.children.size
    assert_equal 1, us.children.size
    assert_equal 2, lawyers.descendants.size
  end

  it "self_and_descendents" do
    parent = categories(:top_level)
    descendants = [categories(:child_1), categories(:child_2),
      categories(:child_2_1), categories(:child_3)]
    assert_equal descendants, parent.descendants
  end

  it "children" do
    category = categories(:top_level)
    category.children.each {|c| assert_equal category.id, c.parent_id }
  end

  it "order_of_children" do
    categories(:child_2).move_left
    assert_equal categories(:child_2), categories(:top_level).children[0]
    assert_equal categories(:child_1), categories(:top_level).children[1]
    assert_equal categories(:child_3), categories(:top_level).children[2]
  end

  it "is_or_is_ancestor_of?" do
    assert categories(:top_level).is_or_is_ancestor_of?(categories(:child_1))
    assert categories(:top_level).is_or_is_ancestor_of?(categories(:child_2_1))
    assert categories(:child_2).is_or_is_ancestor_of?(categories(:child_2_1))
    assert !categories(:child_2_1).is_or_is_ancestor_of?(categories(:child_2))
    assert !categories(:child_1).is_or_is_ancestor_of?(categories(:child_2))
    assert categories(:child_1).is_or_is_ancestor_of?(categories(:child_1))
  end

  it "is_ancestor_of?" do
    assert categories(:top_level).is_ancestor_of?(categories(:child_1))
    assert categories(:top_level).is_ancestor_of?(categories(:child_2_1))
    assert categories(:child_2).is_ancestor_of?(categories(:child_2_1))
    assert !categories(:child_2_1).is_ancestor_of?(categories(:child_2))
    assert !categories(:child_1).is_ancestor_of?(categories(:child_2))
    assert !categories(:child_1).is_ancestor_of?(categories(:child_1))
  end

  it "is_or_is_ancestor_of_with_scope" do
    root = ScopedCategory.root
    child = root.children.first
    assert root.is_or_is_ancestor_of?(child)
    child.update_attribute :organization_id, 'different'
    assert !root.is_or_is_ancestor_of?(child)
  end

  it "is_or_is_descendant_of?" do
    assert categories(:child_1).is_or_is_descendant_of?(categories(:top_level))
    assert categories(:child_2_1).is_or_is_descendant_of?(categories(:top_level))
    assert categories(:child_2_1).is_or_is_descendant_of?(categories(:child_2))
    assert !categories(:child_2).is_or_is_descendant_of?(categories(:child_2_1))
    assert !categories(:child_2).is_or_is_descendant_of?(categories(:child_1))
    assert categories(:child_1).is_or_is_descendant_of?(categories(:child_1))
  end

  it "is_descendant_of?" do
    assert categories(:child_1).is_descendant_of?(categories(:top_level))
    assert categories(:child_2_1).is_descendant_of?(categories(:top_level))
    assert categories(:child_2_1).is_descendant_of?(categories(:child_2))
    assert !categories(:child_2).is_descendant_of?(categories(:child_2_1))
    assert !categories(:child_2).is_descendant_of?(categories(:child_1))
    assert !categories(:child_1).is_descendant_of?(categories(:child_1))
  end

  it "is_or_is_descendant_of_with_scope" do
    root = ScopedCategory.root
    child = root.children.first
    assert child.is_or_is_descendant_of?(root)
    child.update_attribute :organization_id, 'different'
    assert !child.is_or_is_descendant_of?(root)
  end

  it "same_scope?" do
    root = ScopedCategory.root
    child = root.children.first
    assert child.same_scope?(root)
    child.update_attribute :organization_id, 'different'
    assert !child.same_scope?(root)
  end

  it "left_sibling" do
    assert_equal categories(:child_1), categories(:child_2).left_sibling
    assert_equal categories(:child_2), categories(:child_3).left_sibling
  end

  it "left_sibling_of_root" do
    assert_nil categories(:top_level).left_sibling
  end

  it "left_sibling_without_siblings" do
    assert_nil categories(:child_2_1).left_sibling
  end

  it "left_sibling_of_leftmost_node" do
    assert_nil categories(:child_1).left_sibling
  end

  it "right_sibling" do
    assert_equal categories(:child_3), categories(:child_2).right_sibling
    assert_equal categories(:child_2), categories(:child_1).right_sibling
  end

  it "right_sibling_of_root" do
    assert_equal categories(:top_level_2), categories(:top_level).right_sibling
    assert_nil categories(:top_level_2).right_sibling
  end

  it "right_sibling_without_siblings" do
    assert_nil categories(:child_2_1).right_sibling
  end

  it "right_sibling_of_rightmost_node" do
    assert_nil categories(:child_3).right_sibling
  end

  it "move_left" do
    categories(:child_2).move_left
    assert_nil categories(:child_2).left_sibling
    assert_equal categories(:child_1), categories(:child_2).right_sibling
    assert Category.valid?
  end

  it "move_right" do
    categories(:child_2).move_right
    assert_nil categories(:child_2).right_sibling
    assert_equal categories(:child_3), categories(:child_2).left_sibling
    assert Category.valid?
  end

  it "move_to_left_of" do
    categories(:child_3).move_to_left_of(categories(:child_1))
    assert_nil categories(:child_3).left_sibling
    assert_equal categories(:child_1), categories(:child_3).right_sibling
    assert Category.valid?
  end

  it "move_to_right_of" do
    categories(:child_1).move_to_right_of(categories(:child_3))
    assert_nil categories(:child_1).right_sibling
    assert_equal categories(:child_3), categories(:child_1).left_sibling
    assert Category.valid?
  end

  it "move_to_root" do
    categories(:child_2).move_to_root
    assert_nil categories(:child_2).parent
    assert_equal 0, categories(:child_2).level
    assert_equal 1, categories(:child_2_1).level
    assert_equal 1, categories(:child_2).left
    assert_equal 4, categories(:child_2).right
    assert Category.valid?
  end

  it "move_to_child_of" do
    categories(:child_1).move_to_child_of(categories(:child_3))
    assert_equal categories(:child_3).id, categories(:child_1).parent_id
    assert Category.valid?
  end

  it "move_to_child_of_appends_to_end" do
    child = Category.create! :name => 'New Child'
    child.move_to_child_of categories(:top_level)
    assert_equal child, categories(:top_level).children.last
  end

  it "subtree_move_to_child_of" do
    assert_equal 4, categories(:child_2).left
    assert_equal 7, categories(:child_2).right

    assert_equal 2, categories(:child_1).left
    assert_equal 3, categories(:child_1).right

    categories(:child_2).move_to_child_of(categories(:child_1))
    assert Category.valid?
    assert_equal categories(:child_1).id, categories(:child_2).parent_id

    assert_equal 3, categories(:child_2).left
    assert_equal 6, categories(:child_2).right
    assert_equal 2, categories(:child_1).left
    assert_equal 7, categories(:child_1).right    
  end

  it "slightly_difficult_move_to_child_of" do
    assert_equal 11, categories(:top_level_2).left
    assert_equal 12, categories(:top_level_2).right

    # create a new top-level node and move single-node top-level tree inside it.
    new_top = Category.create(:name => 'New Top')
    assert_equal 13, new_top.left
    assert_equal 14, new_top.right

    categories(:top_level_2).move_to_child_of(new_top)

    assert Category.valid?
    assert_equal new_top.id, categories(:top_level_2).parent_id

    assert_equal 12, categories(:top_level_2).left
    assert_equal 13, categories(:top_level_2).right
    assert_equal 11, new_top.left
    assert_equal 14, new_top.right    
  end

  it "difficult_move_to_child_of" do
    assert_equal 1, categories(:top_level).left
    assert_equal 10, categories(:top_level).right
    assert_equal 5, categories(:child_2_1).left
    assert_equal 6, categories(:child_2_1).right

    # create a new top-level node and move an entire top-level tree inside it.
    new_top = Category.create(:name => 'New Top')
    categories(:top_level).move_to_child_of(new_top)
    categories(:child_2_1).reload
    assert Category.valid?  
    assert_equal new_top.id, categories(:top_level).parent_id

    assert_equal 4, categories(:top_level).left
    assert_equal 13, categories(:top_level).right
    assert_equal 8, categories(:child_2_1).left
    assert_equal 9, categories(:child_2_1).right    
  end

  #rebuild swaps the position of the 2 children when added using move_to_child twice onto same parent
  it "move_to_child_more_than_once_per_parent_rebuild" do
    root1 = Category.create(:name => 'Root1')
    root2 = Category.create(:name => 'Root2')
    root3 = Category.create(:name => 'Root3')

    root2.move_to_child_of root1
    root3.move_to_child_of root1

    output = Category.roots.last.to_text
    Category.update_all('lft = null, rgt = null')
    Category.rebuild!

    assert_equal Category.roots.last.to_text, output
  end

  # doing move_to_child twice onto same parent from the furthest right first
  it "move_to_child_more_than_once_per_parent_outside_in" do
    node1 = Category.create(:name => 'Node-1')
    node2 = Category.create(:name => 'Node-2')
    node3 = Category.create(:name => 'Node-3')

    node2.move_to_child_of node1
    node3.move_to_child_of node1

    output = Category.roots.last.to_text
    Category.update_all('lft = null, rgt = null')
    Category.rebuild!

    assert_equal Category.roots.last.to_text, output
  end


  it "valid_with_null_lefts" do
    assert Category.valid?
    Category.update_all('lft = null')
    assert !Category.valid?
  end

  it "valid_with_null_rights" do
    assert Category.valid?
    Category.update_all('rgt = null')
    assert !Category.valid?
  end

  it "valid_with_missing_intermediate_node" do
    # Even though child_2_1 will still exist, it is a sign of a sloppy delete, not an invalid tree.
    assert Category.valid?
    Category.delete(categories(:child_2).id)
    assert Category.valid?
  end

  it "valid_with_overlapping_and_rights" do
    assert Category.valid?
    categories(:top_level_2)['lft'] = 0
    categories(:top_level_2).save
    assert !Category.valid?
  end

  it "rebuild" do
    assert Category.valid?
    before_text = Category.root.to_text
    Category.update_all('lft = null, rgt = null')
    Category.rebuild!
    assert Category.valid?
    assert_equal before_text, Category.root.to_text
  end

  it "move_possible_for_sibling" do
    assert categories(:child_2).move_possible?(categories(:child_1))
  end

  it "move_not_possible_to_self" do
    assert !categories(:top_level).move_possible?(categories(:top_level))
  end

  it "move_not_possible_to_parent" do
    categories(:top_level).descendants.each do |descendant|
      assert !categories(:top_level).move_possible?(descendant)
      assert descendant.move_possible?(categories(:top_level))
    end
  end

  it "is_or_is_ancestor_of?" do
    [:child_1, :child_2, :child_2_1, :child_3].each do |c|
      assert categories(:top_level).is_or_is_ancestor_of?(categories(c))
    end
    assert !categories(:top_level).is_or_is_ancestor_of?(categories(:top_level_2))
  end

  it "left_and_rights_valid_with_blank_left" do
    assert Category.left_and_rights_valid?
    categories(:child_2)[:lft] = nil
    categories(:child_2).save(:validate => false)
    assert !Category.left_and_rights_valid?
  end

  it "left_and_rights_valid_with_blank_right" do
    assert Category.left_and_rights_valid?
    categories(:child_2)[:rgt] = nil
    categories(:child_2).save(:validate => false)
    assert !Category.left_and_rights_valid?
  end

  it "left_and_rights_valid_with_equal" do
    assert Category.left_and_rights_valid?
    categories(:top_level_2)[:lft] = categories(:top_level_2)[:rgt]
    categories(:top_level_2).save(:validate => false)
    assert !Category.left_and_rights_valid?
  end

  it "left_and_rights_valid_with_left_equal_to_parent" do
    assert Category.left_and_rights_valid?
    categories(:child_2)[:lft] = categories(:top_level)[:lft]
    categories(:child_2).save(:validate => false)
    assert !Category.left_and_rights_valid?
  end

  it "left_and_rights_valid_with_right_equal_to_parent" do
    assert Category.left_and_rights_valid?
    categories(:child_2)[:rgt] = categories(:top_level)[:rgt]
    categories(:child_2).save(:validate => false)
    assert !Category.left_and_rights_valid?
  end

  it "moving_dirty_objects_doesnt_invalidate_tree" do
    r1 = Category.create
    r2 = Category.create
    r3 = Category.create
    r4 = Category.create
    nodes = [r1, r2, r3, r4]

    r2.move_to_child_of(r1)
    assert Category.valid?

    r3.move_to_child_of(r1)
    assert Category.valid?

    r4.move_to_child_of(r2)
    assert Category.valid?
  end

  it "multi_scoped_no_duplicates_for_columns?" do
    assert_nothing_raised do
      Note.no_duplicates_for_columns?
    end
  end

  it "multi_scoped_all_roots_valid?" do
    assert_nothing_raised do
      Note.all_roots_valid?
    end
  end

  it "multi_scoped" do
    note1 = Note.create!(:body => "A", :notable_id => 2, :notable_type => 'Category')
    note2 = Note.create!(:body => "B", :notable_id => 2, :notable_type => 'Category')
    note3 = Note.create!(:body => "C", :notable_id => 2, :notable_type => 'Default')

    assert_equal [note1, note2], note1.self_and_siblings
    assert_equal [note3], note3.self_and_siblings
  end

  it "multi_scoped_rebuild" do
    root = Note.create!(:body => "A", :notable_id => 3, :notable_type => 'Category')
    child1 = Note.create!(:body => "B", :notable_id => 3, :notable_type => 'Category')
    child2 = Note.create!(:body => "C", :notable_id => 3, :notable_type => 'Category')

    child1.move_to_child_of root
    child2.move_to_child_of root

    Note.update_all('lft = null, rgt = null')
    Note.rebuild!

    assert_equal Note.roots.find_by_body('A'), root
    assert_equal [child1, child2], Note.roots.find_by_body('A').children
  end

  it "same_scope_with_multi_scopes" do
    assert_nothing_raised do
      notes(:scope1).same_scope?(notes(:child_1))
    end
    assert notes(:scope1).same_scope?(notes(:child_1))
    assert notes(:child_1).same_scope?(notes(:scope1))
    assert !notes(:scope1).same_scope?(notes(:scope2))
  end

  it "quoting_of_multi_scope_column_names" do
    assert_equal ["\"notable_id\"", "\"notable_type\""], Note.quoted_scope_column_names
  end

  it "equal_in_same_scope" do
    assert_equal notes(:scope1), notes(:scope1)
    assert_not_equal notes(:scope1), notes(:child_1)
  end

  it "equal_in_different_scopes" do
    notes(:scope1).should_not == notes(:scope2)
  end

  it "delete_does_not_invalidate" do
    Category.acts_as_nested_set_options[:dependent] = :delete
    categories(:child_2).destroy
    assert Category.valid?
  end

  it "destroy_does_not_invalidate" do
    Category.acts_as_nested_set_options[:dependent] = :destroy
    categories(:child_2).destroy
    assert Category.valid?
  end

  it "destroy_multiple_times_does_not_invalidate" do
    Category.acts_as_nested_set_options[:dependent] = :destroy
    categories(:child_2).destroy
    categories(:child_2).destroy
    assert Category.valid?
  end

  it "assigning_parent_id_on_create" do
    category = Category.create!(:name => "Child", :parent_id => categories(:child_2).id)
    assert_equal categories(:child_2), category.parent
    assert_equal categories(:child_2).id, category.parent_id
    assert_not_nil category.left
    assert_not_nil category.right
    assert Category.valid?
  end

  it "assigning_parent_on_create" do
    category = Category.create!(:name => "Child", :parent => categories(:child_2))
    assert_equal categories(:child_2), category.parent
    assert_equal categories(:child_2).id, category.parent_id
    assert_not_nil category.left
    assert_not_nil category.right
    assert Category.valid?
  end

  it "assigning_parent_id_to_nil_on_create" do
    category = Category.create!(:name => "New Root", :parent_id => nil)
    assert_nil category.parent
    assert_nil category.parent_id
    assert_not_nil category.left
    assert_not_nil category.right
    assert Category.valid?
  end

  it "assigning_parent_id_on_update" do
    category = categories(:child_2_1)
    category.parent_id = categories(:child_3).id
    category.save
    category.reload
    categories(:child_3).reload
    assert_equal categories(:child_3), category.parent
    assert_equal categories(:child_3).id, category.parent_id
    assert Category.valid?
  end

  it "assigning_parent_on_update" do
    category = categories(:child_2_1)
    category.parent = categories(:child_3)
    category.save
    category.reload
    categories(:child_3).reload
    assert_equal categories(:child_3), category.parent
    assert_equal categories(:child_3).id, category.parent_id
    assert Category.valid?
  end

  it "assigning_parent_id_to_nil_on_update" do
    category = categories(:child_2_1)
    category.parent_id = nil
    category.save
    assert_nil category.parent
    assert_nil category.parent_id
    assert Category.valid?
  end

  it "creating_child_from_parent" do
    category = categories(:child_2).children.create!(:name => "Child")
    assert_equal categories(:child_2), category.parent
    assert_equal categories(:child_2).id, category.parent_id
    assert_not_nil category.left
    assert_not_nil category.right
    assert Category.valid?
  end

  def check_structure(entries, structure)
    structure = structure.dup
    Category.each_with_level(entries) do |category, level|
      expected_level, expected_name = structure.shift
      assert_equal expected_name, category.name, "wrong category"
      assert_equal expected_level, level, "wrong level for #{category.name}"
    end
  end

  it "each_with_level" do
    levels = [
      [0, "Top Level"],
      [1, "Child 1"],
      [1, "Child 2"],
      [2, "Child 2.1"],
      [1, "Child 3" ]]

    check_structure(Category.root.self_and_descendants, levels)

    # test some deeper structures
    category = Category.find_by_name("Child 1")
    c1 = Category.new(:name => "Child 1.1")
    c2 = Category.new(:name => "Child 1.1.1")
    c3 = Category.new(:name => "Child 1.1.1.1")
    c4 = Category.new(:name => "Child 1.2")
    [c1, c2, c3, c4].each(&:save!)

    c1.move_to_child_of(category)
    c2.move_to_child_of(c1)
    c3.move_to_child_of(c2)
    c4.move_to_child_of(category)

    levels = [
      [0, "Top Level"],
      [1, "Child 1"],
      [2, "Child 1.1"],
      [3, "Child 1.1.1"],
      [4, "Child 1.1.1.1"],
      [2, "Child 1.2"],
      [1, "Child 2"],
      [2, "Child 2.1"],
      [1, "Child 3" ]]

      check_structure(Category.root.self_and_descendants, levels)
  end

  it "should not error on a model with attr_accessible" do
    model = Class.new(ActiveRecord::Base)
    model.set_table_name 'categories'
    model.attr_accessible :name
    assert_nothing_raised do
      model.acts_as_nested_set
      model.new(:name => 'foo')
    end
  end

  describe "before_move_callback" do
    it "should fire the callback" do
      categories(:child_2).should_receive(:custom_before_move)
      categories(:child_2).move_to_root
    end

    it "should stop move when callback returns false" do
      Category.test_allows_move = false
      assert !categories(:child_3).move_to_root
      assert !categories(:child_3).root?
    end

    it "should not halt save actions" do
      Category.test_allows_move = false
      categories(:child_3).parent_id = nil
      categories(:child_3).save.should be_true
    end
  end
end