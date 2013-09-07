module S3
  module Helper
  end

  class Controller < ApplicationController
    before_filter(:require_current_user)

=begin
    def new
    #
      bucket                  = params[:bucket]                   || aws_s3_bucket
      expiration              = params[:expiration]               || 42.hours.from_now
      protocol                = params[:protocol]                 || 'https'
      acl                     = params[:acl]                      || 'public-read'

    #
      success_action_status   = params[:success_action_status]   || '303'
      success_action_redirect = params[:success_action_redirect] || App.url(request.fullpath)

    #
      id           = Upload.id
      filename     = Upload.cleanname(filename).downcase
      key          = Upload.relative_path_for("#{ Upload.route }/#{ id }/original/#{ filename }")
      content_type = Upload.extract_content_type(filename)

    #
      if params[:file].blank?
        return
      end

    #
      unless params[:file].blank?
        render(:text => params.inspect, :layout => true)
      end
    end
=end

    def index
      if request.get?
        #
          bucket                  = params[:bucket]                   || aws_s3_bucket
          filename                = params[:filename]                 || params[:basename] || params[:pathname] || 'filename'
          expiration              = params[:expiration]               || 42.hours.from_now
          protocol                = params[:protocol]                 || 'https'
          acl                     = params[:acl]                      || 'public-read'

          success_action_status   = params[:success_action_status]   #|| '303'
          success_action_redirect = params[:success_action_redirect] #|| request.referrer

        #
          id           = Upload.id
          filename     = Upload.cleanname(filename).downcase
          key          = Upload.relative_path_for("#{ Upload.route }/#{ id }/original/#{ filename }")
          content_type = Upload.extract_content_type(filename)

        #
          action = "#{ protocol }://s3.amazonaws.com/#{ bucket }"
          url    = "#{ action }/#{ key }"

        #
          inputs = Map.new

        #
          inputs['key']          = key
          inputs['bucket']       = bucket
          inputs['url']          = url
          inputs['Content-Type'] = content_type

        #
          inputs['AWSAccessKeyId']          = aws_access_key_id
          inputs['acl']                     = acl

          if success_action_status
            inputs['success_action_status']   = success_action_status
          end

          if success_action_redirect
            inputs['success_action_redirect'] = success_action_redirect
          end

        #
          expiration = Time.parse(expiration.to_s).utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')

        #
          conditions =
            if params[:inputs].is_a?(Hash)
              conditions_for(inputs, params[:inputs])
            else
              conditions_for(inputs)
            end

        #
          policy = 
            policy_for(
              'expiration'  => expiration,
              'conditions'  => conditions
            )

        #
          signature =
            signature_for(
              policy
            )

        #
          inputs['policy']       = policy
          inputs['signature']    = signature

        #
          result = {
            :bucket       => bucket,
            :key          => key,
            :filename     => filename,

            :action       => action,
            :url          => url,
            :content_type => content_type,

            :inputs       => inputs
          }

        #
          render(:json => result.to_json)

      else

        render(:nothing => true)

      end
    end

  protected

    def conditions_for(*hashes)
      conditions = []

      hashes.compact.flatten.each do |hash|
        hash.each do |name, value|
          next if name == 'AWSAccessKeyId'
          conditions.push({name => value})
        end
      end

      conditions.push(['starts-with', 'success_action_status', ''])
      conditions.push(['starts-with', 'success_action_redirect', ''])

      conditions
    end

    def policy_for(hash = {})
      base64(hash.to_json)
    end

    def signature_for(policy)
      base64(
        OpenSSL::HMAC.digest(
          OpenSSL::Digest::Digest.new('sha1'),
          aws_secret_key_id,
          policy
        )
      )
    end

    def base64(string)
      Base64.encode64(string).gsub(/\n|\r/, '')
    end

    def aws_s3_bucket
      params[:bucket] || App.sekrets.aws.s3.bucket
    end

    def aws_secret_key_id
      App.sekrets.aws.secret_access_key
    end

    def aws_access_key_id
      App.sekrets.aws.access_key_id
    end
  end

  class BucketsController < ApplicationController
  end

  class ObjectsController < ApplicationController
  end
end
