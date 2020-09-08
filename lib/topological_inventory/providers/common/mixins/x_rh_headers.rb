module TopologicalInventory
  module Providers
    module Common
      module Mixins
        module XRhHeaders
          def account_number_by_identity(identity)
            return @account_number if @account_number
            return if identity.try(:[], 'x-rh-identity').nil?

            identity_hash = JSON.parse(Base64.decode64(identity['x-rh-identity']))
            @account_number = identity_hash.dig('identity', 'account_number')
          rescue JSON::ParserError => e
            logger.error_ext(operation, "Failed to parse identity header: #{e.message}")
            nil
          end

          def identity_by_account_number(account_number)
            @identity ||= {"x-rh-identity" => Base64.strict_encode64({"identity" => {"account_number" => account_number, "user" => {"is_org_admin" => true}}}.to_json)}
          end
        end
      end
    end
  end
end
