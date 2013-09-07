class UploadsController < ApplicationController

  def show
    begin
    # CORS request
    #
      headers['Access-Control-Allow-Origin']      = '*'
      headers['Access-Control-Allow-Methods']     = 'GET, POST, OPTIONS'
      headers['Access-Control-Max-Age']           = '1728000'
      headers['Access-Control-Allow-Credentials'] = 'true'

      if request.options?
        render(:nothing => true)
        return
      end

    # find the upload record
    #
      upload = Upload.find(params[:id])

    # domain level validation - can the user view this?
    #
      unless validate_acl?(upload)
        head(:forbidden)
        return
      end

    # the url might specify a variant (small|medium|etc)
    #
      variant = nil

      if params[:variant]
        variant = upload.variants.find_by_name(params[:variant])

        if variant.nil?
          raise(:not_found) if Upload.config.get(:raise_on_missing_variant)
          variant = upload.variants.default
        end
      else
        variant = upload.variants.default
      end

    # if the file is in grid_fs we serve it by checking freshness and merging
    # in any headers from the upload.
    #
      case

        when variant.grid_fs?
          if request.headers["HTTP_RANGE"].blank?
            expires_in(42.years, :public => true)

            if request.head? || stale?(:last_modified => variant.updated_at.utc, :etag => variant, :public => true)
              grid_fs_file = variant.grid_fs_file

              self.headers.update(upload.headers_for(self.headers))
              self.headers.update(variant.headers_for(self.headers))

              self.content_type = grid_fs_file.content_type

              if request.head?
                render nothing: true
              else
                self.response_body = grid_fs_file
              end

              #if upload.acl == 'public'
                #cache!(variant) rescue nil
              #end
            end
          else
            range_start, range_end = request.headers["HTTP_RANGE"] =~ /bytes=(\d+)-(\d*)$/ && [$1, $2]

            if range_start
              range_end = grid_fs_file.length - 1 if range_end.blank?
              data      = grid_fs_file.slice(range_start.to_i .. range_end.to_i)

              Rails.logger.debug("Retrieving from #{ range_start } to #{ range_end }")

              headers["Content-Range"] = "#{ range_start }-#{ range_end }/#{ grid_fs_file.length }"
              headers["Content-Type"] = grid_fs_file.content_type

              response.status = 206
              self.response_body = data
            else
              self.response_body = grid_fs_file
              headers["Content-Length"] = grid_fs_file.length.to_s
            end
          end

          headers["Accept-Ranges"] = "bytes"

        when variant.s3?
          s3_url = variant.s3_url
          redirect_to(s3_url)

        when variant.fs?
          path = File.join(variant.fs['root'] || Upload.config.get(:fs, :root), variant.fs['path'])

          if stale?(:last_modified => variant.updated_at.utc, :etag => variant, :public => true)
            self.headers.update(upload.headers_for(self.headers))
            self.headers.update(variant.headers_for(self.headers))

            self.content_type = variant.content_type

            if request.head?
              render nothing: true
            else
              self.response_body = open(path, 'rb')
            end
          end

        else
          raise NotImplementedError
      end
    rescue Object => e
      raise unless Rails.env.production?
      head(:not_found)
    end
  end

  def create
  # extract filename
  #
    filename =
      %w( filename upload file qqfile ).
        map{|k| params[k]}.compact.first

  # ie9, etc fubars the param, in this case the params is the actual entire
  # uploaded file..
  #
    if filename.is_a?(String)
      io = request.body
    else
      if filename.respond_to?(:original_filename)
        io = filename
        filename = filename.original_filename
      end
    end

  # iphones hork teh image rotation.  we fix this on the fly here even before
  # more processing is done so we can show a correctly oriented image
  # pronto in preview mode.  blargh.
  #
    if Upload.image?(filename)
      begin
        image = MiniMagick::Image.read(io)
        io.rewind rescue nil
        image.auto_orient
        sio = Upload::SIO.new(image.to_blob, :pathname => filename)
        io = sio
      rescue Object => e
        Rails.logger.error(e)
      end
    end

  # store the upload
  #
    upload = Upload.io!(io, :filename => filename)

  # kick off any processing jobs...
  #
    sizes = nil

    if upload.image? and params[:resize]
      begin
        sizes = Upload.create_sizes!(upload, :background => params[:background])
      rescue Object => e
        Rails.logger.error(e)
        raise unless Rails.env.production?
      end
    end

  # mark the upload as a tmp file - hopefully something will claim it later
  # before our background sweeper process nukes it
  #
    unless params[:tmp].to_s == 'false'
      upload.tmp!
    end

  # reload
  #
    upload.reload

  # contruct the response.  doing it badly to make ie9, etc, work out okay...
  #
    json = upload.as_json
    json['sizes'] = sizes || {}

    to_json = json.merge('success' => true).to_json

    render(:text => to_json, :layout => false, :content_type => 'text/plain') ### IMPORTANT for ie9
  end

protected

  def validate_acl?(upload)
    case upload.acl
    # always show public files
    #
      when nil, '', 'public'
        return true

    # show protected files to anyone that's logged in
    #
      when 'protected'
        unless Current.user
          return false
        end

    # otherwise ensure that the user is logged in and either a token is set in
    # the url, or the upload itself expressing role based permissions that
    # overlap with the users...
    #
      when 'private'
        unless Current.user
          return false
        end

        if((token = params[:token]))
          if App.token?(token)
            return true
          else
            return false
          end
        end

        common_roles = (Array(Current.user[:roles]) & Array(upload[:roles]))
        if common_roles.size > 0
          return true
        else
          return false
        end

        return false

    # fallback is to show...
    #
      else
        return true
    end
  end

  def cache!(variant)
    if Rails.application.config.action_controller.perform_caching
      grid_fs_file = variant.grid_fs_file
      pathname = File.join(Rails.public_path, variant.url)

      FileUtils.mkdir_p(File.dirname(pathname))

      tmp = "#{ pathname }.tmp.#{ Process.pid }.#{ rand }"

      open(tmp, 'wb+') do |fd|
        fd.write(variant.data)
        FileUtils.mv(tmp, pathname)
      end
    end
  end

end
