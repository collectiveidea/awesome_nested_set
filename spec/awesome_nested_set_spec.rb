require 'spec_helper'

describe "AwesomeNestedSet" do
  before(:all) do
    self.class.fixtures :categories, :departments, :notes, :things, :brokens, :users, :default_scoped_models
  end

  describe "defaults" do
    it "should have left_column_default" do
      expect(Default.acts_as_nested_set_options[:left_column]).to eq('lft')
    end

    it "should have right_column_default" do
      expect(Default.acts_as_nested_set_options[:right_column]).to eq('rgt')
    end

    it "should have parent_column_default" do
      expect(Default.acts_as_nested_set_options[:parent_column]).to eq('parent_id')
    end

    it " should have a primary_column_default" do
      expect(Default.acts_as_nested_set_options[:primary_column]).to eq('id')
    end

    it "should have scope_default" do
      expect(Default.acts_as_nested_set_options[:scope]).to be_nil
    end

    it "should have left_column_name" do
      expect(Default.left_column_name).to eq('lft')
      expect(Default.new.left_column_name).to eq('lft')
      expect(RenamedColumns.left_column_name).to eq('red')
      expect(RenamedColumns.new.left_column_name).to eq('red')
    end

    it "should have right_column_name" do
      expect(Default.right_column_name).to eq('rgt')
      expect(Default.new.right_column_name).to eq('rgt')
      expect(RenamedColumns.right_column_name).to eq('black')
      expect(RenamedColumns.new.right_column_name).to eq('black')
    end

    it "has a depth_column_name" do
      expect(Default.depth_column_name).to eq('depth')
      expect(Default.new.depth_column_name).to eq('depth')
      expect(RenamedColumns.depth_column_name).to eq('pitch')
      expect(RenamedColumns.depth_column_name).to eq('pitch')
    end

    it "should have parent_column_name" do
      expect(Default.parent_column_name).to eq('parent_id')
      expect(Default.new.parent_column_name).to eq('parent_id')
      expect(RenamedColumns.parent_column_name).to eq('mother_id')
      expect(RenamedColumns.new.parent_column_name).to eq('mother_id')
    end

    it "should have primary_column_name" do
      expect(Default.primary_column_name).to eq('id')
      expect(Default.new.primary_column_name).to eq('id')
      expect(User.primary_column_name).to eq('uuid')
      expect(User.new.primary_column_name).to eq('uuid')
    end
  end

  it "creation_with_altered_column_names" do
    expect {
      RenamedColumns.create!()
    }.not_to raise_exception
  end

  it "creation when existing record has nil left column" do
    expect {
      Broken.create!
    }.not_to raise_exception
  end

  describe "quoted column names" do
    it "quoted_left_column_name" do
      quoted = Default.connection.quote_column_name('lft')
      expect(Default.quoted_left_column_name).to eq(quoted)
      expect(Default.new.quoted_left_column_name).to eq(quoted)
    end

    it "quoted_right_column_name" do
      quoted = Default.connection.quote_column_name('rgt')
      expect(Default.quoted_right_column_name).to eq(quoted)
      expect(Default.new.quoted_right_column_name).to eq(quoted)
    end

    it "quoted_depth_column_name" do
      quoted = Default.connection.quote_column_name('depth')
      expect(Default.quoted_depth_column_name).to eq(quoted)
      expect(Default.new.quoted_depth_column_name).to eq(quoted)
    end

    it "quoted_order_column_name" do
      quoted = Default.connection.quote_column_name('lft')
      expect(Default.quoted_order_column_name).to eq(quoted)
      expect(Default.new.quoted_order_column_name).to eq(quoted)
    end
  end

  describe "protected columns" do
    it "left_column_protected_from_assignment" do
      expect {
        Category.new.lft = 1
      }.to raise_exception(ActiveRecord::ActiveRecordError)
    end

    it "right_column_protected_from_assignment" do
      expect {
        Category.new.rgt = 1
      }.to raise_exception(ActiveRecord::ActiveRecordError)
    end

    it "depth_column_protected_from_assignment" do
      expect {
        Category.new.depth = 1
      }.to raise_exception(ActiveRecord::ActiveRecordError)
    end
  end

  describe "scope" do
    it "scoped_appends_id" do
      expect(ScopedCategory.acts_as_nested_set_options[:scope]).to eq(:organization_id)
    end
  end

  describe "hierarchical structure" do
    it "roots_class_method" do
      found_by_us = Category.where(:parent_id => nil).to_a
      found_by_roots = Category.roots.to_a
      expect(found_by_us.length).to eq(found_by_roots.length)
      found_by_us.each do |root|
        expect(found_by_roots).to include(root)
      end
    end

    it "root_class_method" do
      expect(Category.root).to eq(categories(:top_level))
    end

    it "root" do
      expect(categories(:child_3).root).to eq(categories(:top_level))
    end

    it "root when not persisted and parent_column_name value is self" do
      new_category = Category.new
      expect(new_category.root).to eq(new_category)
    end

    it "root when not persisted and parent_column_name value is set" do
      last_category = Category.last
      expect(Category.new(Default.parent_column_name => last_category.id).root).to eq(last_category.root)
    end

    it "root?" do
      expect(categories(:top_level).root?).to be_truthy
      expect(categories(:top_level_2).root?).to be_truthy
    end

    it "leaves_class_method" do
      expect(Category.where("#{Category.right_column_name} - #{Category.left_column_name} = 1").to_a).to eq(Category.leaves.to_a)
      expect(Category.leaves.count).to eq(4)
      expect(Category.leaves).to include(categories(:child_1))
      expect(Category.leaves).to include(categories(:child_2_1))
      expect(Category.leaves).to include(categories(:child_3))
      expect(Category.leaves).to include(categories(:top_level_2))
    end

    it "leaf" do
      expect(categories(:child_1).leaf?).to be_truthy
      expect(categories(:child_2_1).leaf?).to be_truthy
      expect(categories(:child_3).leaf?).to be_truthy
      expect(categories(:top_level_2).leaf?).to be_truthy

      expect(categories(:top_level).leaf?).to be_falsey
      expect(categories(:child_2).leaf?).to be_falsey
      expect(Category.new.leaf?).to be_falsey
    end

    it "parent" do
      expect(categories(:child_2_1).parent).to eq(categories(:child_2))
    end

    it "self_and_ancestors" do
      child = categories(:child_2_1)
      self_and_ancestors = [categories(:top_level), categories(:child_2), child]
      expect(child.self_and_ancestors).to eq(self_and_ancestors)
    end

    it "ancestors" do
      child = categories(:child_2_1)
      ancestors = [categories(:top_level), categories(:child_2)]
      expect(ancestors).to eq(child.ancestors)
    end

    it "self_and_siblings" do
      child = categories(:child_2)
      self_and_siblings = [categories(:child_1), child, categories(:child_3)]
      expect(self_and_siblings).to eq(child.self_and_siblings)
      expect do
        tops = [categories(:top_level), categories(:top_level_2)]
        assert_equal tops, categories(:top_level).self_and_siblings
      end.not_to raise_exception
    end

    it "siblings" do
      child = categories(:child_2)
      siblings = [categories(:child_1), categories(:child_3)]
      expect(siblings).to eq(child.siblings)
    end

    it "leaves" do
      leaves = [categories(:child_1), categories(:child_2_1), categories(:child_3)]
      expect(categories(:top_level).leaves).to eq(leaves)
    end
  end

  describe "level" do
    it "returns the correct level" do
      expect(categories(:top_level).level).to eq(0)
      expect(categories(:child_1).level).to eq(1)
      expect(categories(:child_2_1).level).to eq(2)
    end

    context "given parent associations are loaded" do
      it "returns the correct level" do
        child = categories(:child_1)
        if child.respond_to?(:association)
          child.association(:parent).load_target
          child.parent.association(:parent).load_target
          expect(child.level).to eq(1)
        else
          skip 'associations not used where child#association is not a method'
        end
      end
    end
  end

  describe "depth" do
    context "in general" do
      let(:lawyers) { Category.create!(:name => "lawyers") }
      let(:us) { Category.create!(:name => "United States") }
      let(:new_york) { Category.create!(:name => "New York") }
      let(:patent) { Category.create!(:name => "Patent Law") }
      let(:ch) { Category.create!(:name => "Switzerland") }
      let(:bern) { Category.create!(:name => "Bern") }

      before(:each) do
        # lawyers > us > new_york > patent
        #         > ch > bern
        us.move_to_child_of(lawyers)
        new_york.move_to_child_of(us)
        patent.move_to_child_of(new_york)
        ch.move_to_child_of(lawyers)
        bern.move_to_child_of(ch)
        [lawyers, us, new_york, patent, ch, bern].each(&:reload)
      end

      it "updates depth when moved into child position" do
        expect(lawyers.depth).to eq(0)
        expect(us.depth).to eq(1)
        expect(new_york.depth).to eq(2)
        expect(patent.depth).to eq(3)
        expect(ch.depth).to eq(1)
        expect(bern.depth).to eq(2)
      end

      it "decreases depth of all descendants when parent is moved up" do
        # lawyers
        # us > new_york > patent
        us.move_to_right_of(lawyers)
        [lawyers, us, new_york, patent, ch, bern].each(&:reload)
        expect(us.depth).to eq(0)
        expect(new_york.depth).to eq(1)
        expect(patent.depth).to eq(2)
        expect(ch.depth).to eq(1)
        expect(bern.depth).to eq(2)
      end

      it "keeps depth of all descendants when parent is moved right" do
        us.move_to_right_of(ch)
        [lawyers, us, new_york, patent, ch, bern].each(&:reload)
        expect(us.depth).to eq(1)
        expect(new_york.depth).to eq(2)
        expect(patent.depth).to eq(3)
        expect(ch.depth).to eq(1)
        expect(bern.depth).to eq(2)
      end

      it "increases depth of all descendants when parent is moved down" do
        us.move_to_child_of(bern)
        [lawyers, us, new_york, patent, ch, bern].each(&:reload)
        expect(us.depth).to eq(3)
        expect(new_york.depth).to eq(4)
        expect(patent.depth).to eq(5)
        expect(ch.depth).to eq(1)
        expect(bern.depth).to eq(2)
      end
    end

    it "is magic and does not apply when column is missing" do
      expect { NoDepth.create!(:name => "shallow") }.not_to raise_error
      expect { NoDepth.first.save }.not_to raise_error
      expect { NoDepth.rebuild! }.not_to raise_error

      expect(NoDepth.method_defined?(:depth)).to be_falsey
      expect(NoDepth.first.respond_to?(:depth)).to be_falsey
    end
  end

  it "has_children?" do
    expect(categories(:child_2_1).children.empty?).to be_truthy
    expect(categories(:child_2).children.empty?).to be_falsey
    expect(categories(:top_level).children.empty?).to be_falsey
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
    expect(self_and_descendants).to eq(parent.self_and_descendants)
    expect(self_and_descendants.count).to eq(parent.self_and_descendants.count)
  end

  it "descendants" do
    lawyers = Category.create!(:name => "lawyers")
    us = Category.create!(:name => "United States")
    us.move_to_child_of(lawyers)
    patent = Category.create!(:name => "Patent Law")
    patent.move_to_child_of(us)
    lawyers.reload

    expect(lawyers.children.size).to eq(1)
    expect(us.children.size).to eq(1)
    expect(lawyers.descendants.size).to eq(2)
  end

  it "self_and_descendants" do
    parent = categories(:top_level)
    descendants = [
      categories(:child_1),
      categories(:child_2),
      categories(:child_2_1),
      categories(:child_3)
    ]
    expect(descendants).to eq(parent.descendants)
  end

  it "children" do
    category = categories(:top_level)
    category.children.each {|c| expect(category.id).to eq(c.parent_id) }
  end

  it "order_of_children" do
    categories(:child_2).move_left
    expect(categories(:child_2)).to eq(categories(:top_level).children[0])
    expect(categories(:child_1)).to eq(categories(:top_level).children[1])
    expect(categories(:child_3)).to eq(categories(:top_level).children[2])
  end

  it "is_or_is_ancestor_of?" do
    expect(categories(:top_level).is_or_is_ancestor_of?(categories(:child_1))).to be_truthy
    expect(categories(:top_level).is_or_is_ancestor_of?(categories(:child_2_1))).to be_truthy
    expect(categories(:child_2).is_or_is_ancestor_of?(categories(:child_2_1))).to be_truthy
    expect(categories(:child_2_1).is_or_is_ancestor_of?(categories(:child_2))).to be_falsey
    expect(categories(:child_1).is_or_is_ancestor_of?(categories(:child_2))).to be_falsey
    expect(categories(:child_1).is_or_is_ancestor_of?(categories(:child_1))).to be_truthy
  end

  it "is_ancestor_of?" do
    expect(categories(:top_level).is_ancestor_of?(categories(:child_1))).to be_truthy
    expect(categories(:top_level).is_ancestor_of?(categories(:child_2_1))).to be_truthy
    expect(categories(:child_2).is_ancestor_of?(categories(:child_2_1))).to be_truthy
    expect(categories(:child_2_1).is_ancestor_of?(categories(:child_2))).to be_falsey
    expect(categories(:child_1).is_ancestor_of?(categories(:child_2))).to be_falsey
    expect(categories(:child_1).is_ancestor_of?(categories(:child_1))).to be_falsey
  end

  it "is_or_is_ancestor_of_with_scope" do
    root = ScopedCategory.root
    child = root.children.first
    expect(root.is_or_is_ancestor_of?(child)).to be_truthy
    child.update_attribute :organization_id, 999999999
    expect(root.is_or_is_ancestor_of?(child)).to be_falsey
  end

  it "is_or_is_descendant_of?" do
    expect(categories(:child_1).is_or_is_descendant_of?(categories(:top_level))).to be_truthy
    expect(categories(:child_2_1).is_or_is_descendant_of?(categories(:top_level))).to be_truthy
    expect(categories(:child_2_1).is_or_is_descendant_of?(categories(:child_2))).to be_truthy
    expect(categories(:child_2).is_or_is_descendant_of?(categories(:child_2_1))).to be_falsey
    expect(categories(:child_2).is_or_is_descendant_of?(categories(:child_1))).to be_falsey
    expect(categories(:child_1).is_or_is_descendant_of?(categories(:child_1))).to be_truthy
  end

  it "is_descendant_of?" do
    expect(categories(:child_1).is_descendant_of?(categories(:top_level))).to be_truthy
    expect(categories(:child_2_1).is_descendant_of?(categories(:top_level))).to be_truthy
    expect(categories(:child_2_1).is_descendant_of?(categories(:child_2))).to be_truthy
    expect(categories(:child_2).is_descendant_of?(categories(:child_2_1))).to be_falsey
    expect(categories(:child_2).is_descendant_of?(categories(:child_1))).to be_falsey
    expect(categories(:child_1).is_descendant_of?(categories(:child_1))).to be_falsey
  end

  it "is_or_is_descendant_of_with_scope" do
    root = ScopedCategory.root
    child = root.children.first
    expect(child.is_or_is_descendant_of?(root)).to be_truthy
    child.update_attribute :organization_id, 999999999
    expect(child.is_or_is_descendant_of?(root)).to be_falsey
  end

  it "same_scope?" do
    root = ScopedCategory.root
    child = root.children.first
    expect(child.same_scope?(root)).to be_truthy
    child.update_attribute :organization_id, 999999999
    expect(child.same_scope?(root)).to be_falsey
  end

  it "left_sibling" do
    expect(categories(:child_1)).to eq(categories(:child_2).left_sibling)
    expect(categories(:child_2)).to eq(categories(:child_3).left_sibling)
  end

  it "left_sibling_of_root" do
    expect(categories(:top_level).left_sibling).to be_nil
  end

  it "left_sibling_without_siblings" do
    expect(categories(:child_2_1).left_sibling).to be_nil
  end

  it "left_sibling_of_leftmost_node" do
    expect(categories(:child_1).left_sibling).to be_nil
  end

  it "right_sibling" do
    expect(categories(:child_3)).to eq(categories(:child_2).right_sibling)
    expect(categories(:child_2)).to eq(categories(:child_1).right_sibling)
  end

  it "right_sibling_of_root" do
    expect(categories(:top_level_2)).to eq(categories(:top_level).right_sibling)
    expect(categories(:top_level_2).right_sibling).to be_nil
  end

  it "right_sibling_without_siblings" do
    expect(categories(:child_2_1).right_sibling).to be_nil
  end

  it "right_sibling_of_rightmost_node" do
    expect(categories(:child_3).right_sibling).to be_nil
  end

  it "move_left" do
    categories(:child_2).move_left
    expect(categories(:child_2).left_sibling).to be_nil
    expect(categories(:child_1)).to eq(categories(:child_2).right_sibling)
    expect(Category.valid?).to be_truthy
  end

  it "move_right" do
    categories(:child_2).move_right
    expect(categories(:child_2).right_sibling).to be_nil
    expect(categories(:child_3)).to eq(categories(:child_2).left_sibling)
    expect(Category.valid?).to be_truthy
  end

  it "move_to_left_of" do
    categories(:child_3).move_to_left_of(categories(:child_1))
    expect(categories(:child_3).left_sibling).to be_nil
    expect(categories(:child_1)).to eq(categories(:child_3).right_sibling)
    expect(Category.valid?).to be_truthy
  end

  it "move_to_right_of" do
    categories(:child_1).move_to_right_of(categories(:child_3))
    expect(categories(:child_1).right_sibling).to be_nil
    expect(categories(:child_3)).to eq(categories(:child_1).left_sibling)
    expect(Category.valid?).to be_truthy
  end

  it "move_to_root" do
    categories(:child_2).move_to_root
    expect(categories(:child_2).parent).to be_nil
    expect(categories(:child_2).level).to eq(0)
    expect(categories(:child_2_1).level).to eq(1)
    expect(categories(:child_2).left).to eq(9)
    expect(categories(:child_2).right).to eq(12)
    expect(Category.valid?).to be_truthy
  end

  it "move_to_child_of" do
    categories(:child_1).move_to_child_of(categories(:child_3))
    expect(categories(:child_3).id).to eq(categories(:child_1).parent_id)
    expect(Category.valid?).to be_truthy
  end

  describe "#move_to_child_with_index" do
    it "move to a node without child" do
      categories(:child_1).move_to_child_with_index(categories(:child_3), 0)
      expect(categories(:child_3).id).to eq(categories(:child_1).parent_id)
      expect(categories(:child_1).left).to eq(7)
      expect(categories(:child_1).right).to eq(8)
      expect(categories(:child_3).left).to eq(6)
      expect(categories(:child_3).right).to eq(9)
      expect(Category.valid?).to be_truthy
    end

    it "move to a node to the left child" do
      categories(:child_1).move_to_child_with_index(categories(:child_2), 0)
      expect(categories(:child_1).parent_id).to eq(categories(:child_2).id)
      expect(categories(:child_2_1).left).to eq(5)
      expect(categories(:child_2_1).right).to eq(6)
      expect(categories(:child_1).left).to eq(3)
      expect(categories(:child_1).right).to eq(4)
      categories(:child_2).reload
      expect(categories(:child_2).left).to eq(2)
      expect(categories(:child_2).right).to eq(7)
    end

    it "move to a node to the right child" do
      categories(:child_1).move_to_child_with_index(categories(:child_2), 1)
      expect(categories(:child_1).parent_id).to eq(categories(:child_2).id)
      expect(categories(:child_2_1).left).to eq(3)
      expect(categories(:child_2_1).right).to eq(4)
      expect(categories(:child_1).left).to eq(5)
      expect(categories(:child_1).right).to eq(6)
      categories(:child_2).reload
      expect(categories(:child_2).left).to eq(2)
      expect(categories(:child_2).right).to eq(7)
    end

    it "move downward within current parent" do
      categories(:child_1).move_to_child_with_index(categories(:top_level), 1)
      expect(categories(:child_1).parent_id).to eq(categories(:top_level).id)
      expect(categories(:child_1).left).to eq(6)
      expect(categories(:child_1).right).to eq(7)
      categories(:child_2).reload
      expect(categories(:child_2).parent_id).to eq(categories(:top_level).id)
      expect(categories(:child_2).left).to eq(2)
      expect(categories(:child_2).right).to eq(5)
    end

    it "move to the same position within current parent" do
      categories(:child_1).move_to_child_with_index(categories(:top_level), 0)
      expect(categories(:child_1).parent_id).to eq(categories(:top_level).id)
      expect(categories(:child_1).left).to eq(2)
      expect(categories(:child_1).right).to eq(3)
    end
  end

  it "move_to_child_of_appends_to_end" do
    child = Category.create! :name => 'New Child'
    child.move_to_child_of categories(:top_level)
    expect(child).to eq(categories(:top_level).children.last)
  end

  it "subtree_move_to_child_of" do
    expect(categories(:child_2).left).to eq(4)
    expect(categories(:child_2).right).to eq(7)

    expect(categories(:child_1).left).to eq(2)
    expect(categories(:child_1).right).to eq(3)

    categories(:child_2).move_to_child_of(categories(:child_1))
    expect(Category.valid?).to be_truthy
    expect(categories(:child_1).id).to eq(categories(:child_2).parent_id)

    expect(categories(:child_2).left).to eq(3)
    expect(categories(:child_2).right).to eq(6)
    expect(categories(:child_1).left).to eq(2)
    expect(categories(:child_1).right).to eq(7)
  end

  it "slightly_difficult_move_to_child_of" do
    expect(categories(:top_level_2).left).to eq(11)
    expect(categories(:top_level_2).right).to eq(12)

    # create a new top-level node and move single-node top-level tree inside it.
    new_top = Category.create(:name => 'New Top')
    expect(new_top.left).to eq(13)
    expect(new_top.right).to eq(14)

    categories(:top_level_2).move_to_child_of(new_top)

    expect(Category.valid?).to be_truthy
    expect(new_top.id).to eq(categories(:top_level_2).parent_id)

    expect(categories(:top_level_2).left).to eq(12)
    expect(categories(:top_level_2).right).to eq(13)
    expect(new_top.left).to eq(11)
    expect(new_top.right).to eq(14)
  end

  it "difficult_move_to_child_of" do
    expect(categories(:top_level).left).to eq(1)
    expect(categories(:top_level).right).to eq(10)
    expect(categories(:child_2_1).left).to eq(5)
    expect(categories(:child_2_1).right).to eq(6)

    # create a new top-level node and move an entire top-level tree inside it.
    new_top = Category.create(:name => 'New Top')
    categories(:top_level).move_to_child_of(new_top)
    categories(:child_2_1).reload
    expect(Category.valid?).to be_truthy
    expect(new_top.id).to eq(categories(:top_level).parent_id)

    expect(categories(:top_level).left).to eq(4)
    expect(categories(:top_level).right).to eq(13)
    expect(categories(:child_2_1).left).to eq(8)
    expect(categories(:child_2_1).right).to eq(9)
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

    expect(Category.roots.last.to_text).to eq(output)
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

    expect(Category.roots.last.to_text).to eq(output)
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

    expect(node3.parent).to eq(node1)
    expect(node1.children.count).to be(2)
    expect(node1.children[0].name).to eq(node3.name)
    expect(node1.children[1].name).to eq(node2.name)
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

    expect(Category.roots.last.to_text).to eq(output)
  end

  it "valid_with_null_lefts" do
    expect(Category.valid?).to be_truthy
    Category.update_all('lft = null')
    expect(Category.valid?).to be_falsey
  end

  it "valid_with_null_rights" do
    expect(Category.valid?).to be_truthy
    Category.update_all('rgt = null')
    expect(Category.valid?).to be_falsey
  end

  it "valid_with_missing_intermediate_node" do
    # Even though child_2_1 will still exist, it is a sign of a sloppy delete, not an invalid tree.
    expect(Category.valid?).to be_truthy
    Category.delete(categories(:child_2).id)
    expect(Category.valid?).to be_truthy
  end

  it "valid_with_overlapping_and_rights" do
    expect(Category.valid?).to be_truthy
    categories(:top_level_2)['lft'] = 0
    categories(:top_level_2).save
    expect(Category.valid?).to be_falsey
  end

  it "rebuild" do
    expect(Category.valid?).to be_truthy
    before_text = Category.root.to_text
    Category.update_all('lft = null, rgt = null')
    Category.rebuild!
    expect(Category.valid?).to be_truthy
    expect(before_text).to eq(Category.root.to_text)
  end

  describe ".rebuild!" do
    subject { Thing.rebuild! }
    before { Thing.update_all(children_count: 0) }

    context "when items have children" do
      it "updates their counter_cache" do
        expect { subject }.to change {
          things(:parent1).reload.children_count }.to(2).from(0).
          and change { things(:child_2).reload.children_count }.to(1).from(0)
      end
    end

    context "when items do not have children" do
      it "doesn't change their counter_cache" do
        subject
        expect(things(:child_1).reload.children_count).to eq(0)
        expect(things(:child_2_1).reload.children_count).to eq(0)
      end
    end
  end

  it "move_possible_for_sibling" do
    expect(categories(:child_2).move_possible?(categories(:child_1))).to be_truthy
  end

  it "move_not_possible_to_self" do
    expect(categories(:top_level).move_possible?(categories(:top_level))).to be_falsey
  end

  it "move_not_possible_to_parent" do
    categories(:top_level).descendants.each do |descendant|
      expect(categories(:top_level).move_possible?(descendant)).to be_falsey
      expect(descendant.move_possible?(categories(:top_level))).to be_truthy
    end
  end

  it "is_or_is_ancestor_of?" do
    [:child_1, :child_2, :child_2_1, :child_3].each do |c|
      expect(categories(:top_level).is_or_is_ancestor_of?(categories(c))).to be_truthy
    end
    expect(categories(:top_level).is_or_is_ancestor_of?(categories(:top_level_2))).to be_falsey
  end

  it "left_and_rights_valid_with_blank_left" do
    expect(Category.left_and_rights_valid?).to be_truthy
    categories(:child_2)[:lft] = nil
    categories(:child_2).save(:validate => false)
    expect(Category.left_and_rights_valid?).to be_falsey
  end

  it "left_and_rights_valid_with_blank_right" do
    expect(Category.left_and_rights_valid?).to be_truthy
    categories(:child_2)[:rgt] = nil
    categories(:child_2).save(:validate => false)
    expect(Category.left_and_rights_valid?).to be_falsey
  end

  it "left_and_rights_valid_with_equal" do
    expect(Category.left_and_rights_valid?).to be_truthy
    categories(:top_level_2)[:lft] = categories(:top_level_2)[:rgt]
    categories(:top_level_2).save(:validate => false)
    expect(Category.left_and_rights_valid?).to be_falsey
  end

  it "left_and_rights_valid_with_left_equal_to_parent" do
    expect(Category.left_and_rights_valid?).to be_truthy
    categories(:child_2)[:lft] = categories(:top_level)[:lft]
    categories(:child_2).save(:validate => false)
    expect(Category.left_and_rights_valid?).to be_falsey
  end

  it "left_and_rights_valid_with_right_equal_to_parent" do
    expect(Category.left_and_rights_valid?).to be_truthy
    categories(:child_2)[:rgt] = categories(:top_level)[:rgt]
    categories(:child_2).save(:validate => false)
    expect(Category.left_and_rights_valid?).to be_falsey
  end

  it "moving_dirty_objects_doesnt_invalidate_tree" do
    r1 = Category.create :name => "Test 1"
    r2 = Category.create :name => "Test 2"
    r3 = Category.create :name => "Test 3"
    r4 = Category.create :name => "Test 4"
    nodes = [r1, r2, r3, r4]

    r2.move_to_child_of(r1)
    expect(Category.valid?).to be_truthy

    r3.move_to_child_of(r1)
    expect(Category.valid?).to be_truthy

    r4.move_to_child_of(r2)
    expect(Category.valid?).to be_truthy
  end

  it "multi_scoped_no_duplicates_for_columns?" do
    expect {
      Note.no_duplicates_for_columns?
    }.not_to raise_exception
  end

  it "multi_scoped_all_roots_valid?" do
    expect {
      Note.all_roots_valid?
    }.not_to raise_exception
  end

  it "multi_scoped" do
    note1 = Note.create!(:body => "A", :notable_id => 2, :notable_type => 'Category')
    note2 = Note.create!(:body => "B", :notable_id => 2, :notable_type => 'Category')
    note3 = Note.create!(:body => "C", :notable_id => 2, :notable_type => 'Default')

    expect([note1, note2]).to eq(note1.self_and_siblings)
    expect([note3]).to eq(note3.self_and_siblings)
  end

  it "multi_scoped_rebuild" do
    root = Note.create!(:body => "A", :notable_id => 3, :notable_type => 'Category')
    child1 = Note.create!(:body => "B", :notable_id => 3, :notable_type => 'Category')
    child2 = Note.create!(:body => "C", :notable_id => 3, :notable_type => 'Category')

    child1.move_to_child_of root
    child2.move_to_child_of root

    Note.update_all('lft = null, rgt = null')
    Note.rebuild!

    expect(Note.roots.find_by_body('A')).to eq(root)
    expect([child1, child2]).to eq(Note.roots.find_by_body('A').children)
  end

  it "same_scope_with_multi_scopes" do
    expect {
      notes(:scope1).same_scope?(notes(:child_1))
    }.not_to raise_exception
    expect(notes(:scope1).same_scope?(notes(:child_1))).to be_truthy
    expect(notes(:child_1).same_scope?(notes(:scope1))).to be_truthy
    expect(notes(:scope1).same_scope?(notes(:scope2))).to be_falsey
  end

  it "quoting_of_multi_scope_column_names" do
    ## Proper Array Assignment for different DBs as per their quoting column behavior
    if Note.connection.adapter_name.match(/oracle/i)
      expected_quoted_scope_column_names = ["\"NOTABLE_ID\"", "\"NOTABLE_TYPE\""]
    elsif Note.connection.adapter_name.match(/mysql/i)
      expected_quoted_scope_column_names = ["`notable_id`", "`notable_type`"]
    else
      expected_quoted_scope_column_names = ["\"notable_id\"", "\"notable_type\""]
    end
    expect(Note.quoted_scope_column_names).to eq(expected_quoted_scope_column_names)
  end

  it "equal_in_same_scope" do
    expect(notes(:scope1)).to eq(notes(:scope1))
    expect(notes(:scope1)).not_to eq(notes(:child_1))
  end

  it "equal_in_different_scopes" do
    expect(notes(:scope1)).not_to eq(notes(:scope2))
  end

  it "delete_does_not_invalidate" do
    Category.acts_as_nested_set_options[:dependent] = :delete
    categories(:child_2).destroy
    expect(Category.valid?).to be_truthy
  end

  it "destroy_does_not_invalidate" do
    Category.acts_as_nested_set_options[:dependent] = :destroy
    categories(:child_2).destroy
    expect(Category.valid?).to be_truthy
  end

  it "destroy_multiple_times_does_not_invalidate" do
    Category.acts_as_nested_set_options[:dependent] = :destroy
    categories(:child_2).destroy
    categories(:child_2).destroy
    expect(Category.valid?).to be_truthy
  end

  it "assigning_parent_id_on_create" do
    category = Category.create!(:name => "Child", :parent_id => categories(:child_2).id)
    expect(categories(:child_2)).to eq(category.parent)
    expect(categories(:child_2).id).to eq(category.parent_id)
    expect(category.left).not_to be_nil
    expect(category.right).not_to be_nil
    expect(Category.valid?).to be_truthy
  end

  it "assigning_parent_on_create" do
    category = Category.create!(:name => "Child", :parent => categories(:child_2))
    expect(categories(:child_2)).to eq(category.parent)
    expect(categories(:child_2).id).to eq(category.parent_id)
    expect(category.left).not_to be_nil
    expect(category.right).not_to be_nil
    expect(Category.valid?).to be_truthy
  end

  it "assigning_parent_id_to_nil_on_create" do
    category = Category.create!(:name => "New Root", :parent_id => nil)
    expect(category.parent).to be_nil
    expect(category.parent_id).to be_nil
    expect(category.left).not_to be_nil
    expect(category.right).not_to be_nil
    expect(Category.valid?).to be_truthy
  end

  it "assigning_parent_id_on_update" do
    category = categories(:child_2_1)
    category.parent_id = categories(:child_3).id
    category.save
    category.reload
    categories(:child_3).reload
    expect(categories(:child_3)).to eq(category.parent)
    expect(categories(:child_3).id).to eq(category.parent_id)
    expect(Category.valid?).to be_truthy
  end

  it "assigning_parent_on_update" do
    category = categories(:child_2_1)
    category.parent = categories(:child_3)
    category.save
    category.reload
    categories(:child_3).reload
    expect(categories(:child_3)).to eq(category.parent)
    expect(categories(:child_3).id).to eq(category.parent_id)
    expect(Category.valid?).to be_truthy
  end

  it "assigning_parent_id_to_nil_on_update" do
    category = categories(:child_2_1)
    category.parent_id = nil
    category.save
    expect(category.parent).to be_nil
    expect(category.parent_id).to be_nil
    expect(Category.valid?).to be_truthy
  end

  it "creating_child_from_parent" do
    category = categories(:child_2).children.create!(:name => "Child")
    expect(categories(:child_2)).to eq(category.parent)
    expect(categories(:child_2).id).to eq(category.parent_id)
    expect(category.left).not_to be_nil
    expect(category.right).not_to be_nil
    expect(Category.valid?).to be_truthy
  end

  def check_structure(entries, structure)
    structure = structure.dup
    Category.each_with_level(entries) do |category, level|
      expected_level, expected_name = structure.shift
      expect(expected_name).to eq(category.name)
      expect(expected_level).to eq(level)
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
      expect(categories(:child_2)).to receive(:custom_before_move)
      categories(:child_2).move_to_root
    end

    it "should stop move when callback returns false" do
      Category.test_allows_move = false
      expect(categories(:child_3).move_to_root).to be_falsey
      expect(categories(:child_3).root?).to be_falsey
    end

    it "should not halt save actions" do
      Category.test_allows_move = false
      categories(:child_3).parent_id = nil
      expect(categories(:child_3).save).to be_truthy
    end
  end

  describe "counter_cache" do
    let(:parent1) { things(:parent1) }
    let(:child_1) { things(:child_1) }
    let(:child_2) { things(:child_2) }
    let(:child_2_1) { things(:child_2_1) }

    it "should allow use of a counter cache for children" do
      expect(parent1.children_count).to eq(parent1.children.count)
    end

    it "should increment the counter cache on create" do
      expect {
        parent1.children.create body: "Child 3"
      }.to change { parent1.reload.children_count }.by(1)
    end

    it "should decrement the counter cache on destroy" do
      expect {
        parent1.children.last.destroy
      }.to change { parent1.reload.children_count }.by(-1)
    end

    context "when moving a grandchild to the root" do
      subject { child_2_1.move_to_root }

      it "should decrement the counter cache of its parent" do
        expect { subject }.to change { child_2.reload.children_count }.by(-1)
      end
    end

    context "when moving within a node" do
      subject { child_1.move_to_right_of(child_2) }

      it "should not update any values" do
        expect { subject }.to_not change { parent1.reload.children_count }
      end
    end

    context "when a child moves to another node" do
      let(:old_parent) { things(:child_2) }
      let(:child) { things(:child_2_1) }
      let!(:new_parent) { Thing.create(body: "New Parent") }

      subject { child.move_to_child_of(new_parent) }

      it "should decrement the counter cache of its parent" do
        expect { subject }.to change { old_parent.reload.children_count }.by(-1)
      end

      it "should increment the counter cache of its new parent" do
        expect { subject }.to change { new_parent.reload.children_count }.by(1)
      end
    end
  end

  describe "association callbacks on children" do
    it "should call the appropriate callbacks on the children :has_many association " do
      root = DefaultWithCallbacks.create
      expect(root).not_to be_new_record

      child = root.children.build

      expect(root.before_add).to eq(child)
      expect(root.after_add).to  eq(child)

      expect(root.before_remove).not_to eq(child)
      expect(root.after_remove).not_to  eq(child)

      expect(child.save).to be_truthy
      expect(root.children.delete(child)).to be_truthy

      expect(root.before_remove).to eq(child)
      expect(root.after_remove).to  eq(child)
    end
  end

  describe 'rebuilding tree with a default scope ordering' do
    it "doesn't throw exception" do
      expect { Position.rebuild! }.not_to raise_error
    end
  end

  describe 'creating roots with a default scope ordering' do
    it "assigns rgt and lft correctly" do
      alpha = Order.create(:name => 'Alpha')
      gamma = Order.create(:name => 'Gamma')
      omega = Order.create(:name => 'Omega')

      expect(alpha.lft).to eq(1)
      expect(alpha.rgt).to eq(2)
      expect(gamma.lft).to eq(3)
      expect(gamma.rgt).to eq(4)
      expect(omega.lft).to eq(5)
      expect(omega.rgt).to eq(6)
    end
  end

  describe 'moving node from one scoped tree to another' do
    xit "moves single node correctly" do
      root1 = Note.create!(:body => "A-1", :notable_id => 4, :notable_type => 'Category')
      child1_1 = Note.create!(:body => "B-1", :notable_id => 4, :notable_type => 'Category')
      child1_2 = Note.create!(:body => "C-1", :notable_id => 4, :notable_type => 'Category')
      child1_1.move_to_child_of root1
      child1_2.move_to_child_of root1

      root2 = Note.create!(:body => "A-2", :notable_id => 5, :notable_type => 'Category')
      child2_1 = Note.create!(:body => "B-2", :notable_id => 5, :notable_type => 'Category')
      child2_2 = Note.create!(:body => "C-2", :notable_id => 5, :notable_type => 'Category')
      child2_1.move_to_child_of root2
      child2_2.move_to_child_of root2

      child1_1.update_attributes!(:notable_id => 5)
      child1_1.move_to_child_of root2

      expect(root1.children).to eq([child1_2])
      expect(root2.children).to eq([child2_1, child2_2, child1_1])

      expect(Note.valid?).to eq(true)
    end

    xit "moves node with children correctly" do
      root1 = Note.create!(:body => "A-1", :notable_id => 4, :notable_type => 'Category')
      child1_1 = Note.create!(:body => "B-1", :notable_id => 4, :notable_type => 'Category')
      child1_2 = Note.create!(:body => "C-1", :notable_id => 4, :notable_type => 'Category')
      child1_1.move_to_child_of root1
      child1_2.move_to_child_of child1_1

      root2 = Note.create!(:body => "A-2", :notable_id => 5, :notable_type => 'Category')
      child2_1 = Note.create!(:body => "B-2", :notable_id => 5, :notable_type => 'Category')
      child2_2 = Note.create!(:body => "C-2", :notable_id => 5, :notable_type => 'Category')
      child2_1.move_to_child_of root2
      child2_2.move_to_child_of root2

      child1_1.update_attributes!(:notable_id => 5)
      child1_1.move_to_child_of root2

      expect(root1.children).to eq([])
      expect(root2.children).to eq([child2_1, child2_2, child1_1])
      child1_1.children is_expected.to eq([child1_2])
      expect(root2.siblings).to eq([child2_1, child2_2, child1_1, child1_2])

      expect(Note.valid?).to eq(true)
    end
  end

  describe 'specifying custom sort column' do
    it "should sort by the default sort column" do
      expect(Category.order_column).to eq('lft')
    end

    it "should sort by custom sort column" do
      expect(OrderedCategory.acts_as_nested_set_options[:order_column]).to eq('name')
      expect(OrderedCategory.order_column).to eq('name')
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

  describe 'table inheritance' do
    it 'allows creation of a subclass pointing to a superclass' do
      subclass1 = Subclass1.create(name: "Subclass1")
      Subclass2.create(name: "Subclass2", parent_id: subclass1.id)
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

    it "properly destroy association's objects and its children and nodes" do
      Category.acts_as_nested_set_options[:dependent] = :destroy
      user = User.first
      note_ids = user.note_ids
      user.notes.destroy_all
      expect(Note.where(id: note_ids, user_id: user.id).count).to be_zero
    end

    it 'delete should delete children and node' do
      Category.acts_as_nested_set_options[:dependent] = :delete
      root = Category.root
      root.destroy!
      expect(Category.where(id: root.id)).to be_empty
      expect(Category.where(parent_id: root.id)).to be_empty
    end

    it 'nullify should nullify child parent IDs rather than deleting' do
      Category.acts_as_nested_set_options[:dependent] = :nullify
      root = Category.root
      child_ids = root.child_ids
      root.destroy!
      expect(Category.where(id: child_ids)).to_not be_empty
      expect(Category.where(parent_id: root.id)).to be_empty
    end

    describe 'restrict_with_exception' do
      it 'raises an exception' do
        Category.acts_as_nested_set_options[:dependent] = :restrict_with_exception
        root = Category.root
        expect { root.destroy! }.to raise_error  ActiveRecord::DeleteRestrictionError, 'Cannot delete record because of dependent children'
      end

      it 'deletes the leaf' do
        Category.acts_as_nested_set_options[:dependent] = :restrict_with_exception
        leaf = Category.last
        expect(leaf.destroy).to eq(leaf)
      end
    end

    describe 'restrict_with_error' do
      it 'adds the error to the parent' do
        Category.acts_as_nested_set_options[:dependent] = :restrict_with_error
        root = Category.root
        root.destroy
        expect(root.errors[:base]).to eq(["Cannot delete record because dependent children exist"])
      end

      it 'deletes the leaf' do
        Category.acts_as_nested_set_options[:dependent] = :restrict_with_error
        leaf = Category.last
        expect(leaf.destroy).to eq(leaf)
      end
    end
    describe "model with default_scope" do
      it "should have correct #lft & #rgt" do
        parent = DefaultScopedModel.find(6)

        DefaultScopedModel.send(:default_scope, Proc.new { parent.reload.self_and_descendants })

        children = parent.children.create(name: 'Helloworld')

        DefaultScopedModel.unscoped do
          expect(children.is_descendant_of?(parent.reload)).to be true
        end
      end
    end
  end
end
