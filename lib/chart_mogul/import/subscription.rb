module ChartMogul
  module Import
    class Subscription

      attr_reader :uuid
      attr_reader :external_id
      attr_reader :plan_uuid
      attr_reader :data_source_uuid
      attr_reader :cancelation_dates

      def initialize(args)
        args.each_pair do |key, value|
          instance_variable_set("@#{key}", value)
        end
      end
    end
  end
end
