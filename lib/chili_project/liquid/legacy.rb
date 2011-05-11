module ChiliProject
  module Liquid
    module Legacy
      @macros = {}
    
      def self.macros
        @macros
      end

      # "Runs" legacy macros by doing a gsub of their values to the new Liquid ones
      def self.run_macros(content)
        macros.each do |macro_name, macro|
          next unless macro[:match].present? && macro[:replace].present?
          content.gsub!(macro[:match]) do |match|
            # Use block form so $1 is set properly
            "{#{macro[:replace]} #{$1} #{macro[:replace]}}"
          end
        end
      end
    
      # Add support for a legacy macro syntax that was converted to liquid
      def self.add(name, liquid_type)
        case liquid_type
        when :tag
        
          @macros[name.to_s] = {
            :match => Regexp.new(/\{\{.(#{name}.*? )\}\}/),
            :replace => "%"
          }
        end
      
      end
    end
  end
end
