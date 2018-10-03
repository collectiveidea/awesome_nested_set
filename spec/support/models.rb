class Note < ActiveRecord::Base
  acts_as_nested_set :scope => [:notable_id, :notable_type]

  belongs_to :user, inverse_of: :notes
end

class DefaultScopedModel < ActiveRecord::Base
  acts_as_nested_set
end

class Default < ActiveRecord::Base
  self.table_name = 'categories'
  acts_as_nested_set
end

class ScopedCategory < ActiveRecord::Base
  self.table_name = 'categories'
  acts_as_nested_set :scope => :organization
end

class ScopedColumnCategory < ActiveRecord::Base
  self.table_name = 'categories'
  acts_as_nested_set :scope => {:column_name => :organization}
end

class OrderedCategory < ActiveRecord::Base
  self.table_name = 'categories'
  acts_as_nested_set :order_column => 'name'
end

class RenamedColumns < ActiveRecord::Base
  acts_as_nested_set :parent_column => 'mother_id',
                     :left_column => 'red',
                     :right_column => 'black',
                     :depth_column => 'pitch'
end

class Category < ActiveRecord::Base
  acts_as_nested_set

  validates_presence_of :name

  # Setup a callback that we can switch to true or false per-test
  set_callback :move, :before, :custom_before_move
  cattr_accessor :test_allows_move
  @@test_allows_move = true
  def custom_before_move
    if !@@test_allows_move
      if Rails::VERSION::MAJOR < 5
        false
      else
        throw :abort
      end
    end
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

class Thing < ActiveRecord::Base
  acts_as_nested_set :counter_cache => 'children_count'
end

class DefaultWithCallbacks < ActiveRecord::Base

  self.table_name = 'categories'

  attr_accessor :before_add, :after_add, :before_remove, :after_remove

  acts_as_nested_set :before_add => :do_before_add_stuff,
    :after_add     => :do_after_add_stuff,
    :before_remove => :do_before_remove_stuff,
    :after_remove  => :do_after_remove_stuff

  private

    [ :before_add, :after_add, :before_remove, :after_remove ].each do |hook_name|
      define_method "do_#{hook_name}_stuff" do |child_node|
        self.send("#{hook_name}=", child_node)
      end
    end

end

class Broken < ActiveRecord::Base
  acts_as_nested_set
end

class Order < ActiveRecord::Base
  acts_as_nested_set

  default_scope -> { order(name: :asc) }
end

class Position < ActiveRecord::Base
  acts_as_nested_set

  default_scope -> { order(position: :asc) }
end

class NoDepth < ActiveRecord::Base
  acts_as_nested_set
end

class User < ActiveRecord::Base
  acts_as_nested_set :parent_column => 'parent_uuid', :primary_column => 'uuid'

  validates_presence_of :name
  validates_presence_of :uuid
  validates_uniqueness_of :uuid

  after_initialize :ensure_uuid

  has_many :notes, dependent: :destroy, inverse_of: :user

  # Setup a callback that we can switch to true or false per-test
  set_callback :move, :before, :custom_before_move
  cattr_accessor :test_allows_move
  @@test_allows_move = true
  def custom_before_move
    if !@@test_allows_move
      if Rails::VERSION::MAJOR < 5
        false
      else
        throw :abort
      end
    end
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

  def ensure_uuid
    self.uuid ||= SecureRandom.hex
  end
end

class ScopedUser < ActiveRecord::Base
  self.table_name = 'users'
  acts_as_nested_set :parent_column => 'parent_uuid', :primary_column => 'uuid', :scope => :organization
end

class Superclass < ActiveRecord::Base
  acts_as_nested_set
  self.table_name = 'single_table_inheritance'
end

class Subclass1 < Superclass
end

class Subclass2 < Superclass
end
