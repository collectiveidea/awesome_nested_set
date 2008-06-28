unless defined? ActiveRecord::NamedScope
  require 'awesome_nested_set/named_scope'
  ActiveRecord::Base.class_eval do
    include CollectiveIdea::NamedScope
  end
end

require 'awesome_nested_set'

ActiveRecord::Base.class_eval do
  include CollectiveIdea::Acts::NestedSet
end

if defined?(ActionView)
  require 'awesome_nested_set/helper'
  ActionView::Base.class_eval do
    include CollectiveIdea::Acts::NestedSet::Helper
  end
end