$:.unshift File.expand_path("..", __FILE__)
require 'rdf'
require 'psych'
require 'yaml'
require 'support/models'

# For now, override RDF::Utils::File.open_file to look for the file locally before attempting to retrieve it
module RDF::Util
  module File
    LOCAL_PATH = ::File.expand_path("../dawg", __FILE__) + '/'

    class << self
      alias_method :original_open_file, :open_file
    end

    ##
    # Override to use Patron for http and https, Kernel.open otherwise.
    #
    # @param [String] filename_or_url to open
    # @param  [Hash{Symbol => Object}] options
    # @option options [Array, String] :headers
    #   HTTP Request headers.
    # @return [IO] File stream
    # @yield [IO] File stream
    def self.open_file(filename_or_url, options = {}, &block)
      case filename_or_url.to_s
      when /^file:/
        path = filename_or_url[5..-1]
        Kernel.open(path.to_s, &block)
      when %r{^(#{SPARQL::Spec::BASE_URI_10}|#{SPARQL::Spec::BASE_URI_11})}
        begin
          #puts "attempt to open #{filename_or_url} locally"
          local_filename = filename_or_url.to_s.sub($1, LOCAL_PATH)
          if ::File.exist?(local_filename)
            response = begin
              ::File.open(local_filename)
            rescue Errno::ENOENT
              Kernel.open(filename_or_url.to_s, "r:utf-8", 'Accept' => "application/ld+json, application/json, text/csv")
            end
            #puts "use #{filename_or_url} locally"
            document_options = {
              base_uri:     RDF::URI(filename_or_url),
              charset:      Encoding::UTF_8,
              code:         200,
              headers:      {}
            }
            document_options[:headers][:content_type] = case filename_or_url.to_s
            when /\.ttl$/    then 'text/turtle'
            when /\.nt$/     then 'application/n-triples'
            else                  'unknown'
            end
            document_options[:headers][:content_type] = response.content_type if response.respond_to?(:content_type)
            # For overriding content type from test data
            document_options[:headers][:content_type] = options[:contentType] if options[:contentType]

            # For overriding Link header from test data
            document_options[:headers][:link] = options[:httpLink] if options[:httpLink]

            remote_document = RDF::Util::File::RemoteDocument.new(response.read, document_options)
            if block_given?
              yield remote_document
            else
              remote_document
            end
          else
            Kernel.open(filename_or_url.to_s, options, &block)
          end
        end
      else
        original_open_file(filename_or_url, options, &block)
      end
    end
  end
end

module SPARQL
  require 'support/extensions/isomorphic'
  require 'support/matchers/solutions'
  require 'support/models'

  ##
  # `SPARQL::Spec` provides access to the Data Access Working Group (DAWG) test sute for SPARQL.
  #
  # @author [Arto Bendiken](http://ar.to/)
  # @author [Ben Lavender](http://bhuga.net/)
  # @author [Gregg Kellogg](http://greggkellogg.net/)
  module Spec
    BASE_DIRECTORY = File.expand_path("../dawg", __FILE__) + "/"
    BASE_URI_10 = RDF::URI("http://www.w3.org/2001/sw/DataAccess/tests/")
    BASE_URI_11 = RDF::URI("http://www.w3.org/2009/sparql/docs/tests/")

    FRAME = JSON.parse(%q({
      "@context": {
        "xsd": "http://www.w3.org/2001/XMLSchema#",
        "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
        "mf": "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#",
        "mq": "http://www.w3.org/2001/sw/DataAccess/tests/test-query#",
        "ut": "http://www.w3.org/2009/sparql/tests/test-update#",
        "dawgt": "http://www.w3.org/2001/sw/DataAccess/tests/test-dawg#",
        "id": "@id",
        "type": "@type",
    
        "comment": "rdfs:comment",
        "entries": {"@id": "mf:entries", "@type": "@id", "@container": "@list"},
        "include": {"@id": "mf:include", "@type": "@id", "@container": "@list"},
        "name": "mf:name",
        "action": {"@id": "mf:action", "@type": "@id"},
        "result": {"@id": "mf:result", "@type": "@id"},
        "approval": {"@id": "dawgt:approval", "@type": "@id"},
        "mq:data": {"@type": "@id"},
        "mq:graphData": {"@type": "@id"},
        "mq:query": {"@type": "@id"},
        "ut:data": {"@type": "@id"},
        "ut:graph": {"@type": "@id"},
        "ut:graphData": {"@type": "@id", "@container": "@set"},
        "ut:request": {"@type": "@id"}
      },
      "@type": "mf:Manifest",
      "entries": {}
    }))
    # Module functions

    ##
    # Convert test manifests from Turtle to JSON-LD. Saves as JSON-LD parallel to original manifest
    def self.convert_manifest(manifest_uri, save=false)
      puts "Convert #{manifest_uri}"
      g = RDF::Repository.load(manifest_uri)
      JSON::LD::API.fromRDF(g) do |expanded|
        JSON::LD::API.frame(expanded, FRAME) do |man|
          includes = Array(man["include"]).dup if man.has_key?("include")

          if save
            local_man = manifest_uri.
              sub(%r{^(#{SPARQL::Spec::BASE_URI_10}|#{SPARQL::Spec::BASE_URI_11})}, BASE_DIRECTORY).
              sub(".ttl", ".jsonld")
            File.open(local_man, "w") do |f|
              f.puts framed.to_json(::JSON::LD::JSON_STATE)
            end
          else
            puts framed.to_json(::JSON::LD::JSON_STATE)
          end

          # Recurse into sub-manifests
          Array(includes).each do |sub_uri|
            self.convert_manifest(sub_uri, save)
          end
        end
      end
      manifest_uri.sub(".ttl", ".jsonld")
    end

    def self.sparql1_0_tests(save_cache = false)
      self.convert_manifest(File.join(BASE_URI_10, "data-r2/manifest-evaluation.ttl"), true) if save_cache
      File.join(BASE_URI_10, "data-r2/manifest-evaluation.jsonld")
    end

    def self.sparql1_0_syntax_tests(save_cache = false)
      self.convert_manifest(File.join(BASE_URI_10, "data-r2/manifest-syntax.ttl"), true) if save_cache
      File.join(BASE_URI_10, "data-r2/manifest-syntax.jsonld")
    end

    def self.sparql1_1_tests(save_cache = false)
      self.convert_manifest(File.join(BASE_URI_11, "data-sparql11/manifest-all.ttl"), true) if save_cache
      File.join(BASE_URI_10, "data-sparql11/manifest-all.jsonld")
    end
  end # Spec
end # RDF
