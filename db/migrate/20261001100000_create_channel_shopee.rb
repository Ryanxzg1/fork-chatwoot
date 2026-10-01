class CreateChannelShopee < ActiveRecord::Migration[7.1]
  def change
    create_table :channel_shopee do |t|
      t.integer :account_id, null: false
      t.string :shop_id, null: false
      t.string :partner_id, null: false
      t.string :partner_key, null: false
      t.string :access_token, null: false
      t.datetime :expires_at, null: false
      t.string :refresh_token, null: false
      t.datetime :refresh_token_expires_at, null: false
      t.string :environment, default: 'sandbox', null: false
      t.string :provider_name, default: 'Shopee'
      t.timestamps
    end

    add_index :channel_shopee, [:account_id, :shop_id], unique: true
    add_index :channel_shopee, :shop_id
  end
end
