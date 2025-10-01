module Api
  class BaseController < ApplicationController
    include Authenticable
  end
end
