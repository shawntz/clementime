class AddBalancedTaSchedulingConfig < ActiveRecord::Migration[8.0]
  def change
    reversible do |dir|
      dir.up do
        # Add configuration for balanced TA scheduling
        # When enabled, students are distributed evenly across all TAs regardless of section assignment
        # Default: false (maintain traditional section-based scheduling)
        SystemConfig.create!(
          key: SystemConfig::BALANCED_TA_SCHEDULING,
          value: "false",
          config_type: "boolean",
          description: "Enable balanced randomization of students across all TAs (ignores section assignments for scheduling). Helps balance workload when sections have uneven enrollment."
        ) rescue ActiveRecord::RecordNotUnique
      end

      dir.down do
        SystemConfig.where(key: SystemConfig::BALANCED_TA_SCHEDULING).destroy_all
      end
    end
  end
end
