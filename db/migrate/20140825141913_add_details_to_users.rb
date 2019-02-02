class AddDetailsToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :picture, :string
    add_column :users, :token, :string
    add_column :users, :refresh_token, :string
  end
end
