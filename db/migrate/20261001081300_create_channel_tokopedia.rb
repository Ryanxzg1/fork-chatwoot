class CreateChannelTokopedia < ActiveRecord::Migration[7.1]
  def change
    create_table :channel_tokopedia do |t|
      t.integer :account_id, null: false
      t.string :shop_id, null: false
      t.string :client_id, null: false
      t.string :client_secret, null: false
      t.string :access_token, null: false
      t.datetime :expires_at, null: false
      t.string :refresh_token, null: false
      t.datetime :refresh_token_expires_at, null: false
      t.string :environment, default: 'sandbox', null: false
      t.string :provider_name, default: 'Tokopedia'
      t.timestamps
    end

    add_index :channel_tokopedia, [:account_id, :shop_id], unique: true
    add_index :channel_tokopedia, :shop_id, unique: true
  end
end
