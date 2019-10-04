Sequel.migration do
  change do
    create_table(:checks) do
      primary_key :id
      String :login, null: false
      String :repo, null: false
      String :sha, null: false
      index :login
    end
  end
end
