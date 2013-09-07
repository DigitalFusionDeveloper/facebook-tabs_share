class Su::TestController < Su::Controller
  Actions = []

  def self.method_added(*args, &block)
    super
  ensure
    Actions << args.first.to_s
    Actions.uniq!
  end

  def index
    @actions = Actions.select{|action| self.class.action_methods.include?(action)}
    erb = <<-__
      <ul>
        <% @actions.each do |action| %>
          <li><%= link_to action, :action => action %></li>
        <% end %>
      </ul>
    __
    render(:inline => erb, :layout => 'application')
  end

  def show_current_keys
    render(:json => Current.attributes.keys.to_json, :layout => 'application')  
  end

  def show_message_with_redirect
    message('hai!', :class => :error)
    redirect_to('/')
  end

  def show_app_url
    href = App.url
    link = "<a href=#{ href.inspect }>#{ href.inspect }</a>"
    render(:inline => link, :layout => 'application')
  end

  def show_default_url_options
    render(:text => h(DefaultUrlOptions.inspect), :layout => 'application')
  end

  def server_env
    dump_env(ENV)
  end

  def request_env
    dump_env(request.env)
  end

  def show_current_controller
    show(current_controller)
  end

  def show_session
    show(session)
  end

  def show_user_session
    show((current_user || User.first).session)
  end

  def show_real_and_effective_users
    show(real_and_effective_users)
  end

  def show_params
    show(params.class.ancestors)
  end

  def show_helper
    show(Helper.new)
  end

  def demo_x_sendfile
    x_sendfile(__FILE__)
  end

  def show_flash_styles
    flash_message_keys.each do |key|
      msg = "<a href='javascript:App.flash(#{ 'hai!'.to_json })'>#{ key }</a> " + Lorem[4, 4 + rand(16)]
      message(msg, :class => key)
    end

    message.info('info: this method of calling works too')

    message.success('success: this method of calling works too')

    erb = <<-__
      <pre><%= App.json_for(flash.to_hash) %></pre>
      <br />
      <em>show_flash_styles</em>
    __

    render(:inline => erb, :layout => 'application')
  end

  def show_form_styles
    @errors = ActiveModel::Errors.new(base = Map.new)
    @errors.add :title, 'is too short'
    @errors.add :base, 'api was fubar'
  end

  def show_view_render
    html = View.render(:inline => '<%= time %>', :locals => {:time => Time.now})
    render(:text => html, :layout => 'application')
  end


  def session_plus_redirect
    session[:time] = Time.now.utc.iso8601
    redirect_to(:action => :session_plus_redirect_to)
  end

  def session_plus_redirect_to
    show(session)
  end

  def test_redirect_to
    redirect_to!(:action => :test_redirect_to_target)
  end

  def test_redirect_to_target
    render(:text => 'made it!', :layout => true)
  end

  def test_render_bang
    render!(:text => 'foobar')
    render!(:text => 'this never happens...')
  end

  def show_cache
    show Rails.cache.inspect
  end


  def conducer_upload
    #if defined?(::Dao)
    #  Object.send(:remove_const, :Dao)
    #  Kernel.load('/Users/ahoward/git/dao/lib/dao.rb')
    #end

    upload_conducer = Class.new(::Dao::Conducer) do
      model_name :Upload
      mount Dao::Upload, :a_file, :placeholder => 'han-solo.jpg'
    end

    @c = upload_conducer.new(params[:upload])

    erb = <<-__
      <% form = capture do %>

        <%= form_tag({}, :multipart => true) do %>

          <img src='<%= @c.get(:a_file, :url) %>' />
          <br />
          <%= @c.form.upload :a_file %>
          <br />
          <%= @c.form.submit %>

        <% end %>

      <% end %>


      <pre>
        @c: <%= pp @c %>
      </pre>

      <pre>
        params: <%= pp params %>
      </pre>

      <pre>
        <%= raw(CGI.escapeHTML(form)) %>
      </pre>

      <%= form %>


    __

    render(:inline => erb, :layout => 'application')
  end


  def test_job
    @job = Job.submit(Kernel, :puts, 42)
    loop do
      break if @job.reload.completed_at
    end
    render :inline => "<pre><%= @job.inspect %></pre>", :layout => true
  end

  def test_background_job
    background = Job.background
    Job.background = true
    @job = Job.submit(Kernel, :puts, 42)
    Job.background = background
    42.times do
      break if @job.reload.completed_at
    end
    render :inline => "<pre><%= @job.inspect %></pre>", :layout => true
  end

  def test_mailer_job
    @email = params[:email]

    if @email.blank? 
      @email = current_user ? current_user.email : ''
      erb = <<-__
        <html>
          <body>
            <%= form_tag do %>
              email: <input name='email' value=#{ @email.inspect }/>
            <% end %>
          </body>
        </html>
      __
      render(:inline => erb, :layout => 'application')
      return
    end

    @job = Job.submit(Mailer, :test, @email)
    42.times do
      break if @job.reload.completed_at
    end
    render :inline => "<pre><%= @job.inspect %></pre>", :layout => true
  end


  def rendering_markdown
    markdown =
      <<-__
        * one
        * two
        * three

        ```css
          .foobar {
            color: pink;
          }
        ```

        ```bash
          # comment
          echo $foobar
        ```


        ```ruby
        ## teh comments...
        #
        #
          class C
            A = 42
            B = "string\#{ interpolation }"

            def foobar
              @barfoo
            end
          end
        ```
      __

    markdown = Util.unindent(markdown)

    render(:inline => markdown, :layout => true, :type => :md)
  end

  def ajax_upload
    return if request.get?
  end

