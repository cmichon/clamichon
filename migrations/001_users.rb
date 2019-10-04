Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      String :login, unique: true, null: false
    end
  end
end
