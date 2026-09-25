class AddAccountStatusLastActivityAtIndexToConversations < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # Optimizes default conversation list sorting by last_activity_at desc in ConversationFinder,
    # preventing costly in-memory / disk merge sorts on high-volume accounts.
    add_index :conversations, [:account_id, :status, :last_activity_at],
              order: { last_activity_at: :desc },
              name: 'index_conversations_on_account_id_status_last_activity_at',
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :conversations,
                 name: 'index_conversations_on_account_id_status_last_activity_at',
                 algorithm: :concurrently,
                 if_exists: true
  end
end
