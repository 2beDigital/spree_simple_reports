Spree::Core::Engine.routes.draw do
  namespace :admin do
    resources :reports, only: [:index] do
      collection do
        get :total_sales_of_each_variant
        post :total_sales_of_each_variant
        get :ten_days_order_count
        get :thirty_days_order_count
        get :stock_report
        post :stock_report
        get :stockout_report
        post :stockout_report
        get :sales_total_net
        post :sales_total_net
        get :total_sales_by_product
        post :total_sales_by_product
        get :reimbursement_total
        post :reimbursement_total
      end
    end
  end
end
