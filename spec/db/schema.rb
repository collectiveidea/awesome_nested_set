ActiveRecord::Schema.define(:version => 0) do

  create_table :default_scoped_models, :force => true do |t|
    t.column :name, :string
    t.column :parent_id, :integer
    t.column :lft, :integer
    t.column :rgt, :integer
    t.column :depth, :integer
    t.column :draft, :boolean, default: false
  end

  create_table :categories, :force => true do |t|
    t.column :name, :string
    t.column :parent_id, :integer
    t.column :lft, :integer
    t.column :rgt, :integer
    t.column :depth, :integer
    t.column :organization_id, :integer
  end

  create_table :departments, :force => true do |t|
    t.column :name, :string
  end

  create_table :notes, :force => true do |t|
    t.column :body, :text
    t.column :parent_id, :integer
    t.column :lft, :integer
    t.column :rgt, :integer
    t.column :depth, :integer
    t.column :notable_id, :integer
    t.column :notable_type, :string
    t.column :user_id, :integer
  end

  create_table :renamed_columns, :force => true do |t|
    t.column :name, :string
    t.column :mother_id, :integer
    t.column :red, :integer
    t.column :black, :integer
    t.column :pitch, :integer
  end

  create_table :things, :force => true do |t|
    t.column :body, :text
    t.column :parent_id, :integer
    t.column :lft, :integer
    t.column :rgt, :integer
    t.column :depth, :integer
    t.column :children_count, :integer, null: false, default: 0
  end

  create_table :brokens, :force => true do |t|
    t.column :name, :string
    t.column :parent_id, :integer
    t.column :lft, :integer
    t.column :rgt, :integer
    t.column :depth, :integer
  end

  create_table :orders, :force => true do |t|
    t.column :name, :string
    t.column :parent_id, :integer
    t.column :lft, :integer
    t.column :rgt, :integer
    t.column :depth, :integer
  end

  create_table :positions, :force => true do |t|
    t.column :name, :string
    t.column :parent_id, :integer
    t.column :lft, :integer
    t.column :rgt, :integer
    t.column :depth, :integer
    t.column :position, :integer
  end

  create_table :no_depths, :force => true do |t|
    t.column :name, :string
    t.column :parent_id, :integer
    t.column :lft, :integer
    t.column :rgt, :integer
  end

  create_table :single_table_inheritance, :force => true do |t|
    t.column :type, :string
    t.column :name, :string
    t.column :parent_id, :integer
    t.column :lft, :integer
    t.column :rgt, :integer
    t.column :children_count, :integer, null: false, default: 0
  end

  create_table :users, :force => true do |t|
    t.column :uuid, :string
    t.column :name, :string
    t.column :parent_uuid, :string
    t.column :lft, :integer
    t.column :rgt, :integer
    t.column :depth, :integer
    t.column :organization_id, :integer
  end
end
