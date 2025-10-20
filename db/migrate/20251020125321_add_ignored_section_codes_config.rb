class AddIgnoredSectionCodesConfig < ActiveRecord::Migration[8.0]
  def change
    reversible do |dir|
      dir.up do
        # Add configuration for section codes to ignore during roster import
        # Default: ["01"] - filters out lecture sections at Stanford
        # Can be customized for other institutions (e.g., ["01", "00"])
        SystemConfig.create!(
          key: SystemConfig::IGNORED_SECTION_CODES,
          value: [ "01" ].to_json,
          config_type: "json",
          description: "Section codes to ignore during Canvas roster import (e.g., lecture sections). Default: [\"01\"] for Stanford."
        ) rescue ActiveRecord::RecordNotUnique
      end

      dir.down do
        SystemConfig.where(key: SystemConfig::IGNORED_SECTION_CODES).destroy_all
      end
    end
  end
end
