require 'rdf' # @see http://rubygems.org/gems/rdf
require 'sparql/algebra'
require 'json'
require 'sxp'

module SPARQL
  ##
  # A SPARQL grammar for RDF.rb.
  #
  # ## Representation
  # The parser natively generates  native SPARQL S-Expressions (SSE),
  # a hierarch of `SPARQL::Algebra::Operator` instances
  # which can be executed against a queryable object, such as a Repository identically
  # to `RDF::Query`.
  # 
  # Other elements within the hierarchy
  # are generated using RDF objects, such as `RDF::URI`, `RDF::Node`, `RDF::Literal`, and `RDF::Query`.
  # 
  # See {SPARQL::Grammar::Parser} for a full listing
  # of algebra operations and RDF objects generated by the parser.
  # 
  # The native SSE representation may be serialized to a textual representation of SSE as
  # serialized general S-Expressions (SXP).
  # The SXP generated closely follows that of [OpenJena ARQ](http://openjena.org/wiki/SSE), which is intended principally for
  # running the SPARQL rules. Additionally, SSE is generated for CONSTRUCT, ASK, DESCRIBE and FROM operators.
  # 
  # SXP is generated by serializing the parser result as follows:
  # 
  #     sse = SPARQL::Grammar.parse("SELECT * WHERE { ?s ?p ?o }")
  #     sxp = sse.to_sxp
  # 
  # The following examples illustrate SPARQL transformations:
  #
  # SPARQL:
  #
  #     SELECT * WHERE { ?a ?b ?c }
  # 
  # SXP:
  #
  #     (bgp (triple ?a ?b ?c))
  # 
  # SPARQL:
  #
  #     SELECT * FROM <a> WHERE { ?a ?b ?c }
  # 
  # SXP:
  #
  #     (dataset (<a>) (bgp (triple ?a ?b ?c)))
  # 
  # SPARQL:
  #
  #     SELECT * FROM NAMED <a> WHERE { ?a ?b ?c }
  # 
  # SXP:
  #
  #     (dataset ((named <a>)) (bgp (triple ?a ?b ?c)))
  # 
  # SPARQL:
  #
  #     SELECT DISTINCT * WHERE {?a ?b ?c}
  # 
  # SXP:
  #
  #     (distinct (bgp (triple ?a ?b ?c)))
  # 
  # SPARQL:
  #
  #     SELECT ?a ?b WHERE {?a ?b ?c}
  # 
  # SXP:
  #
  #     (project (?a ?b) (bgp (triple ?a ?b ?c)))
  # 
  # SPARQL:
  #
  #     CONSTRUCT {?a ?b ?c} WHERE {?a ?b ?c FILTER (?a)}
  # 
  # SXP:
  #
  #     (construct ((triple ?a ?b ?c)) (filter ?a (bgp (triple ?a ?b ?c))))
  # 
  # SPARQL:
  #
  #     SELECT * WHERE {<a> <b> <c> OPTIONAL {<d> <e> <f>}}
  # 
  # SXP:
  #
  #     (leftjoin (bgp (triple <a> <b> <c>)) (bgp (triple <d> <e> <f>)))
  # 
  # SPARQL:
  #
  #     SELECT * WHERE {<a> <b> <c> {<d> <e> <f>}}
  # 
  # SXP:
  #
  #     (join (bgp (triple <a> <b> <c>)) (bgp (triple <d> <e> <f>)))
  # 
  # SPARQL:
  #
  #     PREFIX : <http://example/> 
  # 
  #     SELECT * 
  #     { 
  #        { ?s ?p ?o }
  #       UNION
  #        { GRAPH ?g { ?s ?p ?o } }
  #     }
  # 
  # SXP:
  #
  #     (prefix ((: <http://example/>))
  #       (union
  #         (bgp (triple ?s ?p ?o))
  #         (graph ?g
  #           (bgp (triple ?s ?p ?o)))))
  # 
  # ## Implementation Notes
  # The parser is driven through a rules table contained in lib/sparql/grammar/meta.rb. This includes branch rules to indicate productions to be taken based on a current production.
  # 
  # The meta.rb file is generated from etc/sparql11.bnf using the `ebnf` gem.
  # 
  #     ebnf --ll1 Query --format rb \
  #       --mod-name SPARQL::Grammar::Meta \
  #       --output lib/sparql/grammar/meta.rb \
  #       etc/sparql11.bnf
  # 
  # @see http://www.w3.org/TR/rdf-sparql-query/#grammar
  # @see http://rubygems.org/gems/ebnf
  module Grammar
    autoload :Parser,     'sparql/grammar/parser11'
    autoload :Terminals,  'sparql/grammar/terminals11'

    # Make all defined non-autoloaded constants immutable:
    constants.each { |name| const_get(name).freeze unless autoload?(name) }

    ##
    # Parse the given SPARQL `query` string.
    #
    # @example
    #   result = SPARQL::Grammar.parse("SELECT * WHERE { ?s ?p ?o }")
    #
    # @param  [IO, StringIO, Lexer, Array, String, #to_s] query
    #   Query may be an array of lexed tokens, a lexer, or a
    #   string or open file.
    # @param  [Hash{Symbol => Object}] options
    # @return [Parser]
    # @raise  [Parser::Error] on invalid input
    def self.parse(query, options = {}, &block)
      Parser.new(query, options).parse(options[:update] ? :UpdateUnit : :QueryUnit)
    end

    ##
    # Parses input from the given file name or URL.
    #
    # @param  [String, #to_s] filename
    # @param  [Hash{Symbol => Object}] options
    #   any additional options (see `RDF::Reader#initialize` and `RDF::Format.for`)
    # @option options [Symbol] :format (:ntriples)
    # @yield  [reader]
    # @yieldparam  [RDF::Reader] reader
    # @yieldreturn [void] ignored
    # @raise  [RDF::FormatError] if no reader found for the specified format
    def self.open(filename, options = {}, &block)
      RDF::Util::File.open_file(filename, options) do |file|
        self.parse(file, options, &block)
      end
    end

    ##
    # Returns `true` if the given SPARQL `query` string is valid.
    #
    # @example
    #     SPARQL::Grammar.valid?("SELECT ?s WHERE { ?s ?p ?o }")  #=> true
    #     SPARQL::Grammar.valid?("SELECT s WHERE { ?s ?p ?o }")   #=> false
    #
    # @param  [String, #to_s]          query
    # @param  [Hash{Symbol => Object}] options
    # @return [Boolean]
    def self.valid?(query, options = {})
      Parser.new(query, options).valid?
    end

    ##
    # Tokenizes the given SPARQL `query` string.
    #
    # @example
    #     lexer = SPARQL::Grammar.tokenize("SELECT * WHERE { ?s ?p ?o }")
    #     lexer.each_token do |token|
    #       puts token.inspect
    #     end
    #
    # @param  [String, #to_s]          query
    # @param  [Hash{Symbol => Object}] options
    # @yield  [lexer]
    # @yieldparam [Lexer] lexer
    # @return [Lexer]
    # @raise  [Lexer::Error] on invalid input
    def self.tokenize(query, options = {}, &block)
      Lexer.tokenize(query, options, &block)
    end
  end # Grammar
end # SPARQL
