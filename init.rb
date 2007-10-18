require 'awesome_nested_set'
require 'awesome_nested_set_helper'

ActiveRecord::Base.class_eval do
  include CollectiveIdea::Acts::NestedSet
end

ActionView::Base.class_eval do
  include CollectiveIdea::Acts::NestedSetHelper
end