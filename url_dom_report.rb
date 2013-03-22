#!/usr/bin/env ruby

require 'rubygems'

require 'nokogiri' # parse HTML docs
require 'open-uri' # handle file opens nicely over HTTP
require 'timeout'  # to catch HTTP timeouts


### some constants

# FIXME: specify file on command line or accept via stdin
INPUT_FILENAME = "urls.html"

# time (in seconds) to wait for HTTP request to succeed
HTTP_TIMEOUT = 5 # seconds

# CSS selector for pulling out links of input document. should just be "a"
INPUT_INPUT_LINK_SELECTOR = "a"

# CSS selector for what data you want out of remote documents
# FIXME: this should be passed on the cmd line
CSS_SELECTOR = "#site-name strong a span"

# specs for output
# FIXME: add option for stdout
OUTPUT_FILE = "urls.#{}.tsv"
OUTPUT_COLS = ["anchor_text", "url", "matched_text"]


### some functions

# FIXME: make these all object-oriented

# execute a given a CSS selector against a given nokogiri doc
# return value of text in selected node
def match_selector(page, css_selector)
  title_nodes = page.css(css_selector)

  if title_nodes.length > 0
    title_nodes[0].text
  else
    "ERROR: Couldn't parse CSS selector."
  end
end


# given some markup, parse it. simple wrapper function
# returns result of parsing
def parse_doc(markup)
  match_selector(Nokogiri::HTML(markup), CSS_SELECTOR)
end


# given a URL, fetch and parse it, handling error conditions
# returns selected text
def fetch_and_parse_url(url)
  begin
    # open the doc, wrapping it in a timeout
    remote_doc = Timeout::timeout(HTTP_TIMEOUT){
      open(url)
    }
    # parse the resulting content
    parse_doc(remote_doc)

  # catch HTTP errors
  rescue OpenURI::HTTPError => e
    # "ERROR: #{e.io.status}"

    # sometimes we want to parse the error page; the primary use case is 
    # parsing navigation/breadcrumbs. if the error is displayed a 
    # contextually (within the site's hierarchy), then it's somewhat useful.
    # 
    # FIXME: make this behavior configurable
    parse_doc(e.io.read)

  rescue Timeout::Error
    # return a generic timeout error
    "ERROR: Timeout"

  rescue
    # FIXME: provide better error mesaging here. would need more conditions 
    # or to interpret exception info
    "ERROR: Unknown"
  end
end


# given a results array of objects, write out a tab-separateed file
def output_results(results)
  # create the actual output content as an array (will be joined later 
  # with linebreaks)
  tsv_content = []

  # join the header columns with a tab
  # FIXME: make this optional
  tsv_content << OUTPUT_COLS.join("\t")

  # map the result array of objects to a tab-separated line
  tsv_content << results.map{ |row| "#{row[:anchor_text]}\t#{row[:url]}\t#{row[:matched_text]}" }

  # write out the file
  File.open(OUTPUT_FILE, 'w') { |f| f.write(tsv_content.join("\n")) }
end


### actual  functions


# FIXME: these three statements can probably be refactored into a block

# read in the HTML
input_file = File.open(INPUT_FILENAME)

# use Nokogiti to parse the HTML
url_doc = Nokogiri::HTML(input_file)

# close the input file; we don't need it anymore
input_file.close


# pull the anchors out of the HTML doc
anchors = url_doc.css(INPUT_LINK_SELECTOR)
puts "Checking #{anchors.length} URLs..."


# array of objects for later formatting/output
results = []


# iterate over the anchors
anchors.each_with_index do |anchor, i|
  # grab the URL from the A tag and output it for status msg
  url = anchor.attributes['href'].text
  puts "[#{i}/#{anchors.length}] #{url}"

  # perform the match on the page
  matched_text = fetch_and_parse_url(url)

  # append the data to the results array
  results << {
    :anchor_text => anchor.text,
    :url => url,
    :matched_text => matched_text
  }
end


# output the data
output_results(results)
