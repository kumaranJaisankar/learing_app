class CreateUnikeySchema < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :sku, null: false, index: { unique: true }
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :stock, default: 100, null: false

      t.timestamps
    end

    create_table :agent_identities do |t|
      t.string :domain, null: false, index: { unique: true }
      t.string :selector, default: "unikey", null: false
      t.text :public_key, null: false
      t.decimal :authorized_budget, precision: 10, scale: 2, default: 500.0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    create_table :trust_packet_ledgers do |t|
      t.string :packet_id, null: false, index: { unique: true }
      t.string :signer_domain, null: false
      t.string :subject, null: false
      t.string :action, null: false
      t.string :status, null: false # "verified", "rejected"
      t.string :failure_reason
      t.string :payload_digest
      t.text :raw_packet, null: false
      t.datetime :verified_at

      t.timestamps
    end

    create_table :orders do |t|
      t.references :product, null: false, foreign_key: true
      t.references :agent_identity, foreign_key: true
      t.references :trust_packet_ledger, null: false, foreign_key: true
      t.integer :quantity, default: 1, null: false
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :total_amount, precision: 10, scale: 2, null: false
      t.string :status, default: "fulfilled", null: false
      t.text :response_packet

      t.timestamps
    end
  end
end
