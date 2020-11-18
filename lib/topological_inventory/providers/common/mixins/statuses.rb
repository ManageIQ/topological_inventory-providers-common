module TopologicalInventory
  module Providers
    module Common
      module Mixins
        module Statuses
          def operation_status
            return @statuses if @statuses.present?

            @statuses = {}
            %i[success error skipped not_implemented].each do |status|
              @statuses[status] = status.to_s
            end
            @statuses
          end
        end
      end
    end
  end
end
