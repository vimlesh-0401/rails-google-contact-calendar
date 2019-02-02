class CreateContacts < ActiveRecord::Migration[4.2]
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