#http://0.0.0.0:3000/su/test/s3_upload?bucket=staging.cdn.movionetwork.com&key=system%2Fuploads%2F5155c9baaf481c68bc000060%2Foriginal%2Fchicken-run.jpg&etag=%2259a85a90a6cc7faec2bba91dcf798f6d%22&bucket=staging.cdn.movionetwork.com&key=system%2Fuploads%2F5155c9e1af481ca994000061%2Foriginal%2Fboots.jpg&etag=%22d0a9d2eb8938acdf071f79e3a7952139%22
  def s3_upload
    return if(request.get? and !params[:key])

    @uploads = []

    unless params[:files].blank?
      urls = Array(params[:files])

      urls.each do |url|
        @uploads.push(Upload.create_from_s3_url!(url))
      end
    end

    @data = Map.new
    @data[:params] = params
    @data[:uploads] = @uploads.map(&:as_document)
    #render(:inline => "<pre><%= @data.inspect %></pre>", :layout => true)
  end

  def editor
    return if request.get?
  end

  def clear_cookies
    cookies.clear
    redirect_to :action => :index
  end

  def get_device
    device = request.cookies['device']

    if device.blank?
      flash[:return_to] = request.fullpath
      render :template => 'shared/get_device'
    else
      render :text => "device : #{ device }", :layout => true
    end
  end

  def google_map
    @location = Location.for('boulder')
  end


private
  Lorem = <<-__
    Ut nulla. Vivamus bibendum, nulla ut congue fringilla, lorem ipsum ultricies
    risus, ut rutrum velit tortor vel purus. In hac habitasse platea dictumst. Duis
    fermentum, metus sed congue gravida, arcu dui ornare urna, ut imperdiet enim
    odio dignissim ipsum. Nulla facilisi. Cras magna ante, bibendum sit amet, porta
    vitae, laoreet ut, justo. Nam tortor sapien, pulvinar nec, malesuada in,
    ultrices in, tortor. Cras ultricies placerat eros. Quisque odio eros, feugiat
    non, iaculis nec, lobortis sed, arcu. Pellentesque sit amet sem et purus
    pretium consectetuer.
  __

  def dump_env(dump_env)
    env = {}
    dump_env.each do |key, val|
      env[key] =
        begin
          val.to_yaml
          val
        rescue
          val.inspect
        end
    end
    render(:text => env.to_a.sort.to_yaml, :content_type => 'text/plain')
  end

  def show(object)
    render(:text => pp(object), :content_type => 'text/plain')
  end

  def pp(object)
    require 'pp'
    raw(PP.pp(object, ''))
  end
end
