class Category < ActiveRecord::Base
  acts_as_nested_set
  
  def recurse &block
    block.call self, lambda{
      self.children.each do |child|
        child.recurse &block
      end
    }
  end
end