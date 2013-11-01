jQuery ->
    getLocations = (args) ->
        $('.location').remove()
        $('.load-more').hide()
        locator_message 'info', 'searching...'
        $.getJSON '/' + window.brand + '/locations', args, (locations) ->
            $('#locator_message').hide()

            if locations.length == 0
                locator_message 'info', 'We were unable to find a location near you.'

            for location,i in locations
                $address = $('#locations .template').clone()
                $address.removeClass 'template'
                $address.addClass 'location'
                $address.data('map_url',location.map_url)
                $address.click ->
                    $('#location_details .name').text($(this).find('.name').text())
                    $('#location_details .modal-body .map').attr('src',$(this).data('map_url'))
                    htmlCopy = $(this).clone()
                    htmlCopy.children('.viewMap').remove()
                    htmlCopy.css('cursor', 'default')
                    $('#location_details .modal-body .address').html(htmlCopy)
                    $('#location_details').modal('show')
                $address.find('.name').text(location.title)
                $address.find('.address').text(location.address)
                $address.find('.city').text(location.city)
                $address.find('.state').text(location.state)
                $address.find('.zipcode').text(location.zipcode)
                $address.show() if i < 5
                $address.insertBefore '.load-more'
             if locations.length > 5
                $('.load-more').show()
                $('.load-more').click ->
                    $hidden = $('.location:hidden');
                    $hidden.slice(0,5).show();
                    $('.load-more').hide() if $hidden.length <= 5
                
    $('#current_location').click ->
        locator_message 'info', 'finding your location...'
        $(this).addClass('disabled')
        if geoPosition.init()   # Geolocation Initialization
            geoPosition.getCurrentPosition(geo_success,geo_error)
        else
            locator_message 'error', 'Unable to find your current location.'
        false

    geo_success = (p) ->
        c = p.coords
        getLocations { lat: c.latitude, lng: c.longitude }
        $('#current_location').removeClass('disabled')

    geo_error = (p) ->
        locator_message 'error', 'Unable to find your current location.'
        $('#current_location').removeClass('disabled')

    $('.find-location').submit ->
        if $('#location').val()
            getLocations { location_string: $('#location').val() }
        else
            locator_message 'info', 'Please select "use current location" or enter a location and click "search."'
        false

    locator_message = (type,message) ->
        $lm = $('#locator_message')
        $lm.removeClass('alert-info alert-error').addClass('alert-' + type)
        $lm.html message
        $lm.show()
