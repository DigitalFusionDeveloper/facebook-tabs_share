class FormsController < ::ApplicationController
##
#
  layout 'forms'

  prepend_view_path 'app/views/beers'

  before_filter 'set_beer'

##
#
  def rfi
    @rfi = RFIConducer.for(@beer, @beer.rfis.new, params[:rfi])

    return if request.get?

    if @rfi.save
      message.success("Thanks #{ @rfi.email }!")
    else
      message.failure("Sorry, something went wrong - Please try again later.")
    end
  end

protected
##
#
  def set_beer
    @beer = Beer.find_by!(:slug => params[:slug])
  end

##
#
  class RFIConducer < ::Dao::Conducer
    model_name :rfi

    attr_accessor :beer
    attr_accessor :rfi

    def initialize(beer, rfi, params = {})
      @beer = beer
      @rfi = rfi

      update_attributes(
        @rfi.attributes
      )

      update_attributes(
        params
      )
    end

    def save
      @rfi.beer = @beer

      attributes.each do |attr, value|
        @rfi[attr] = value
      end

      if @rfi.save
        true
      else
        errors.relay(@rfi.errors)
        false
      end
    end
  end
end
