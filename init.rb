unless defined? ActiveRecord::NamedScope
  require 'awesome_nested_set/named_scope'
  ActiveRecord::Base.class_eval do
    include ActiveRecord::NamedScope
  end
end

require 'awesome_nested_set'
require 'awesome_nested_set/helper'

ActiveRecord::Base.class_eval do
  include CollectiveIdea::Acts::NestedSet
end

ActionView::Base.class_eval do
  include CollectiveIdea::Acts::NestedSet::Helper
end