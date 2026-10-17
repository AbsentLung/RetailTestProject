class CreateCsvImports < ActiveRecord::Migration[7.1]
  def change
    create_table :csv_imports do |t|
      t.string :checksum, null: false
      t.integer :row_count, null: false

      t.timestamps
    end
    add_index :csv_imports, :checksum, unique: true
  end
end
