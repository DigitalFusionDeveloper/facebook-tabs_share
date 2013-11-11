jQuery ->
    getLocations = (args) ->
        $('.location').remove()
        $('.load-more').hide()
        locator_message 'info', 'searching...'
        types = ($(type).val() for type in $("input[name='type']:checked"))
        args['type'] = types
        $.getJSON '/' + window.brand + '/locations', args, (locations) ->
            $('#locator_message').hide()

            if locations.length == 0
                locator_message 'info', 'We were unable to find a location near you.'
                $('#location').attr 'placeholder', 'Enter zip, city, or state'
            else
                $('#metaLocationResults')?.show?()
                $('.load-more').hide()
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
                    if $('#metaLocationResults').length is 0
                        $address.insertBefore '.load-more'
                    else
                        $address.insertBefore '#metaLocationResults'
                 if locations.length > 5
                    $('.load-more').show()
                    $('.load-more').click ->
                        $hidden = $('.location:hidden');
                        $hidden.slice(0,5).show();
                        $('.load-more').hide() if $hidden.length <= 5
                
    $('#current_location').click ->
        $('#location').attr 'placeholder', 'Finding your current location...'
        locator_message 'info', 'Finding your current location...'
        $(this).addClass('disabled')
        if geoPosition.init()   # Geolocation Initialization
            geoPosition.getCurrentPosition(geo_success,geo_error)
        else
            locator_message 'error', 'Unable to find your current location.'
            $('#location').attr 'placeholder', 'Enter zip, city, or state'
        false

    $('#requestCityBtn button')?.click ->
        window.location.replace('contact')

    geo_success = (p) ->
        c = p.coords
        getLocations { lat: c.latitude, lng: c.longitude }
        updateLocation  c.latitude, c.longitude
        $('#current_location').removeClass('disabled')

    geo_error = (p) ->
        locator_message 'error', 'Unable to find your current location.'
        $('#current_location').removeClass('disabled')

    updateLocation = (lat,lng) ->
        current_location = $('#location').val()
        $.getJSON '/api/geolocate', {location: (lat + ',' + lng) }, (response) ->
            if location = response.data.location
                # Geo responses can be slow, don't if the user has
                # already started typing
                if current_location == $('#location').val()
                    $('#location').val(location.city + ', ' + location.state)

    $('.find-location').submit ->
        if $('#location').val()
            address = $('#location').val()
            url     = "http://maps.google.com/maps/api/geocode/json"
            params  = {search: address, type: ['a','b']}

            $.ajax
              url      : url
              type     : 'GET'
              dataType : 'json'
              data     : {sensor : false, address : address}
              success  : (response) ->
                location = eval('response.results[0].geometry.location') || {}
                params['lat'] = location['lat']
                params['lng'] = location['lng']
                getLocations params
              error    :
                getLocations params
        else
            locator_message 'info', 'Please select "use current location" or enter a location and click "search."'
        false

    locator_message = (type,message) ->
        $lm = $('#locator_message')
        $lm.removeClass('alert-info alert-error').addClass('alert-' + type)
        $lm.html message
        $lm.show()
