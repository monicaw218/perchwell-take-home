class ClientsController < ApplicationController
  def index
    clients = Client.order(:name).select(:id, :name)
    render json: clients
  end
end
