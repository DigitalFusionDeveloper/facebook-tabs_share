#! /usr/bin/env ruby
#
  require 'csv'

#
  src_rows = []
  dst_rows = []

  src_headers = nil
  # "Retail Account(s), ADDR(s), CITY(s), STATE(s), ZIP9(s), PHON(s), Draft\\Package(s)"
  dst_headers = %w( title address city state zipcode phone type )

  src2dst = nil
 
#
  input =
    case ARGV[0]
      when '-', nil
        STDIN.binread
      else
        IO.binread(ARGV[0])
    end

  begin
    CSV.parse(input) do |src_row|
      if src_headers.nil?
        src_headers = src_row
        src2dst = Hash[src_headers.zip(dst_headers)]
        next
      end

      dst_rows.push( dst_row = [] )

      src2dst.each do |src_header, dst_header|
        dst_row.push(src_row.shift)
      end
    end
  rescue Errno::EPIPE
    nil
  end

#
  output =
    case ARGV[1]
      when '-', nil
        STDOUT
      else
        open(ARGV[1], 'wb')
    end

  begin
    CSV(output) do |csv|
      csv << dst_headers
      dst_rows.each do |dst_row|
        csv << dst_row
      end
    end
  rescue Errno::EPIPE
    nil
  end

BEGIN {

  def dos2unix(string)
    string = string.to_s
    string.gsub!(%r/\r\n/, "\n")
    string.gsub!(%r/\r/, "\n")
    string
  end

}
