class CreateEvents < ActiveRecord::Migration[4.2]
  def change
    create_table :events do |t|
      t.string :name
      t.datetime :start
      t.string :creator
      t.string :link
      t.string :status
      t.string :calendar
      t.references :user

      t.timestamps
    end
  end
end
