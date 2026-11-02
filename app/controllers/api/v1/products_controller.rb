module Api
  module V1
    class ProductsController < ActionController::API
      def index
        products = Product.all.order(:id)
        render json: products.as_json(only: [:id, :name, :sku, :description, :price, :stock])
      end

      def show
        product = Product.find_by(sku: params[:id]) || Product.find_by(id: params[:id])
        if product
          render json: product.as_json(only: [:id, :name, :sku, :description, :price, :stock])
        else
          render json: { error: "Product not found" }, status: :not_found
        end
      end
    end
  end
end
