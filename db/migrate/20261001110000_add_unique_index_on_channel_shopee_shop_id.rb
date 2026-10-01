# frozen_string_literal: true

class AddUniqueIndexOnChannelShopeeShopId < ActiveRecord::Migration[7.1]
  def change
    remove_index :channel_shopee, :shop_id
    add_index :channel_shopee, :shop_id, unique: true
  end
end
