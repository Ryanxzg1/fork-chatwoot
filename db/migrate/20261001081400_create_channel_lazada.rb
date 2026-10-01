class CreateChannelLazada < ActiveRecord::Migration[7.1]
  def change
    create_table :channel_lazada do |t|
      t.integer :account_id, null: false
      t.string :seller_id, null: false
      t.string :app_key, null: false
      t.string :app_secret, null: false
      t.string :access_token, null: false
      t.datetime :expires_at, null: false
      t.string :refresh_token, null: false
      t.datetime :refresh_token_expires_at, null: false
      t.string :environment, default: 'sandbox', null: false
      t.string :provider_name, default: 'Lazada'
      t.timestamps
    end

    add_index :channel_lazada, [:account_id, :seller_id], unique: true
    add_index :channel_lazada, :seller_id, unique: true
  end
end
