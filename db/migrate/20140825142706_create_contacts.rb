class CreateContacts < ActiveRecord::Migration
  def change
    create_table :contacts do |t|
      t.string :name
      t.string :email
      t.string :picture
      t.string :tel
      t.belongs_to :user
    end
  end
end
