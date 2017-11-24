module Spree
  module Admin
    ReportsController.class_eval do
      respond_to :html, :csv
      module SimpleReport
        def initialize
          ReportsController.add_available_report!(:total_sales_of_each_variant)
          ReportsController.add_available_report!(:total_sales_by_product)
          ReportsController.add_available_report!(:ten_days_order_count)
          ReportsController.add_available_report!(:thirty_days_order_count)
          ReportsController.add_available_report!(:stock_report)
          ReportsController.add_available_report!(:stockout_report)
          ReportsController.add_available_report!(:reimbursement_total)
          ReportsController.add_available_report!(:sales_total_net)         
          super
        end
      end
      prepend SimpleReport

      # load helper method to views & controller
      helper "spree/admin/simple_reports"
      include SimpleReportsHelper

      def total_sales_of_each_variant
        @variants = Variant.joins(:product, line_items: :order)
                    .select("spree_variants.id, spree_products.slug as productId, spree_products.name as name, sku, SUM(spree_line_items.quantity) as quantity, SUM((spree_line_items.price * spree_line_items.quantity) + spree_line_items.adjustment_total) as total_price")
                    .merge(Order.complete.completed_between(completed_at_gt, completed_at_lt))
                    .group("spree_variants.id, spree_products.id, spree_products.name")
        if supports_store_id? && store_id
          @variants = @variants.where("spree_orders.store_id" => store_id)
        end
      end

      def total_sales_by_product
        @products = Spree::Product.joins(:variants, line_items: :order)
                    .select('spree_products.id, spree_products.name, spree_products.slug, SUM(spree_line_items.quantity) as quantity, SUM((spree_line_items.price * spree_line_items.quantity) + spree_line_items.adjustment_total) as total_price')
                    .merge(Spree::Order.complete.completed_between(completed_at_gt, completed_at_lt))
                    .group('spree_products.id, spree_variants.id, spree_products.name')
                    .uniq
        if supports_store_id? && store_id
          @products = @products.where("spree_orders.store_id" => store_id)
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

      def sales_total_net
        sales_total
        @reimbursements = Reimbursement.where('created_at between ? and ?', params[:q][:completed_at_gt], params[:q][:completed_at_lt].present? ? params[:q][:completed_at_lt] : Time.now) 
        @reimbursements.each do |reimbursement|
          @totals[reimbursement.order.currency][:reimbursement_total] = ::Money.new(0, reimbursement.order.currency) unless @totals[reimbursement.order.currency][:reimbursement_total]
          @totals[reimbursement.order.currency][:sales_total_net] = ::Money.new(0, reimbursement.order.currency) unless @totals[reimbursement.order.currency][:sales_total_net]
          @totals[reimbursement.order.currency][:reimbursement_total] += reimbursement.total.to_money(reimbursement.order.currency)
          @totals[reimbursement.order.currency][:sales_total_net] = @totals[reimbursement.order.currency][:sales_total] - @totals[reimbursement.order.currency][:reimbursement_total]
        end
      end

      def reimbursement_total
        params[:created_at_gt] = '' unless params[:created_at_gt]
        params[:created_at_lt] = '' unless params[:created_at_lt]

        if params[:created_at_gt].blank?
          params[:created_at_gt] = Time.zone.now.beginning_of_month
        else
          params[:created_at_gt] = Time.zone.parse(params[:created_at_gt]).beginning_of_day rescue Time.zone.now.beginning_of_month
        end

        if params[:created_at_lt].blank?
          params[:created_at_lt] = Time.zone.now
        else
          params[:created_at_lt] = Time.zone.parse(params[:created_at_lt]).beginning_of_day rescue Time.zone.now
        end
        @reimbursements = Reimbursement.where('created_at between ? and ?', params[:created_at_gt], params[:created_at_lt]) 
        @totals = {}
        @reimbursements.each do |reimbursement|
          @totals[reimbursement.order.currency] = { reimbursement_total: ::Money.new(0, reimbursement.order.currency) } unless @totals[reimbursement.order.currency]
          @totals[reimbursement.order.currency][:reimbursement_total] += reimbursement.total.to_money(reimbursement.order.currency)
        end
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
