require File.dirname(__FILE__) + '/spec_helper'

describe "acts_as_nested_set" do
  class Default < ActiveRecord::Base
    acts_as_nested_set
  end
  attr_accessor :options
  before do
    @options = Default.acts_as_nested_set_options
  end
  
  it "should set :left_column default to 'lft'" do
    options[:left_column].should == 'lft'
  end

  it "should set :right_column default to 'rgt'" do
    options[:right_column].should == 'rgt'
  end
  
  it "should set :parent_column default to 'parent_id'" do
    options[:parent_column].should == 'parent_id'
  end

  it "should set :scope default to nil" do
    options[:scope].should be_nil
  end
  
  it "should protect :left_column from being assigned" do
    lambda { Category.new.lft = 1 }.should raise_error(ActiveRecord::ActiveRecordError)
  end

  it "should protect :right_column from being assigned" do
    lambda { Category.new.rgt = 1 }.should raise_error(ActiveRecord::ActiveRecordError)
  end
  
  it "should protect :parent_column from being assigned" do
    lambda { Category.new.parent_id = 1 }.should raise_error(ActiveRecord::ActiveRecordError)
  end
  
end

describe "acts_as_nested_set scoped with symbol" do
  class Scoped < ActiveRecord::Base
    acts_as_nested_set :scope => :organization
  end
  
  it "should append _id to the symbol" do
    Scoped.acts_as_nested_set_options[:scope].should == :organization_id
  end
  
end

describe "acts_as_nested_set.roots" do
  fixtures :categories
  
  before do
    @roots = Category.roots
  end
  
  it "should find all records without a parent_id" do
    @roots.should == Category.find_all_by_parent_id(nil)
  end
  
end

describe "acts_as_nested_set.root" do
  fixtures :categories
  
  before do
    @root = Category.root
  end
  
  it "should find first record without a parent_id" do
    @root.should == categories(:top_level)
  end

end

describe "acts_as_nested_set#children" do
  fixtures :categories
  
  before do
    @category = categories(:top_level)
    @children = @category.children
  end
  
  it "should include direct descendents" do
    @children.each {|c| c.parent_id.should == @category.id }
  end
end

describe "acts_as_nested_set#root" do
  fixtures :categories
  
  before do
    @child = categories(:child_3)
    @root = categories(:top_level)
  end
  
  it "should return the root of the tree" do
    @child.root.should == @root
  end

end

describe "acts_as_nested_set#parent" do
  fixtures :categories
  
  before do
    @child = categories(:child_2_1)
    @parent = categories(:child_2)
  end
  
  it "should return the parent" do
    @child.parent.should == @parent
  end

end
