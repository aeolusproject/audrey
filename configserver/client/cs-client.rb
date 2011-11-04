require 'rubygems'
require 'oauth'
require 'nokogiri'
require 'optparse'
require 'ruby-debug'

@API_VERSION = "1"
@options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"
  opts.separator ""
  opts.separator "Specific options:"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    @options[:verbose] = v
  end

  opts.on("-e", "--endpoint endpoint", "Endpoint") do |e|
    @options[:endpoint] = e
  end

  opts.on("-k", "--key [oauth_key]", "oAuth Key") do |k|
    @options[:oauth_key] = k
  end

  opts.on("-s", "--secret [oauth_secret]", "oAuth Secret") do |s|
    @options[:oauth_secret] = s
  end
end.parse!

def read_file(fname)
  if not File.exist?(fname)
    raise "ERROR: Cannot open #{fname} for reading"
  end
  puts "Reading #{fname}"
  xml_body = File.open(fname, 'r') { |file| file.read }
  xml = Nokogiri::XML xml_body
  root_node = xml.xpath('instance-config').first
  [root_node, xml_body]
end

def get_key_secret_from_xml(root_node)
  uuid = root_node.attributes['id']
  secret = root_node.attributes['secret']
  puts "UUID #{uuid}" if @options[:verbose]
  puts "Secret #{secret}" if @options[:verbose]
  [uuid, secret]
end

# Exchange your oauth_token and oauth_token_secret for an AccessToken instance.
def client_setup_and_test(key, secret)
  consumer = OAuth::Consumer.new(key, secret,
    { :scheme => :header })
  token = OAuth::AccessToken.new consumer

  # use the access token as an agent to get the home timeline
  puts "#{@options[:endpoint]}/auth"
  auth_test = token.request(:get, "#{@options[:endpoint]}/auth")
  puts auth_test.body

  # return the token and the auth test code
  [token, auth_test.code]
end

def post(client, xml_body, uuid)
  data = CGI::escape(xml_body)
#  args[:payload] = "data=#{data}"
  puts "#{@options[:endpoint]}/configs/#{@API_VERSION}/#{uuid}"
  post = client.request(:post, "#{@options[:endpoint]}/configs/#{@API_VERSION}/#{uuid}/",
                  { :payload => "data=#{data}" })
  puts post.code
  puts post.body
end

# main
ARGV.each do |fname|
  # read the file
  root_node, xml_body = read_file(fname)

  # get auth creds
  uuid = @options[:oauth_key]
  secret = @options[:oauth_secret]
  file_uuid, file_secret = get_key_secret_from_xml(root_node)

  # setup the client
  client, test_code = client_setup_and_test(uuid, secret)

  if test_code == "200"
    # call the config server
    post(client, xml_body, file_uuid)
  end
end
