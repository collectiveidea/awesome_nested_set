require 'spec_helper'

describe "Category" do
  before(:all) do
    self.class.fixtures :categories, :departments, :notes, :things, :brokens, :users
  end

  describe "hierarchical structure" do
    it "roots_class_method" do
      found_by_us = Category.where(:parent_id => nil).to_a
      found_by_roots = Category.roots.to_a
      found_by_us.length.should == found_by_roots.length
      found_by_us.each do |root|
        found_by_roots.should include(root)
      end
    end

    it "root_class_method" do
      Category.root.should == categories(:top_level)
    end

    it "root" do
      categories(:child_3).root.should == categories(:top_level)
    end

    it "root when not persisted and parent_column_name value is self" do
      new_category = Category.new
      new_category.root.should == new_category
    end

    it "root when not persisted and parent_column_name value is set" do
      last_category = Category.last
      Category.new(Default.parent_column_name => last_category.id).root.should == last_category.root
    end

    it "root?" do
      categories(:top_level).root?.should be_true
      categories(:top_level_2).root?.should be_true
    end

    it "leaves_class_method" do
      Category.where("#{Category.right_column_name} - #{Category.left_column_name} = 1").to_a.should == Category.leaves.to_a
      Category.leaves.count.should == 4
      Category.leaves.should include(categories(:child_1))
      Category.leaves.should include(categories(:child_2_1))
      Category.leaves.should include(categories(:child_3))
      Category.leaves.should include(categories(:top_level_2))
    end

    it "leaf" do
      categories(:child_1).leaf?.should be_true
      categories(:child_2_1).leaf?.should be_true
      categories(:child_3).leaf?.should be_true
      categories(:top_level_2).leaf?.should be_true

      categories(:top_level).leaf?.should be_false
      categories(:child_2).leaf?.should be_false
      Category.new.leaf?.should be_false
    end

    it "parent" do
      categories(:child_2_1).parent.should == categories(:child_2)
    end

    it "self_and_ancestors" do
      child = categories(:child_2_1)
      self_and_ancestors = [categories(:top_level), categories(:child_2), child]
      child.self_and_ancestors.should == self_and_ancestors
    end

    it "ancestors" do
      child = categories(:child_2_1)
      ancestors = [categories(:top_level), categories(:child_2)]
      ancestors.should == child.ancestors
    end

    it "self_and_siblings" do
      child = categories(:child_2)
      self_and_siblings = [categories(:child_1), child, categories(:child_3)]
      self_and_siblings.should == child.self_and_siblings
      lambda do
        tops = [categories(:top_level), categories(:top_level_2)]
        assert_equal tops, categories(:top_level).self_and_siblings
      end.should_not raise_exception
    end

    it "siblings" do
      child = categories(:child_2)
      siblings = [categories(:child_1), categories(:child_3)]
      siblings.should == child.siblings
    end

    it "leaves" do
      leaves = [categories(:child_1), categories(:child_2_1), categories(:child_3)]
      categories(:top_level).leaves.should == leaves
    end
  end

  describe "level" do
    it "returns the correct level" do
      categories(:top_level).level.should == 0
      categories(:child_1).level.should == 1
      categories(:child_2_1).level.should == 2
    end

    context "given parent associations are loaded" do
      it "returns the correct level" do
        child = categories(:child_1)
        if child.respond_to?(:association)
          child.association(:parent).load_target
          child.parent.association(:parent).load_target
          child.level.should == 1
        else
          pending 'associations not used where child#association is not a method'
        end
      end
    end
  end

  describe "depth" do
    context "in general" do
      let(:ceo) { Category.create!(:name => "CEO") }
      let(:district_manager) { Category.create!(:name => "District Manager") }
      let(:store_manager) { Category.create!(:name => "Store Manager") }
      let(:cashier) { Category.create!(:name => "Cashier") }

      before(:each) do
        # ceo > district_manager > store_manager > cashier
        district_manager.move_to_child_of(ceo)
        store_manager.move_to_child_of(district_manager)
        cashier.move_to_child_of(store_manager)
        [ceo, district_manager, store_manager, cashier].each(&:reload)
      end

      it "updates depth when moved into child position" do
        ceo.depth.should == 0
        district_manager.depth.should == 1
        store_manager.depth.should == 2
        cashier.depth.should == 3
      end

      it "updates depth of all descendants when parent is moved" do
        # ceo
        # district_manager > store_manager > cashier
        district_manager.move_to_right_of(ceo)
        [ceo, district_manager, store_manager, cashier].each(&:reload)
        district_manager.depth.should == 0
        store_manager.depth.should == 1
        cashier.depth.should == 2
      end
    end

    it "is magic and does not apply when column is missing" do
      lambda { NoDepth.create!(:name => "shallow") }.should_not raise_error
      lambda { NoDepth.first.save }.should_not raise_error
      lambda { NoDepth.rebuild! }.should_not raise_error

      NoDepth.method_defined?(:depth).should be_false
      NoDepth.first.respond_to?(:depth).should be_false
    end
  end

  it "has_children?" do
    categories(:child_2_1).children.empty?.should be_true
    categories(:child_2).children.empty?.should be_false
    categories(:top_level).children.empty?.should be_false
  end

  it "self_and_descendants" do
    parent = categories(:top_level)
    self_and_descendants = [
      parent,
      categories(:child_1),
      categories(:child_2),
      categories(:child_2_1),
      categories(:child_3)
    ]
    self_and_descendants.should == parent.self_and_descendants
    self_and_descendants.count.should == parent.self_and_descendants.count
  end

  it "descendants" do
    lawyers = Category.create!(:name => "lawyers")
    us = Category.create!(:name => "United States")
    us.move_to_child_of(lawyers)
    patent = Category.create!(:name => "Patent Law")
    patent.move_to_child_of(us)
    lawyers.reload

    lawyers.children.size.should == 1
    us.children.size.should == 1
    lawyers.descendants.size.should == 2
  end

  it "self_and_descendants" do
    parent = categories(:top_level)
    descendants = [
      categories(:child_1),
      categories(:child_2),
      categories(:child_2_1),
      categories(:child_3)
    ]
    descendants.should == parent.descendants
  end

  it "children" do
    category = categories(:top_level)
    category.children.each {|c| category.id.should == c.parent_id }
  end

  it "order_of_children" do
    categories(:child_2).move_left
    categories(:child_2).should == categories(:top_level).children[0]
    categories(:child_1).should == categories(:top_level).children[1]
    categories(:child_3).should == categories(:top_level).children[2]
  end

  it "is_or_is_ancestor_of?" do
    categories(:top_level).is_or_is_ancestor_of?(categories(:child_1)).should be_true
    categories(:top_level).is_or_is_ancestor_of?(categories(:child_2_1)).should be_true
    categories(:child_2).is_or_is_ancestor_of?(categories(:child_2_1)).should be_true
    categories(:child_2_1).is_or_is_ancestor_of?(categories(:child_2)).should be_false
    categories(:child_1).is_or_is_ancestor_of?(categories(:child_2)).should be_false
    categories(:child_1).is_or_is_ancestor_of?(categories(:child_1)).should be_true
  end

  it "is_ancestor_of?" do
    categories(:top_level).is_ancestor_of?(categories(:child_1)).should be_true
    categories(:top_level).is_ancestor_of?(categories(:child_2_1)).should be_true
    categories(:child_2).is_ancestor_of?(categories(:child_2_1)).should be_true
    categories(:child_2_1).is_ancestor_of?(categories(:child_2)).should be_false
    categories(:child_1).is_ancestor_of?(categories(:child_2)).should be_false
    categories(:child_1).is_ancestor_of?(categories(:child_1)).should be_false
  end

  it "is_or_is_ancestor_of_with_scope" do
    root = ScopedCategory.root
    child = root.children.first
    root.is_or_is_ancestor_of?(child).should be_true
    child.update_attribute :organization_id, 'different'
    root.is_or_is_ancestor_of?(child).should be_false
  end

  it "is_or_is_descendant_of?" do
    categories(:child_1).is_or_is_descendant_of?(categories(:top_level)).should be_true
    categories(:child_2_1).is_or_is_descendant_of?(categories(:top_level)).should be_true
    categories(:child_2_1).is_or_is_descendant_of?(categories(:child_2)).should be_true
    categories(:child_2).is_or_is_descendant_of?(categories(:child_2_1)).should be_false
    categories(:child_2).is_or_is_descendant_of?(categories(:child_1)).should be_false
    categories(:child_1).is_or_is_descendant_of?(categories(:child_1)).should be_true
  end

  it "is_descendant_of?" do
    categories(:child_1).is_descendant_of?(categories(:top_level)).should be_true
    categories(:child_2_1).is_descendant_of?(categories(:top_level)).should be_true
    categories(:child_2_1).is_descendant_of?(categories(:child_2)).should be_true
    categories(:child_2).is_descendant_of?(categories(:child_2_1)).should be_false
    categories(:child_2).is_descendant_of?(categories(:child_1)).should be_false
    categories(:child_1).is_descendant_of?(categories(:child_1)).should be_false
  end

  it "is_or_is_descendant_of_with_scope" do
    root = ScopedCategory.root
    child = root.children.first
    child.is_or_is_descendant_of?(root).should be_true
    child.update_attribute :organization_id, 'different'
    child.is_or_is_descendant_of?(root).should be_false
  end

  it "same_scope?" do
    root = ScopedCategory.root
    child = root.children.first
    child.same_scope?(root).should be_true
    child.update_attribute :organization_id, 'different'
    child.same_scope?(root).should be_false
  end

  it "left_sibling" do
    categories(:child_1).should == categories(:child_2).left_sibling
    categories(:child_2).should == categories(:child_3).left_sibling
  end

  it "left_sibling_of_root" do
    categories(:top_level).left_sibling.should be_nil
  end

  it "left_sibling_without_siblings" do
    categories(:child_2_1).left_sibling.should be_nil
  end

  it "left_sibling_of_leftmost_node" do
    categories(:child_1).left_sibling.should be_nil
  end

  it "right_sibling" do
    categories(:child_3).should == categories(:child_2).right_sibling
    categories(:child_2).should == categories(:child_1).right_sibling
  end

  it "right_sibling_of_root" do
    categories(:top_level_2).should == categories(:top_level).right_sibling
    categories(:top_level_2).right_sibling.should be_nil
  end

  it "right_sibling_without_siblings" do
    categories(:child_2_1).right_sibling.should be_nil
  end

  it "right_sibling_of_rightmost_node" do
    categories(:child_3).right_sibling.should be_nil
  end

  it "move_left" do
    categories(:child_2).move_left
    categories(:child_2).left_sibling.should be_nil
    categories(:child_1).should == categories(:child_2).right_sibling
    Category.valid?.should be_true
  end

  it "move_right" do
    categories(:child_2).move_right
    categories(:child_2).right_sibling.should be_nil
    categories(:child_3).should == categories(:child_2).left_sibling
    Category.valid?.should be_true
  end

  it "move_to_left_of" do
    categories(:child_3).move_to_left_of(categories(:child_1))
    categories(:child_3).left_sibling.should be_nil
    categories(:child_1).should == categories(:child_3).right_sibling
    Category.valid?.should be_true
  end

  it "move_to_right_of" do
    categories(:child_1).move_to_right_of(categories(:child_3))
    categories(:child_1).right_sibling.should be_nil
    categories(:child_3).should == categories(:child_1).left_sibling
    Category.valid?.should be_true
  end

  it "move_to_root" do
    categories(:child_2).move_to_root
    categories(:child_2).parent.should be_nil
    categories(:child_2).level.should == 0
    categories(:child_2_1).level.should == 1
    categories(:child_2).left.should == 9
    categories(:child_2).right.should == 12
    Category.valid?.should be_true
  end

  it "move_to_child_of" do
    categories(:child_1).move_to_child_of(categories(:child_3))
    categories(:child_3).id.should == categories(:child_1).parent_id
    Category.valid?.should be_true
  end

  describe "#move_to_child_with_index" do
    it "move to a node without child" do
      categories(:child_1).move_to_child_with_index(categories(:child_3), 0)
      categories(:child_3).id.should == categories(:child_1).parent_id
      categories(:child_1).left.should == 7
      categories(:child_1).right.should == 8
      categories(:child_3).left.should == 6
      categories(:child_3).right.should == 9
      Category.valid?.should be_true
    end

    it "move to a node to the left child" do
      categories(:child_1).move_to_child_with_index(categories(:child_2), 0)
      categories(:child_1).parent_id.should == categories(:child_2).id
      categories(:child_2_1).left.should == 5
      categories(:child_2_1).right.should == 6
      categories(:child_1).left.should == 3
      categories(:child_1).right.should == 4
      categories(:child_2).reload
      categories(:child_2).left.should == 2
      categories(:child_2).right.should == 7
    end

    it "move to a node to the right child" do
      categories(:child_1).move_to_child_with_index(categories(:child_2), 1)
      categories(:child_1).parent_id.should == categories(:child_2).id
      categories(:child_2_1).left.should == 3
      categories(:child_2_1).right.should == 4
      categories(:child_1).left.should == 5
      categories(:child_1).right.should == 6
      categories(:child_2).reload
      categories(:child_2).left.should == 2
      categories(:child_2).right.should == 7
    end

  end

  it "move_to_child_of_appends_to_end" do
    child = Category.create! :name => 'New Child'
    child.move_to_child_of categories(:top_level)
    child.should == categories(:top_level).children.last
  end

  it "subtree_move_to_child_of" do
    categories(:child_2).left.should == 4
    categories(:child_2).right.should == 7

    categories(:child_1).left.should == 2
    categories(:child_1).right.should == 3

    categories(:child_2).move_to_child_of(categories(:child_1))
    Category.valid?.should be_true
    categories(:child_1).id.should == categories(:child_2).parent_id

    categories(:child_2).left.should == 3
    categories(:child_2).right.should == 6
    categories(:child_1).left.should == 2
    categories(:child_1).right.should == 7
  end

  it "slightly_difficult_move_to_child_of" do
    categories(:top_level_2).left.should == 11
    categories(:top_level_2).right.should == 12

    # create a new top-level node and move single-node top-level tree inside it.
    new_top = Category.create(:name => 'New Top')
    new_top.left.should == 13
    new_top.right.should == 14

    categories(:top_level_2).move_to_child_of(new_top)

    Category.valid?.should be_true
    new_top.id.should == categories(:top_level_2).parent_id

    categories(:top_level_2).left.should == 12
    categories(:top_level_2).right.should == 13
    new_top.left.should == 11
    new_top.right.should == 14
  end

  it "difficult_move_to_child_of" do
    categories(:top_level).left.should == 1
    categories(:top_level).right.should == 10
    categories(:child_2_1).left.should == 5
    categories(:child_2_1).right.should == 6

    # create a new top-level node and move an entire top-level tree inside it.
    new_top = Category.create(:name => 'New Top')
    categories(:top_level).move_to_child_of(new_top)
    categories(:child_2_1).reload
    Category.valid?.should be_true
    new_top.id.should == categories(:top_level).parent_id

    categories(:top_level).left.should == 4
    categories(:top_level).right.should == 13
    categories(:child_2_1).left.should == 8
    categories(:child_2_1).right.should == 9
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

    Category.roots.last.to_text.should == output
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

    Category.roots.last.to_text.should == output
  end

  it "should_move_to_ordered_child" do
    node1 = Category.create(:name => 'Node-1')
    node2 = Category.create(:name => 'Node-2')
    node3 = Category.create(:name => 'Node-3')

    node2.move_to_ordered_child_of(node1, "name")

    assert_equal node1, node2.parent
    assert_equal 1, node1.children.count

    node3.move_to_ordered_child_of(node1, "name", true) # acending

    assert_equal node1, node3.parent
    assert_equal 2, node1.children.count
    assert_equal node2.name, node1.children[0].name
    assert_equal node3.name, node1.children[1].name

    node3.move_to_ordered_child_of(node1, "name", false) # decending
    node1.reload

    assert_equal node1, node3.parent
    assert_equal 2, node1.children.count
    assert_equal node3.name, node1.children[0].name
    assert_equal node2.name, node1.children[1].name
  end

  it "should be able to rebuild without validating each record" do
    root1 = Category.create(:name => 'Root1')
    root2 = Category.create(:name => 'Root2')
    root3 = Category.create(:name => 'Root3')

    root2.move_to_child_of root1
    root3.move_to_child_of root1

    root2.name = nil
    root2.save!(:validate => false)

    output = Category.roots.last.to_text
    Category.update_all('lft = null, rgt = null')
    Category.rebuild!(false)

    Category.roots.last.to_text.should == output
  end

  it "valid_with_null_lefts" do
    Category.valid?.should be_true
    Category.update_all('lft = null')
    Category.valid?.should be_false
  end

  it "valid_with_null_rights" do
    Category.valid?.should be_true
    Category.update_all('rgt = null')
    Category.valid?.should be_false
  end

  it "valid_with_missing_intermediate_node" do
    # Even though child_2_1 will still exist, it is a sign of a sloppy delete, not an invalid tree.
    Category.valid?.should be_true
    Category.delete(categories(:child_2).id)
    Category.valid?.should be_true
  end

  it "valid_with_overlapping_and_rights" do
    Category.valid?.should be_true
    categories(:top_level_2)['lft'] = 0
    categories(:top_level_2).save
    Category.valid?.should be_false
  end

  it "rebuild" do
    Category.valid?.should be_true
    before_text = Category.root.to_text
    Category.update_all('lft = null, rgt = null')
    Category.rebuild!
    Category.valid?.should be_true
    before_text.should == Category.root.to_text
  end

  it "move_possible_for_sibling" do
    categories(:child_2).move_possible?(categories(:child_1)).should be_true
  end

  it "move_not_possible_to_self" do
    categories(:top_level).move_possible?(categories(:top_level)).should be_false
  end

  it "move_not_possible_to_parent" do
    categories(:top_level).descendants.each do |descendant|
      categories(:top_level).move_possible?(descendant).should be_false
      descendant.move_possible?(categories(:top_level)).should be_true
    end
  end

  it "is_or_is_ancestor_of?" do
    [:child_1, :child_2, :child_2_1, :child_3].each do |c|
      categories(:top_level).is_or_is_ancestor_of?(categories(c)).should be_true
    end
    categories(:top_level).is_or_is_ancestor_of?(categories(:top_level_2)).should be_false
  end

  it "left_and_rights_valid_with_blank_left" do
    Category.left_and_rights_valid?.should be_true
    categories(:child_2)[:lft] = nil
    categories(:child_2).save(:validate => false)
    Category.left_and_rights_valid?.should be_false
  end

  it "left_and_rights_valid_with_blank_right" do
    Category.left_and_rights_valid?.should be_true
    categories(:child_2)[:rgt] = nil
    categories(:child_2).save(:validate => false)
    Category.left_and_rights_valid?.should be_false
  end

  it "left_and_rights_valid_with_equal" do
    Category.left_and_rights_valid?.should be_true
    categories(:top_level_2)[:lft] = categories(:top_level_2)[:rgt]
    categories(:top_level_2).save(:validate => false)
    Category.left_and_rights_valid?.should be_false
  end

  it "left_and_rights_valid_with_left_equal_to_parent" do
    Category.left_and_rights_valid?.should be_true
    categories(:child_2)[:lft] = categories(:top_level)[:lft]
    categories(:child_2).save(:validate => false)
    Category.left_and_rights_valid?.should be_false
  end

  it "left_and_rights_valid_with_right_equal_to_parent" do
    Category.left_and_rights_valid?.should be_true
    categories(:child_2)[:rgt] = categories(:top_level)[:rgt]
    categories(:child_2).save(:validate => false)
    Category.left_and_rights_valid?.should be_false
  end

  it "moving_dirty_objects_doesnt_invalidate_tree" do
    r1 = Category.create :name => "Test 1"
    r2 = Category.create :name => "Test 2"
    r3 = Category.create :name => "Test 3"
    r4 = Category.create :name => "Test 4"
    nodes = [r1, r2, r3, r4]

    r2.move_to_child_of(r1)
    Category.valid?.should be_true

    r3.move_to_child_of(r1)
    Category.valid?.should be_true

    r4.move_to_child_of(r2)
    Category.valid?.should be_true
  end

  it "delete_does_not_invalidate" do
    Category.acts_as_nested_set_options[:dependent] = :delete
    categories(:child_2).destroy
    Category.valid?.should be_true
  end

  it "destroy_does_not_invalidate" do
    Category.acts_as_nested_set_options[:dependent] = :destroy
    categories(:child_2).destroy
    Category.valid?.should be_true
  end

  it "destroy_multiple_times_does_not_invalidate" do
    Category.acts_as_nested_set_options[:dependent] = :destroy
    categories(:child_2).destroy
    categories(:child_2).destroy
    Category.valid?.should be_true
  end

  it "assigning_parent_id_on_create" do
    category = Category.create!(:name => "Child", :parent_id => categories(:child_2).id)
    categories(:child_2).should == category.parent
    categories(:child_2).id.should == category.parent_id
    category.left.should_not be_nil
    category.right.should_not be_nil
    Category.valid?.should be_true
  end

  it "assigning_parent_on_create" do
    category = Category.create!(:name => "Child", :parent => categories(:child_2))
    categories(:child_2).should == category.parent
    categories(:child_2).id.should == category.parent_id
    category.left.should_not be_nil
    category.right.should_not be_nil
    Category.valid?.should be_true
  end

  it "assigning_parent_id_to_nil_on_create" do
    category = Category.create!(:name => "New Root", :parent_id => nil)
    category.parent.should be_nil
    category.parent_id.should be_nil
    category.left.should_not be_nil
    category.right.should_not be_nil
    Category.valid?.should be_true
  end

  it "assigning_parent_id_on_update" do
    category = categories(:child_2_1)
    category.parent_id = categories(:child_3).id
    category.save
    category.reload
    categories(:child_3).reload
    categories(:child_3).should == category.parent
    categories(:child_3).id.should == category.parent_id
    Category.valid?.should be_true
  end

  it "assigning_parent_on_update" do
    category = categories(:child_2_1)
    category.parent = categories(:child_3)
    category.save
    category.reload
    categories(:child_3).reload
    categories(:child_3).should == category.parent
    categories(:child_3).id.should ==  category.parent_id
    Category.valid?.should be_true
  end

  it "assigning_parent_id_to_nil_on_update" do
    category = categories(:child_2_1)
    category.parent_id = nil
    category.save
    category.parent.should be_nil
    category.parent_id.should be_nil
    Category.valid?.should be_true
  end

  it "creating_child_from_parent" do
    category = categories(:child_2).children.create!(:name => "Child")
    categories(:child_2).should == category.parent
    categories(:child_2).id.should == category.parent_id
    category.left.should_not be_nil
    category.right.should_not be_nil
    Category.valid?.should be_true
  end

  def check_structure(entries, structure)
    structure = structure.dup
    Category.each_with_level(entries) do |category, level|
      expected_level, expected_name = structure.shift
      expected_name.should == category.name
      expected_level.should == level
    end
  end

  it "each_with_level" do
    levels = [
      [0, "Top Level"],
      [1, "Child 1"],
      [1, "Child 2"],
      [2, "Child 2.1"],
      [1, "Child 3" ]
    ]

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
      [1, "Child 3" ]
    ]

    check_structure(Category.root.self_and_descendants, levels)
  end

  describe "before_move_callback" do
    it "should fire the callback" do
      categories(:child_2).should_receive(:custom_before_move)
      categories(:child_2).move_to_root
    end

    it "should stop move when callback returns false" do
      Category.test_allows_move = false
      categories(:child_3).move_to_root.should be_false
      categories(:child_3).root?.should be_false
    end

    it "should not halt save actions" do
      Category.test_allows_move = false
      categories(:child_3).parent_id = nil
      categories(:child_3).save.should be_true
    end
  end

  describe 'associate_parents' do
    it 'assigns parent' do
      root = Category.root
      categories = root.self_and_descendants
      categories = Category.associate_parents categories
      expect(categories[1].parent).to be categories.first
    end

    it 'adds children on inverse of association' do
      root = Category.root
      categories = root.self_and_descendants
      categories = Category.associate_parents categories
      expect(categories[0].children.first).to be categories[1]
    end
  end

  describe 'option dependent' do
    it 'destroy should destroy children and node' do
      Category.acts_as_nested_set_options[:dependent] = :destroy
      root = Category.root
      root.destroy!
      expect(Category.where(id: root.id)).to be_empty
      expect(Category.where(parent_id: root.id)).to be_empty
    end

    it 'delete should delete children and node' do
      Category.acts_as_nested_set_options[:dependent] = :delete
      root = Category.root
      root.destroy!
      expect(Category.where(id: root.id)).to be_empty
      expect(Category.where(parent_id: root.id)).to be_empty
    end

    it 'restrict_with_exception should raise exception' do
      Category.acts_as_nested_set_options[:dependent] = :restrict_with_exception
      root = Category.root
      expect { root.destroy! }.to raise_error  ActiveRecord::DeleteRestrictionError, 'Cannot delete record because of dependent children'
    end

    describe 'restrict_with_error' do
      it 'adds the error to the parent' do
        Category.acts_as_nested_set_options[:dependent] = :restrict_with_error
        root = Category.root
        root.destroy
        assert_equal ["Cannot delete record because dependent children exist"], root.errors[:base]
      end

      it 'deletes the leaf' do
        Category.acts_as_nested_set_options[:dependent] = :restrict_with_error
        leaf = Category.last
        assert_equal leaf, leaf.destroy
      end
    end
  end
end
