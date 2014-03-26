require 'spec_helper'

describe "User" do
  before(:all) do
    self.class.fixtures :categories, :departments, :notes, :things, :brokens, :users
  end

  describe "hierarchical structure" do
    it "roots_class_method" do
      found_by_us = User.where(:parent_uuid => nil).to_a
      found_by_roots = User.roots.to_a
      found_by_us.length.should == found_by_roots.length
      found_by_us.each do |root|
        found_by_roots.should include(root)
      end
    end

    it "root_class_method" do
      User.root.should == users(:top_level)
    end

    it "root" do
      users(:child_3).root.should == users(:top_level)
    end

    it "root when not persisted and parent_column_name value is self" do
      new_user = User.new
      new_user.root.should == new_user
    end

    it "root?" do
      users(:top_level).root?.should be_true
      users(:top_level_2).root?.should be_true
    end

    it "leaves_class_method" do
      User.where("#{User.right_column_name} - #{User.left_column_name} = 1").to_a.should == User.leaves.to_a
      User.leaves.count.should == 4
      User.leaves.should include(users(:child_1))
      User.leaves.should include(users(:child_2_1))
      User.leaves.should include(users(:child_3))
      User.leaves.should include(users(:top_level_2))
    end

    it "leaf" do
      users(:child_1).leaf?.should be_true
      users(:child_2_1).leaf?.should be_true
      users(:child_3).leaf?.should be_true
      users(:top_level_2).leaf?.should be_true

      users(:top_level).leaf?.should be_false
      users(:child_2).leaf?.should be_false
      User.new.leaf?.should be_false
    end

    it "parent" do
      users(:child_2_1).parent.should == users(:child_2)
    end

    it "self_and_ancestors" do
      child = users(:child_2_1)
      self_and_ancestors = [users(:top_level), users(:child_2), child]
      child.self_and_ancestors.should == self_and_ancestors
    end

    it "ancestors" do
      child = users(:child_2_1)
      ancestors = [users(:top_level), users(:child_2)]
      ancestors.should == child.ancestors
    end

    it "self_and_siblings" do
      child = users(:child_2)
      self_and_siblings = [users(:child_1), child, users(:child_3)]
      self_and_siblings.should == child.self_and_siblings
      lambda do
        tops = [users(:top_level), users(:top_level_2)]
        assert_equal tops, users(:top_level).self_and_siblings
      end.should_not raise_exception
    end

    it "siblings" do
      child = users(:child_2)
      siblings = [users(:child_1), users(:child_3)]
      siblings.should == child.siblings
    end

    it "leaves" do
      leaves = [users(:child_1), users(:child_2_1), users(:child_3)]
      users(:top_level).leaves.should == leaves
    end
  end

  describe "level" do
    it "returns the correct level" do
      users(:top_level).level.should == 0
      users(:child_1).level.should == 1
      users(:child_2_1).level.should == 2
    end

    context "given parent associations are loaded" do
      it "returns the correct level" do
        child = users(:child_1)
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
      let(:ceo) { User.create!(:name => "CEO") }
      let(:district_manager) { User.create!(:name => "District Manager") }
      let(:store_manager) { User.create!(:name => "Store Manager") }
      let(:cashier) { User.create!(:name => "Cashier") }

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
    users(:child_2_1).children.empty?.should be_true
    users(:child_2).children.empty?.should be_false
    users(:top_level).children.empty?.should be_false
  end

  it "self_and_descendants" do
    parent = users(:top_level)
    self_and_descendants = [
      parent,
      users(:child_1),
      users(:child_2),
      users(:child_2_1),
      users(:child_3)
    ]
    self_and_descendants.should == parent.self_and_descendants
    self_and_descendants.count.should == parent.self_and_descendants.count
  end

  it "descendants" do
    lawyers = User.create!(:name => "lawyers")
    us = User.create!(:name => "United States")
    us.move_to_child_of(lawyers)
    patent = User.create!(:name => "Patent Law")
    patent.move_to_child_of(us)
    lawyers.reload

    lawyers.children.size.should == 1
    us.children.size.should == 1
    lawyers.descendants.size.should == 2
  end

  it "self_and_descendants" do
    parent = users(:top_level)
    descendants = [
      users(:child_1),
      users(:child_2),
      users(:child_2_1),
      users(:child_3)
    ]
    descendants.should == parent.descendants
  end

  it "children" do
    user = users(:top_level)
    user.children.each {|c| user.uuid.should == c.parent_uuid }
  end

  it "order_of_children" do
    users(:child_2).move_left
    users(:child_2).should == users(:top_level).children[0]
    users(:child_1).should == users(:top_level).children[1]
    users(:child_3).should == users(:top_level).children[2]
  end

  it "is_or_is_ancestor_of?" do
    users(:top_level).is_or_is_ancestor_of?(users(:child_1)).should be_true
    users(:top_level).is_or_is_ancestor_of?(users(:child_2_1)).should be_true
    users(:child_2).is_or_is_ancestor_of?(users(:child_2_1)).should be_true
    users(:child_2_1).is_or_is_ancestor_of?(users(:child_2)).should be_false
    users(:child_1).is_or_is_ancestor_of?(users(:child_2)).should be_false
    users(:child_1).is_or_is_ancestor_of?(users(:child_1)).should be_true
  end

  it "is_ancestor_of?" do
    users(:top_level).is_ancestor_of?(users(:child_1)).should be_true
    users(:top_level).is_ancestor_of?(users(:child_2_1)).should be_true
    users(:child_2).is_ancestor_of?(users(:child_2_1)).should be_true
    users(:child_2_1).is_ancestor_of?(users(:child_2)).should be_false
    users(:child_1).is_ancestor_of?(users(:child_2)).should be_false
    users(:child_1).is_ancestor_of?(users(:child_1)).should be_false
  end

  it "is_or_is_ancestor_of_with_scope" do
    root = ScopedUser.root
    child = root.children.first
    root.is_or_is_ancestor_of?(child).should be_true
    child.update_attribute :organization_id, 'different'
    root.is_or_is_ancestor_of?(child).should be_false
  end

  it "is_or_is_descendant_of?" do
    users(:child_1).is_or_is_descendant_of?(users(:top_level)).should be_true
    users(:child_2_1).is_or_is_descendant_of?(users(:top_level)).should be_true
    users(:child_2_1).is_or_is_descendant_of?(users(:child_2)).should be_true
    users(:child_2).is_or_is_descendant_of?(users(:child_2_1)).should be_false
    users(:child_2).is_or_is_descendant_of?(users(:child_1)).should be_false
    users(:child_1).is_or_is_descendant_of?(users(:child_1)).should be_true
  end

  it "is_descendant_of?" do
    users(:child_1).is_descendant_of?(users(:top_level)).should be_true
    users(:child_2_1).is_descendant_of?(users(:top_level)).should be_true
    users(:child_2_1).is_descendant_of?(users(:child_2)).should be_true
    users(:child_2).is_descendant_of?(users(:child_2_1)).should be_false
    users(:child_2).is_descendant_of?(users(:child_1)).should be_false
    users(:child_1).is_descendant_of?(users(:child_1)).should be_false
  end

  it "is_or_is_descendant_of_with_scope" do
    root = ScopedUser.root
    child = root.children.first
    child.is_or_is_descendant_of?(root).should be_true
    child.update_attribute :organization_id, 'different'
    child.is_or_is_descendant_of?(root).should be_false
  end

  it "same_scope?" do
    root = ScopedUser.root
    child = root.children.first
    child.same_scope?(root).should be_true
    child.update_attribute :organization_id, 'different'
    child.same_scope?(root).should be_false
  end

  it "left_sibling" do
    users(:child_1).should == users(:child_2).left_sibling
    users(:child_2).should == users(:child_3).left_sibling
  end

  it "left_sibling_of_root" do
    users(:top_level).left_sibling.should be_nil
  end

  it "left_sibling_without_siblings" do
    users(:child_2_1).left_sibling.should be_nil
  end

  it "left_sibling_of_leftmost_node" do
    users(:child_1).left_sibling.should be_nil
  end

  it "right_sibling" do
    users(:child_3).should == users(:child_2).right_sibling
    users(:child_2).should == users(:child_1).right_sibling
  end

  it "right_sibling_of_root" do
    users(:top_level_2).should == users(:top_level).right_sibling
    users(:top_level_2).right_sibling.should be_nil
  end

  it "right_sibling_without_siblings" do
    users(:child_2_1).right_sibling.should be_nil
  end

  it "right_sibling_of_rightmost_node" do
    users(:child_3).right_sibling.should be_nil
  end

  it "move_left" do
    users(:child_2).move_left
    users(:child_2).left_sibling.should be_nil
    users(:child_1).should == users(:child_2).right_sibling
    User.valid?.should be_true
  end

  it "move_right" do
    users(:child_2).move_right
    users(:child_2).right_sibling.should be_nil
    users(:child_3).should == users(:child_2).left_sibling
    User.valid?.should be_true
  end

  it "move_to_left_of" do
    users(:child_3).move_to_left_of(users(:child_1))
    users(:child_3).left_sibling.should be_nil
    users(:child_1).should == users(:child_3).right_sibling
    User.valid?.should be_true
  end

  it "move_to_right_of" do
    users(:child_1).move_to_right_of(users(:child_3))
    users(:child_1).right_sibling.should be_nil
    users(:child_3).should == users(:child_1).left_sibling
    User.valid?.should be_true
  end

  it "move_to_root" do
    users(:child_2).move_to_root
    users(:child_2).parent.should be_nil
    users(:child_2).level.should == 0
    users(:child_2_1).level.should == 1
    users(:child_2).left.should == 9
    users(:child_2).right.should == 12
    User.valid?.should be_true
  end

  it "move_to_child_of" do
    users(:child_1).move_to_child_of(users(:child_3))
    users(:child_3).uuid.should == users(:child_1).parent_uuid
    User.valid?.should be_true
  end

  describe "#move_to_child_with_index" do
    it "move to a node without child" do
      users(:child_1).move_to_child_with_index(users(:child_3), 0)
      users(:child_3).uuid.should == users(:child_1).parent_uuid
      users(:child_1).left.should == 7
      users(:child_1).right.should == 8
      users(:child_3).left.should == 6
      users(:child_3).right.should == 9
      User.valid?.should be_true
    end

    it "move to a node to the left child" do
      users(:child_1).move_to_child_with_index(users(:child_2), 0)
      users(:child_1).parent_uuid.should == users(:child_2).uuid
      users(:child_2_1).left.should == 5
      users(:child_2_1).right.should == 6
      users(:child_1).left.should == 3
      users(:child_1).right.should == 4
      users(:child_2).reload
      users(:child_2).left.should == 2
      users(:child_2).right.should == 7
    end

    it "move to a node to the right child" do
      users(:child_1).move_to_child_with_index(users(:child_2), 1)
      users(:child_1).parent_uuid.should == users(:child_2).uuid
      users(:child_2_1).left.should == 3
      users(:child_2_1).right.should == 4
      users(:child_1).left.should == 5
      users(:child_1).right.should == 6
      users(:child_2).reload
      users(:child_2).left.should == 2
      users(:child_2).right.should == 7
    end

  end

  it "move_to_child_of_appends_to_end" do
    child = User.create! :name => 'New Child'
    child.move_to_child_of users(:top_level)
    child.should == users(:top_level).children.last
  end

  it "subtree_move_to_child_of" do
    users(:child_2).left.should == 4
    users(:child_2).right.should == 7

    users(:child_1).left.should == 2
    users(:child_1).right.should == 3

    users(:child_2).move_to_child_of(users(:child_1))
    User.valid?.should be_true
    users(:child_1).uuid.should == users(:child_2).parent_uuid

    users(:child_2).left.should == 3
    users(:child_2).right.should == 6
    users(:child_1).left.should == 2
    users(:child_1).right.should == 7
  end

  it "slightly_difficult_move_to_child_of" do
    users(:top_level_2).left.should == 11
    users(:top_level_2).right.should == 12

    # create a new top-level node and move single-node top-level tree inside it.
    new_top = User.create(:name => 'New Top')
    new_top.left.should == 13
    new_top.right.should == 14

    users(:top_level_2).move_to_child_of(new_top)

    User.valid?.should be_true
    new_top.uuid.should == users(:top_level_2).parent_uuid

    users(:top_level_2).left.should == 12
    users(:top_level_2).right.should == 13
    new_top.left.should == 11
    new_top.right.should == 14
  end

  it "difficult_move_to_child_of" do
    users(:top_level).left.should == 1
    users(:top_level).right.should == 10
    users(:child_2_1).left.should == 5
    users(:child_2_1).right.should == 6

    # create a new top-level node and move an entire top-level tree inside it.
    new_top = User.create(:name => 'New Top')
    users(:top_level).move_to_child_of(new_top)
    users(:child_2_1).reload
    User.valid?.should be_true
    new_top.uuid.should == users(:top_level).parent_uuid

    users(:top_level).left.should == 4
    users(:top_level).right.should == 13
    users(:child_2_1).left.should == 8
    users(:child_2_1).right.should == 9
  end

  #rebuild swaps the position of the 2 children when added using move_to_child twice onto same parent
  it "move_to_child_more_than_once_per_parent_rebuild" do
    root1 = User.create(:name => 'Root1')
    root2 = User.create(:name => 'Root2')
    root3 = User.create(:name => 'Root3')

    root2.move_to_child_of root1
    root3.move_to_child_of root1

    output = User.roots.last.to_text
    User.update_all('lft = null, rgt = null')
    User.rebuild!

    User.roots.last.to_text.should == output
  end

  # doing move_to_child twice onto same parent from the furthest right first
  it "move_to_child_more_than_once_per_parent_outside_in" do
    node1 = User.create(:name => 'Node-1')
    node2 = User.create(:name => 'Node-2')
    node3 = User.create(:name => 'Node-3')

    node2.move_to_child_of node1
    node3.move_to_child_of node1

    output = User.roots.last.to_text
    User.update_all('lft = null, rgt = null')
    User.rebuild!

    User.roots.last.to_text.should == output
  end

  it "should_move_to_ordered_child" do
    node1 = User.create(:name => 'Node-1')
    node2 = User.create(:name => 'Node-2')
    node3 = User.create(:name => 'Node-3')

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
    root1 = User.create(:name => 'Root1')
    root2 = User.create(:name => 'Root2')
    root3 = User.create(:name => 'Root3')

    root2.move_to_child_of root1
    root3.move_to_child_of root1

    root2.name = nil
    root2.save!(:validate => false)

    output = User.roots.last.to_text
    User.update_all('lft = null, rgt = null')
    User.rebuild!(false)

    User.roots.last.to_text.should == output
  end

  it "valid_with_null_lefts" do
    User.valid?.should be_true
    User.update_all('lft = null')
    User.valid?.should be_false
  end

  it "valid_with_null_rights" do
    User.valid?.should be_true
    User.update_all('rgt = null')
    User.valid?.should be_false
  end

  it "valid_with_missing_intermediate_node" do
    # Even though child_2_1 will still exist, it is a sign of a sloppy delete, not an invalid tree.
    User.valid?.should be_true
    User.delete(users(:child_2).uuid)
    User.valid?.should be_true
  end

  it "valid_with_overlapping_and_rights" do
    User.valid?.should be_true
    users(:top_level_2)['lft'] = 0
    users(:top_level_2).save
    User.valid?.should be_false
  end

  it "rebuild" do
    User.valid?.should be_true
    before_text = User.root.to_text
    User.update_all('lft = null, rgt = null')
    User.rebuild!
    User.valid?.should be_true
    before_text.should == User.root.to_text
  end

  it "move_possible_for_sibling" do
    users(:child_2).move_possible?(users(:child_1)).should be_true
  end

  it "move_not_possible_to_self" do
    users(:top_level).move_possible?(users(:top_level)).should be_false
  end

  it "move_not_possible_to_parent" do
    users(:top_level).descendants.each do |descendant|
      users(:top_level).move_possible?(descendant).should be_false
      descendant.move_possible?(users(:top_level)).should be_true
    end
  end

  it "is_or_is_ancestor_of?" do
    [:child_1, :child_2, :child_2_1, :child_3].each do |c|
      users(:top_level).is_or_is_ancestor_of?(users(c)).should be_true
    end
    users(:top_level).is_or_is_ancestor_of?(users(:top_level_2)).should be_false
  end

  it "left_and_rights_valid_with_blank_left" do
    User.left_and_rights_valid?.should be_true
    users(:child_2)[:lft] = nil
    users(:child_2).save(:validate => false)
    User.left_and_rights_valid?.should be_false
  end

  it "left_and_rights_valid_with_blank_right" do
    User.left_and_rights_valid?.should be_true
    users(:child_2)[:rgt] = nil
    users(:child_2).save(:validate => false)
    User.left_and_rights_valid?.should be_false
  end

  it "left_and_rights_valid_with_equal" do
    User.left_and_rights_valid?.should be_true
    users(:top_level_2)[:lft] = users(:top_level_2)[:rgt]
    users(:top_level_2).save(:validate => false)
    User.left_and_rights_valid?.should be_false
  end

  it "left_and_rights_valid_with_left_equal_to_parent" do
    User.left_and_rights_valid?.should be_true
    users(:child_2)[:lft] = users(:top_level)[:lft]
    users(:child_2).save(:validate => false)
    User.left_and_rights_valid?.should be_false
  end

  it "left_and_rights_valid_with_right_equal_to_parent" do
    User.left_and_rights_valid?.should be_true
    users(:child_2)[:rgt] = users(:top_level)[:rgt]
    users(:child_2).save(:validate => false)
    User.left_and_rights_valid?.should be_false
  end

  it "moving_dirty_objects_doesnt_invalidate_tree" do
    r1 = User.create :name => "Test 1"
    r2 = User.create :name => "Test 2"
    r3 = User.create :name => "Test 3"
    r4 = User.create :name => "Test 4"
    nodes = [r1, r2, r3, r4]

    r2.move_to_child_of(r1)
    User.valid?.should be_true

    r3.move_to_child_of(r1)
    User.valid?.should be_true

    r4.move_to_child_of(r2)
    User.valid?.should be_true
  end

  it "delete_does_not_invalidate" do
    User.acts_as_nested_set_options[:dependent] = :delete
    users(:child_2).destroy
    User.valid?.should be_true
  end

  it "destroy_does_not_invalidate" do
    User.acts_as_nested_set_options[:dependent] = :destroy
    users(:child_2).destroy
    User.valid?.should be_true
  end

  it "destroy_multiple_times_does_not_invalidate" do
    User.acts_as_nested_set_options[:dependent] = :destroy
    users(:child_2).destroy
    users(:child_2).destroy
    User.valid?.should be_true
  end

  it "assigning_parent_uuid_on_create" do
    user = User.create!(:name => "Child", :parent_uuid => users(:child_2).uuid)
    users(:child_2).should == user.parent
    users(:child_2).uuid.should == user.parent_uuid
    user.left.should_not be_nil
    user.right.should_not be_nil
    User.valid?.should be_true
  end

  it "assigning_parent_on_create" do
    user = User.create!(:name => "Child", :parent => users(:child_2))
    users(:child_2).should == user.parent
    users(:child_2).uuid.should == user.parent_uuid
    user.left.should_not be_nil
    user.right.should_not be_nil
    User.valid?.should be_true
  end

  it "assigning_parent_uuid_to_nil_on_create" do
    user = User.create!(:name => "New Root", :parent_uuid => nil)
    user.parent.should be_nil
    user.parent_uuid.should be_nil
    user.left.should_not be_nil
    user.right.should_not be_nil
    User.valid?.should be_true
  end

  it "assigning_parent_uuid_on_update" do
    user = users(:child_2_1)
    user.parent_uuid = users(:child_3).uuid
    user.save
    user.reload
    users(:child_3).reload
    users(:child_3).should == user.parent
    users(:child_3).uuid.should == user.parent_uuid
    User.valid?.should be_true
  end

  it "assigning_parent_on_update" do
    user = users(:child_2_1)
    user.parent = users(:child_3)
    user.save
    user.reload
    users(:child_3).reload
    users(:child_3).should == user.parent
    users(:child_3).uuid.should ==  user.parent_uuid
    User.valid?.should be_true
  end

  it "assigning_parent_uuid_to_nil_on_update" do
    user = users(:child_2_1)
    user.parent_uuid = nil
    user.save
    user.parent.should be_nil
    user.parent_uuid.should be_nil
    User.valid?.should be_true
  end

  it "creating_child_from_parent" do
    user = users(:child_2).children.create!(:name => "Child")
    users(:child_2).should == user.parent
    users(:child_2).uuid.should == user.parent_uuid
    user.left.should_not be_nil
    user.right.should_not be_nil
    User.valid?.should be_true
  end

  def check_structure(entries, structure)
    structure = structure.dup
    User.each_with_level(entries) do |user, level|
      expected_level, expected_name = structure.shift
      expected_name.should == user.name
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

    check_structure(User.root.self_and_descendants, levels)

    # test some deeper structures
    user = User.find_by_name("Child 1")
    c1 = User.new(:name => "Child 1.1")
    c2 = User.new(:name => "Child 1.1.1")
    c3 = User.new(:name => "Child 1.1.1.1")
    c4 = User.new(:name => "Child 1.2")
    [c1, c2, c3, c4].each(&:save!)

    c1.move_to_child_of(user)
    c2.move_to_child_of(c1)
    c3.move_to_child_of(c2)
    c4.move_to_child_of(user)

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

    check_structure(User.root.self_and_descendants, levels)
  end

  describe "before_move_callback" do
    it "should fire the callback" do
      users(:child_2).should_receive(:custom_before_move)
      users(:child_2).move_to_root
    end

    it "should stop move when callback returns false" do
      User.test_allows_move = false
      users(:child_3).move_to_root.should be_false
      users(:child_3).root?.should be_false
    end

    it "should not halt save actions" do
      User.test_allows_move = false
      users(:child_3).parent_uuid = nil
      users(:child_3).save.should be_true
    end
  end

  describe 'associate_parents' do
    it 'assigns parent' do
      root = User.root
      users = root.self_and_descendants
      users = User.associate_parents users
      expect(users[1].parent).to be users.first
    end

    it 'adds children on inverse of association' do
      root = User.root
      users = root.self_and_descendants
      users = User.associate_parents users
      expect(users[0].children.first).to be users[1]
    end
  end

  describe 'option dependent' do
    it 'destroy should destroy children and node' do
      User.acts_as_nested_set_options[:dependent] = :destroy
      root = User.root
      root.destroy!
      expect(User.where(id: root.uuid)).to be_empty
      expect(User.where(parent_uuid: root.uuid)).to be_empty
    end

    it 'delete should delete children and node' do
      User.acts_as_nested_set_options[:dependent] = :delete
      root = User.root
      root.destroy!
      expect(User.where(id: root.uuid)).to be_empty
      expect(User.where(parent_uuid: root.uuid)).to be_empty
    end

    it 'restrict_with_exception should raise exception' do
      User.acts_as_nested_set_options[:dependent] = :restrict_with_exception
      root = User.root
      expect { root.destroy! }.to raise_error  ActiveRecord::DeleteRestrictionError, 'Cannot delete record because of dependent children'
    end

    describe 'restrict_with_error' do
      it 'adds the error to the parent' do
        User.acts_as_nested_set_options[:dependent] = :restrict_with_error
        root = User.root
        root.destroy
        assert_equal ["Cannot delete record because dependent children exist"], root.errors[:base]
      end

      it 'deletes the leaf' do
        User.acts_as_nested_set_options[:dependent] = :restrict_with_error
        leaf = User.last
        assert_equal leaf, leaf.destroy
      end
    end
  end
end
