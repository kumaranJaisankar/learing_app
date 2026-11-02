class AddSimulatedPrivateKeyToAgentIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :agent_identities, :simulated_private_key, :text
  end
end
