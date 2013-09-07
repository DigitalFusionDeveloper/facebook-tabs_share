module App
  module Document
    code_for 'app/document/to_csv' do
      def self.to_csv_rows(query = all, &block)
        rows = []
        keys = field_names

        block ? block.call(keys) : rows.push(keys)

        query.each do |doc|
          row = keys.map{|key| doc[key]}
          block ? block.call(row) : rows.push(row)
        end
        
        block ? nil : rows
      end

      def self.to_csv(query = all)
        require 'csv' unless defined?(CSV)

        CSV.generate do |csv|
          to_csv_rows(query) do |row|
            csv << row
          end
        end
      end
    end
  end
end
