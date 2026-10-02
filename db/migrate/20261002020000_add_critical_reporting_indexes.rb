class AddCriticalReportingIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # 1. Composite index on csat_survey_responses for date range filtering in CSAT reports
    add_index :csat_survey_responses, [:account_id, :created_at],
              name: 'index_csat_survey_responses_on_account_id_and_created_at',
              algorithm: :concurrently,
              if_not_exists: true

    # 2. Composite index on conversations for total conversation counts by date range
    add_index :conversations, [:account_id, :created_at],
              name: 'index_conversations_on_account_id_and_created_at',
              algorithm: :concurrently,
              if_not_exists: true

    # 3. Composite index on reporting_events for agent performance reports
    add_index :reporting_events, [:account_id, :user_id, :created_at],
              name: 'index_reporting_events_on_account_user_created_at',
              algorithm: :concurrently,
              if_not_exists: true

    # 4. Remove redundant single-column index on reporting_events(account_id)
    # covered by reporting_events__account_id__name__created_at
    remove_index :reporting_events,
                 name: 'index_reporting_events_on_account_id',
                 algorithm: :concurrently,
                 if_exists: true
  end

  def down
    add_index :reporting_events, :account_id,
              name: 'index_reporting_events_on_account_id',
              algorithm: :concurrently,
              if_not_exists: true

    remove_index :reporting_events,
                 name: 'index_reporting_events_on_account_user_created_at',
                 algorithm: :concurrently,
                 if_exists: true

    remove_index :conversations,
                 name: 'index_conversations_on_account_id_and_created_at',
                 algorithm: :concurrently,
                 if_exists: true

    remove_index :csat_survey_responses,
                 name: 'index_csat_survey_responses_on_account_id_and_created_at',
                 algorithm: :concurrently,
                 if_exists: true
  end
end
