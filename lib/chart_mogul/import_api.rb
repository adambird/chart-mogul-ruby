require_relative 'import/customer'
require_relative 'import/data_source'
require_relative 'import/plan'
require_relative 'import/invoice'

module ChartMogul
  module ImportApi
    include Assertive

    # Public - list DataSources
    #
    # Returns an Array of ChartMogul::Import::DataSource
    def list_data_sources
      response = connection.get("/v1/import/data_sources")
      preprocess_response(response)[:data_sources]
        .map { |ds| Import::DataSource.new(ds) }
    end

    # Public - create a DataSource
    #
    # args   - Hash of params only :name is supported
    #          {
    #            name: "Name of data source"
    #          }
    #
    # Returns a ChartMogul::Import::DataSource
    def create_data_source(args)
      refute_blank! args[:name], :name

      response = connection.post do |request|
        request.url "/v1/import/data_sources"
        request.headers['Content-Type'] = "application/json"
        request.body = args.to_json
      end

      Import::DataSource.new(preprocess_response(response))
    end

    # Public - purge all data for a DataSource
    #          super dangerous
    #
    # Returns nothing but an empty hole where your data was!
    def purge_data_source!(data_source_uuid)
      response = connection.delete do |request|
        request.url "/v1/import/data_sources/#{data_source_uuid}/erase_data"
        request.headers['Content-Type'] = "application/json"
        request.body = { confirm: 1 }.to_json
      end
      response.status == 202
    end

    # Public - list all Customers.
    #          this will page through all customers see #list_customers_each
    #          for iterator method to prevent loading the whole array in
    #          memory
    #
    # options - see #list_customers_each
    #
    # Returns an Array of ChartMogul::Import::Customer
    def list_customers(options={})
      customers = []
      list_customers_each(options) { |c| customers << c }
      customers
    end

    # Public    - iterate through all customers
    #
    # options   - Hash of filter options
    #             :data_source_uuid
    #
    # Returns an Enumerable that will yield a ChartMogul::Import::Customer for
    # each record
    def list_customers_each(options={}, &block)
      params = { page_number: 1 }
      params[:data_source_uuid] = options[:data_source_uuid] if options[:data_source_uuid]

      paged_get("/v1/import/customers", params, :customers) do |customers|
        customers.each do |customer|
          yield Import::Customer.new(customer)
        end
      end
    end

    # Public - import a Customer
    #
    # args   - Hash of params see https://dev.chartmogul.com/docs/customers
    #          Mandatory: :data_source_uuid, :external_id, :name
    #
    # Returns a ChartMogul::Import::Customer
    def import_customer(args)
      [:data_source_uuid, :external_id, :name].each do |attribute|
        refute_blank! args[attribute], attribute
      end

      # ChartMogul API will 500 if nill keys are sent
      args.keys.each do |key|
        refute! args[key].nil?, "nil keys not supported [#{key}]"
      end

      response = connection.post do |request|
        request.url "/v1/import/customers"
        request.headers['Content-Type'] = "application/json"
        request.body = args.to_json
      end

      Import::Customer.new(preprocess_response(response))
    end

    # Public - list all Plans.
    #          this will page through all plans see #list_plans_each
    #          for iterator method to prevent loading the whole array in
    #          memory
    #
    # options - see #list_plans_each
    #
    # Returns an Array of ChartMogul::Import::Plan
    def list_plans(options={})
      plans = []
      list_plans_each(options) { |p| plans << p }
      plans
    end

    # Public    - iterate through all plans
    #
    # options   - Hash of filter options
    #             :data_source_uuid
    #
    # Returns an Enumerable that will yield a ChartMogul::Import::Plan for
    # each record
    def list_plans_each(options={}, &block)
      params = { page_number: 1 }
      params[:data_source_uuid] = options[:data_source_uuid] if options[:data_source_uuid]

      paged_get("/v1/import/plans", params, :plans) do |plans|
        plans.each do |plan|
          yield Import::Plan.new(plan)
        end
      end
    end

    # Public - import a Plan
    #
    # args   - Hash of params see https://dev.chartmogul.com/docs/plans
    #          Mandatory: :data_source_uuid, :name, :interval_count, :interval_unit
    #
    # Returns a ChartMogul::Import::Plan
    def import_plan(args)
      [:data_source_uuid, :name, :interval_unit, :interval_count].each do |attribute|
        refute_blank! args[attribute], attribute
      end
      assert! (args[:interval_count].is_a?(Integer) && args[:interval_count] > 0), "interval_count must be an integer greater than zero"
      assert! [:day, :month, :year].include?(args[:interval_unit].to_sym), "interval_unit must be one of :day, :month, :year"

      response = connection.post do |request|
        request.url "/v1/import/plans"
        request.headers['Content-Type'] = "application/json"
        request.body = args.to_json
      end

      Import::Plan.new(preprocess_response(response))
    end

    # Public      - import a single Invoice. Convenience method that
    #               maps the output (and validation errors) to a single operation
    #
    # customer_id - ChartMogul id for the customer
    # invoice     - Hash of params see https://dev.chartmogul.com/docs/invoices
    #               See invoice_invoices for mandatory attributes
    #
    # Returns an Array of ChartMogul::Import::Invoice
    def import_invoice(customer_id, invoice)
      invoices = import_invoices(customer_id, [ invoice ])
      invoices.first

    rescue ChartMogul::Client::ValidationError => e
      # restructure ValidationError to map the single invoice error that was returned
      if e.body[:invoices]
        raise ChartMogul::Client::ValidationError.new(e.body[:invoices].first)
      else
        raise
      end
    end

    # Public      - import Invoices
    #
    # customer_id - ChartMogul id for the customer
    # invoices    - Array of Hash of params see https://dev.chartmogul.com/docs/invoices
    #               Mandatory: :external_id, :date, :currency, :line_items
    #
    # Returns an Array of ChartMogul::Import::Invoice
    def import_invoices(customer_id, invoices)
      refute_blank! customer_id, "customer_id"
      refute! invoices.nil? && invoices.empty?, "invoices required"

      args = { invoices: invoices }

      args[:invoices].each do |invoice|
        [:external_id, :date, :currency].each do |attribute|
          refute_blank! invoice[attribute], attribute
        end

        invoice[:date] = format_datetime(invoice[:date])

        assert! invoice[:line_items] && invoice[:line_items].any?, "line_items is required"

        invoice[:line_items].each do |line_item|
          line_item[:service_period_start] = format_datetime(line_item[:service_period_start]) if line_item[:service_period_start]
          line_item[:service_period_end] = format_datetime(line_item[:service_period_end]) if line_item[:service_period_end]
        end

      end

      response = connection.post do |request|
        request.url "/v1/import/customers/#{customer_id}/invoices"
        request.headers['Content-Type'] = "application/json"
        request.body = args.to_json
      end

      preprocess_response(response)[:invoices].map { |i| Import::Invoice.new(i) }
    end

  end
end