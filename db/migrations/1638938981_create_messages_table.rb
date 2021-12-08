Sequel.migration do
  up do
    create_table(:messages) do
      primary_key :id
      String :from, null: false, index: true
      String :to, null: false, index: true
      Text :body, null: false, index: true
    end
  end

  down do
    drop_table(:messages)
  end
end
