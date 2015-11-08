module Spree
  module Admin
    ReportsController.class_eval do
      respond_to :html, :csv
      module SimpleReport
        def initialize
          ReportsController.add_available_report!(:total_sales_of_each_product)
          ReportsController.add_available_report!(:ten_days_order_count)
          ReportsController.add_available_report!(:thirty_days_order_count)
          ReportsController.add_available_report!(:stock_report)
          ReportsController.add_available_report!(:stockout_report)
          super
        end
      end
      prepend SimpleReport

      # load helper method to views & controller
      helper "spree/admin/simple_reports"
      include SimpleReportsHelper

      def total_sales_of_each_product
        @variants = Variant.joins(:product, line_items: :order)
                    .select("spree_variants.id, spree_products.slug as product_id, spree_products.name as name, sku, SUM(spree_line_items.quantity) as quantity, SUM((spree_line_items.price * spree_line_items.quantity) + spree_line_items.adjustment_total) as total_price")
                    .merge(Order.complete.completed_between(completed_at_gt, completed_at_lt))
                    .group("spree_variants.id, spree_products.id, spree_products.name")
        if supports_store_id? && store_id
          @variants = @variants.where("spree_orders.store_id" => store_id)
        end
      end

      def ten_days_order_count
        @counts = n_day_order_count(10)
      end

      def thirty_days_order_count
        @counts = n_day_order_count(30)
      end

      def stock_report
        orderby='sum(spree_stock_items.count_on_hand),spree_products.name,spree_variants.sku'
        @variants_before_paginate=Variant.eager_load(:stock_items,:product)
          .select('spree_products.id,sum(spree_stock_items.count_on_hand) as stock,spree_variants.id')
          .where(track_inventory: 1).where.not(spree_stock_items: {count_on_hand: nil})
          .group('spree_variants.id')
          .order(orderby)
        @variants = stock_paginate
      end

      def stockout_report
        orderby="sum(spree_stock_items.count_on_hand),spree_products.name,spree_variants.sku"
        @variants_before_paginate=Variant.eager_load(:stock_items,:product)
          .select('spree_products.id,sum(spree_stock_items.count_on_hand) as stock,spree_variants.id')
          .where(track_inventory: 1).where.not(spree_stock_items: {count_on_hand: nil})
          .group('spree_variants.id')
          .having('sum(spree_stock_items.count_on_hand)<=0')
          .order(orderby)
        @variants = stock_paginate
      end

      private
      def stock_paginate
        if supports_store_id? && store_id
          @variants_before_paginate = @variants_before_paginate.where("spree_orders.store_id" => store_id).order(orderby)
        end
        if @variants_before_paginate.empty?
          flash[:notice] = Spree.t(:stock_report_empty)
        end
        @variants = @variants_before_paginate.page(params[:page]).per(params[:per_page] || 20)
      end
      def n_day_order_count(n)
        counts = []
        n.times do |i|
          counts << {
            number: i,
            date: i.days.ago.to_date,
            count: Order.complete
              .where("completed_at >= ?",i.days.ago.beginning_of_day)
              .where("completed_at <= ?",i.days.ago.end_of_day).count
          }
        end
        counts
      end

      def store_id
        params[:store_id].presence
      end

      def completed_at_gt
        params[:completed_at_gt] = if params[:completed_at_gt].blank?
          Date.today.beginning_of_month
        else
          Date.parse(params[:completed_at_gt])
        end
      end

      def completed_at_lt
        params[:completed_at_lt] = if params[:completed_at_lt].blank?
          Date.today
        else
          Date.parse(params[:completed_at_lt])
        end
      end
    end
  end
end
