require 'spec_helper'

module ChartMogul
  describe ImportApi do
    let(:credentials) { { account_token: "a_token", secret_key: "a secret" } }
    let(:client) { Client.new(credentials) }

    describe "list_data_sources" do

      let(:data_sources) {[
                            {
                              uuid: "ds_fef05d54-47b4-431b-aed2-eb6b9e545430",
                              name: "In-house billing",
                              created_at: "2016-01-10 15:34:05",
                              status: "never_imported"
                            },
                            {
                              uuid: "ds_ade45e52-47a4-231a-1ed2-eb6b9e541213",
                              name: "ChargeBee connection",
                              created_at: "2016-01-09 10:14:15",
                              status: "import_complete"
                            }
                          ]}
      before(:each) do
        stub_request(:get, request_stub_path(credentials, "/import/data_sources"))
          .to_return(status: 200, body: { data_sources: data_sources }.to_json)
      end

      subject { client.list_data_sources }

      it "should return all of the data sources" do
        result = subject
        data_sources.each_with_index do |data_source, i|
          expect(result[i].uuid).to eq(data_source[:uuid])
        end
      end
    end

    describe "#create_data_source" do

      let(:name) { "New Data Source" }
      let(:data_source) { {
                            uuid: "ds_fef05d54-47b4-431b-aed2-eb6b9e545430",
                            name: "In-house billing",
                            created_at: "2016-01-10 15:34:05",
                            status: "never_imported"
                        } }

      subject { client.create_data_source(name: name) }

      before(:each) do
        stub_request(:post, request_stub_path(credentials, "/import/data_sources"))
            .with(body: { name: name }.to_json)
            .to_return(body: data_source.to_json)
      end

      it "should return the created data source" do
        expect(subject.uuid).to eq(data_source[:uuid])
      end

      context "when name nil" do
        let(:name) { nil }

        it "should raise an ArgumentError" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

    end

    describe "list_customers" do

      let(:customers) {[
                         {
                           uuid: "cus_f466e33d-ff2b-4a11-8f85-417eb02157a7",
                           data_source_uuid: "ds_fef05d54-47b4-431b-aed2-eb6b9e545430",
                           external_id: "cus_0001",
                           name: "Adam Smith",
                           email: "adam@smith.com",
                           company: "",
                           country: "US",
                           state: "",
                           city: "New York",
                           zip: ""
                         },
                         {
                           uuid: "cus_ee325d54-7ab4-421b-cdb2-eb6b9e546034",
                           data_source_uuid: "ds_fef05d54-47b4-431b-aed2-eb6b9e545430",
                           external_id: "cus_0002",
                           name: "Alice",
                           email: "alice@acme.com",
                           company: "Acme inc.",
                           country: "",
                           state: "",
                           city: "",
                           zip: ""
                         }
                          ]}
      subject { client.list_customers }

      context "when don't filter by data_source_uuid" do
        before(:each) do
          stub_request(:get, request_stub_path(credentials, "/import/customers") + "?page_number=1")
            .to_return(status: 200, body: { customers: customers, current_page: 1, total_pages: 1 }.to_json)
        end

        it "should return all of the customers" do
          result = subject
          customers.each_with_index do |customer, i|
            expect(result[i].uuid).to eq(customer[:uuid])
          end
        end
      end

      context "when filter by data_source_uuid" do
        let(:data_source_uuid) { "ds_fef05d54-47b4-431b-aed2-eb6b9e545430"}

        before(:each) do
          stub_request(:get, request_stub_path(credentials, "/import/customers") + "?page_number=1&data_source_uuid=#{data_source_uuid}")
            .to_return(status: 200, body: { customers: customers, current_page: 1, total_pages: 1 }.to_json)
        end

        subject { client.list_customers(data_source_uuid: data_source_uuid) }

        it "should return results" do
          result = subject
          customers.each_with_index do |customer, i|
            expect(result[i].uuid).to eq(customer[:uuid])
          end
        end
      end
    end

    describe "#import_customer" do

      let(:args) {{
                    data_source_uuid: "ds_fef05d54-47b4-431b-aed2-eb6b9e545430",
                    external_id: "cus_0001",
                    name: "Adam Smith",
                    email: "adam@smith.com",
                    country: "US",
                    city: "New York"
                   }}

      let(:customer) {{
                       uuid: "cus_f466e33d-ff2b-4a11-8f85-417eb02157a7",
                       data_source_uuid: "ds_fef05d54-47b4-431b-aed2-eb6b9e545430",
                       external_id: "cus_0001",
                       name: "Adam Smith",
                       company: "",
                       email: "adam@smith.com",
                       city: "New York",
                       state: "",
                       country: "US",
                       zip: ""
                      }}

      subject { client.import_customer(args) }

      before(:each) do
        stub_request(:post, request_stub_path(credentials, "/import/customers"))
            .with(body: args.to_json)
            .to_return(body: customer.to_json)
      end

      it "should return the created customer" do
        expect(subject.uuid).to eq(customer[:uuid])
      end

      context "when missing data_source_uuid" do
        before(:each) do
          args.delete(:data_source_uuid)
        end
        it "should raise an ArgumentError" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context "when missing external_id" do
        before(:each) do
          args.delete(:external_id)
        end
        it "should raise an ArgumentError" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context "when missing name" do
        before(:each) do
          args.delete(:name)
        end
        it "should raise an ArgumentError" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

    end

    describe "list_subscriptions" do

      let(:subscriptions) {[
                     {
                             uuid: "sub_e6bc5407-e258-4de0-bb43-61faaf062035",
                             external_id: "sub_0001",
                             plan_uuid: "pl_eed05d54-75b4-431b-adb2-eb6b9e543206",
                             data_source_uuid: "ds_fef05d54-47b4-431b-aed2-eb6b9e545430",
                             cancellation_dates: []
                     },
                    ]}
      let(:customer_uuid) { random_string }
      before(:each) do
        stub_request(:get, request_stub_path(credentials, "/import/customers/#{customer_uuid}/subscriptions") + "?page_number=1")
          .to_return(status: 200, body: { subscriptions: subscriptions, current_page: 1, total_pages: 1, customer_uuid: customer_uuid }.to_json)
      end

      subject { client.list_subscriptions(customer_uuid) }

      it "should return all of the subscriptions" do
        result = subject
        subscriptions.each_with_index do |subscription, i|
          expect(result[i].uuid).to eq(subscription[:uuid])
        end
      end
    end

    describe "list_plans" do

      let(:plans) {[
                     {
                       uuid: "pl_eed05d54-75b4-431b-adb2-eb6b9e543206",
                       data_source_uuid: "ds_fef05d54-47b4-431b-aed2-eb6b9e545430",
                       name: "Bronze Plan",
                       interval_count: 1,
                       interval_unit: "month",
                       external_id: "plan_0001"
                     },
                     {
                       uuid: "pl_cdb35d54-75b4-431b-adb2-eb6b9e873425",
                       data_source_uuid: "ds_fef05d54-47b4-431b-aed2-eb6b9e545430",
                       name: "Silver Plan",
                       interval_count: 6,
                       interval_unit: "month",
                       external_id: "plan_0002"
                     },
                     {
                       uuid: "pl_ab225d54-7ab4-421b-cdb2-eb6b9e553462",
                       data_source_uuid: "ds_fef05d54-47b4-431b-aed2-eb6b9e545430",
                       name: "Gold Plan",
                       interval_count: 1,
                       interval_unit: "year",
                       external_id: "plan_0003"
                     }
                    ]}
      before(:each) do
        stub_request(:get, request_stub_path(credentials, "/import/plans") + "?page_number=1")
          .to_return(status: 200, body: { plans: plans, current_page: 1, total_pages: 1 }.to_json)
      end

      subject { client.list_plans }

      it "should return all of the plans" do
        result = subject
        plans.each_with_index do |plan, i|
          expect(result[i].uuid).to eq(plan[:uuid])
        end
      end
    end

    describe "#import_plan" do

      let(:args) {{
                   data_source_uuid: "ds_fef05d54-47b4-431b-aed2-eb6b9e545430",
                   name: "Bronze Plan",
                   interval_count: 1,
                   interval_unit: :month,
                   external_id: "plan_0001"
                 }}

      let(:plan) {{
                   uuid: "pl_eed05d54-75b4-431b-adb2-eb6b9e543206",
                   data_source_uuid: "ds_fef05d54-47b4-431b-aed2-eb6b9e545430",
                   name: "Bronze Plan",
                   interval_count: 1,
                   interval_unit: "month",
                   external_id: "plan_0001"
                  }}

      subject { client.import_plan(args) }

      before(:each) do
        stub_request(:post, request_stub_path(credentials, "/import/plans"))
            .with(body: args.to_json)
            .to_return(body: plan.to_json)
      end

      it "should return the created plan" do
        expect(subject.uuid).to eq(plan[:uuid])
      end

      context "when missing data_source_uuid" do
        before(:each) do
          args.delete(:data_source_uuid)
        end
        it "should raise an ArgumentError" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context "when missing interval_count" do
        before(:each) do
          args.delete(:interval_count)
        end
        it "should raise an ArgumentError" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context "when missing name" do
        before(:each) do
          args.delete(:name)
        end
        it "should raise an ArgumentError" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context "when interval_count not an integer" do
        before(:each) do
          args[:interval_count] = 123.0
        end
        it "should raise an ArgumentError" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context "when interval_unit not :day, :month or :year" do
        before(:each) do
          args[:interval_unit] = :bilge
        end
        it "should raise an ArgumentError" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end
    end

    describe "#import_invoices" do
      let(:args) { [
                       {
                          external_id: "INV0001",
                          date: Time.parse("2015-11-01 00:00:00"),
                          currency: "USD",
                          due_date: "2015-11-15 00:00:00",
                          line_items: [
                            {
                              type: "subscription",
                              subscription_external_id: "sub_0001",
                              plan_uuid:"pl_eed05d54-75b4-431b-adb2-eb6b9e543206",
                              service_period_start: Time.parse("2015-11-01 00:00:00"),
                              service_period_end: Time.parse("2015-12-01 00:00:00"),
                              amount_in_cents: 5000,
                              quantity: 1,
                              discount_code: "PSO86",
                              discount_amount_in_cents: 1000,
                              tax_amount_in_cents: 900
                            },
                            {
                              type: "one_time",
                              description: "Setup Fees",
                              amount_in_cents: 2500,
                              quantity: 1,
                              discount_code: "PSO86",
                              discount_amount_in_cents: 500,
                              tax_amount_in_cents: 450
                            }
                          ],
                          transactions: [
                            {
                              date: Time.parse("2015-11-05 00:14:23"),
                              type: "payment",
                              result: "successful"
                            }
                          ]
                       }
                     ]
                    }
      let(:invoices) {
                      [
                        {
                          uuid: "inv_565c73b2-85b9-49c9-a25e-2b7df6a677c9",
                          external_id: "INV0001",
                          date: "2015-11-01T00:00:00.000Z",
                          due_date: "2015-11-15T00:00:00.000Z",
                          currency: "USD",
                          line_items: [
                            {
                              uuid: "li_d72e6843-5793-41d0-bfdf-0269514c9c56",
                              external_id: nil,
                              type: "subscription",
                              subscription_uuid: "sub_e6bc5407-e258-4de0-bb43-61faaf062035",
                              plan_uuid: "pl_eed05d54-75b4-431b-adb2-eb6b9e543206",
                              prorated: false,
                              service_period_start: "2015-11-01T00:00:00.000Z",
                              service_period_end: "2015-12-01T00:00:00.000Z",
                              amount_in_cents: 5000,
                              quantity: 1,
                              discount_code: "PSO86",
                              discount_amount_in_cents: 1000,
                              tax_amount_in_cents: 900
                            },
                            {
                              uuid: "li_0cc8c112-beac-416d-af11-f35744ca4e83",
                              external_id: nil,
                              type: "one_time",
                              description: "Setup Fees",
                              amount_in_cents: 2500,
                              quantity: 1,
                              discount_code: "PSO86",
                              discount_amount_in_cents: 500,
                              tax_amount_in_cents: 450
                            }
                          ],
                          transactions: [
                            {
                              uuid: "tr_879d560a-1bec-41bb-986e-665e38a2f7bc",
                              external_id: nil,
                              type: "payment",
                              date: "2015-11-05T00:14:23.000Z",
                              result: "successful"
                            }
                          ]
                        }
                      ]
                    }

      let(:customer_id) { "cus_f466e33d-ff2b-4a11-8f85-417eb02157a7" }

      subject { client.import_invoices(customer_id, args) }

      before(:each) do
        stub_request(:post, request_stub_path(credentials, "/import/customers/#{customer_id}/invoices"))
            .to_return(body: { invoices: invoices }.to_json)
      end

      it "should return the created invoices" do
        result = subject
        invoices.each_with_index do |invoice, i|
          expect(result[i].uuid).to eq(invoice[:uuid])
          expect(result[i].line_items.count).to eq(invoice[:line_items].count)
        end
      end

    end

    describe "#list_invoices" do
      let(:customer_id) { "cus_f466e33d-ff2b-4a11-8f85-417eb02157a7" }

      let(:invoices) {
                      [
                        {
                          uuid: "inv_565c73b2-85b9-49c9-a25e-2b7df6a677c9",
                          external_id: "INV0001",
                          date: "2015-11-01T00:00:00.000Z",
                          due_date: "2015-11-15T00:00:00.000Z",
                          currency: "USD",
                          line_items: [
                            {
                              uuid: "li_d72e6843-5793-41d0-bfdf-0269514c9c56",
                              external_id: nil,
                              type: "subscription",
                              subscription_uuid: "sub_e6bc5407-e258-4de0-bb43-61faaf062035",
                              plan_uuid: "pl_eed05d54-75b4-431b-adb2-eb6b9e543206",
                              prorated: false,
                              service_period_start: "2015-11-01T00:00:00.000Z",
                              service_period_end: "2015-12-01T00:00:00.000Z",
                              amount_in_cents: 5000,
                              quantity: 1,
                              discount_code: "PSO86",
                              discount_amount_in_cents: 1000,
                              tax_amount_in_cents: 900
                            },
                            {
                              uuid: "li_0cc8c112-beac-416d-af11-f35744ca4e83",
                              external_id: nil,
                              type: "one_time",
                              description: "Setup Fees",
                              amount_in_cents: 2500,
                              quantity: 1,
                              discount_code: "PSO86",
                              discount_amount_in_cents: 500,
                              tax_amount_in_cents: 450
                            }
                          ],
                          transactions: [
                            {
                              uuid: "tr_879d560a-1bec-41bb-986e-665e38a2f7bc",
                              external_id: nil,
                              type: "payment",
                              date: "2015-11-05T00:14:23.000Z",
                              result: "successful"
                            }
                          ]
                        }
                      ]
                    }

      before(:each) do
        stub_request(:get, request_stub_path(credentials, "/import/customers/#{customer_id}/invoices") + "?page_number=1")
          .to_return(status: 200, body: { invoices: invoices, current_page: 1, total_pages: 1 }.to_json)
      end

      subject { client.list_invoices(customer_id) }

      it "should return all of the invoices" do
        result = subject
        invoices.each_with_index do |invoice, i|
          expect(result[i].uuid).to eq(invoice[:uuid])
        end
      end

    end
  end
end
