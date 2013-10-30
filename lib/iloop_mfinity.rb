module ILoop
  class MFinity

    def self.settings
      @@settings ||= Map.for(Settings.for(File.join(Rails.root, 'config/iloop.yml')))
    end

    def settings
      self.class.settings
    end

    def opt_in(phone)
      phone = '1' + phone unless phone =~ /^1/
      path = path_for_message(phone,settings.keyword)
      response = Net::HTTP.get_response(uri.host,path)
    end

    def opt_out(phone)
      phone = '1' + phone unless phone =~ /^1/
      path = path_for_message(phone,"STOP%20#{settings.keyword}")
      response = Net::HTTP.get_response(uri.host,path)
    end

    def path_for_message(phone,message)
      path = "#{uri.path}?msisdn=#{phone}&shortCode=#{settings.short_code}&message=#{message}&userToken=#{settings.user_token}"
    end

    def uri
      @url ||= URI.parse(settings.web_uri)
    end

    def group_messaging_report(start_date = nil, end_date = nil)
      start_date ||= (DateTime.now - 1.day).midnight
      end_date ||= DateTime.now.midnight - 1.second
      response = Net::HTTP.get_response(report_uri.host, 
                                        path_for_report(start_date,end_date))
      if response.kind_of? Net::HTTPSuccess
        header, report = response.body.split("\n\n")
        Map.new(header: header.split("\n"), csv: report)
      else
        nil
      end
    end

    def path_for_report(start_date,end_date)
      xml = <<-__
  <?xml version="1.0" encoding="UTF-8" ?>
    <report-request>
      <authentication>
        <userToken>#{ settings.user_token }</userToken>
      </authentication>
      <report>
        <groupId>#{ settings.group_id }</groupId>
        <startDate>#{ start_date.strftime('%Y/%m/%d %R') }</startDate>
        <endDate>#{ end_date.strftime('%Y/%m/%d %R') }</endDate>
        <reportName></reportName>
        <gender>false</gender>
        <state>false</state>
        <postalCode>false</postalCode>
      </report>
    </report-request>
    __
      "#{report_uri.path}?xml=" + URI.escape(xml.strip)
    end

    def report_uri
      @report_uri ||= URI.parse(settings.report_uri)
    end

  end
end

