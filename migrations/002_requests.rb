Sequel.migration do
  change do
    create_table(:requests) do
      primary_key :id
      String :status, null: false
      String :login, null: false
      String :repo, null: false
      String :sha, null: false
      # remember add the timestamp of the pull_request
      index :login
      index :status
    end
  end
end
