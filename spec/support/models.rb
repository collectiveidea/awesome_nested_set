class Note < ActiveRecord::Base
  acts_as_nested_set :scope => [:notable_id, :notable_type]
end

class Default < ActiveRecord::Base
  set_table_name 'categories'
  acts_as_nested_set
end

class ScopedCategory < ActiveRecord::Base
  set_table_name 'categories'
  acts_as_nested_set :scope => :organization
end

class RenamedColumns < ActiveRecord::Base
  acts_as_nested_set :parent_column => 'mother_id', :left_column => 'red', :right_column => 'black'
end

class Category < ActiveRecord::Base
  acts_as_nested_set

  validates_presence_of :name

  # Setup a callback that we can switch to true or false per-test
  set_callback :move, :before, :custom_before_move
  cattr_accessor :test_allows_move
  @@test_allows_move = true
  def custom_before_move
    @@test_allows_move
  end

  def to_s
    name
  end

  def recurse &block
    block.call self, lambda{
      self.children.each do |child|
        child.recurse &block
      end
    }
  end
end