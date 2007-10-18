class Category < ActiveRecord::Base
  acts_as_nested_set
end