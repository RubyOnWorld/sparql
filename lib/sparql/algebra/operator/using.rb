module SPARQL; module Algebra
  class Operator

    ##
    # The SPARQL UPDATE `using` operator.
    #
    # XXX
    #
    # @example
    #   (add default <a>)
    #
    # @see http://www.w3.org/TR/sparql11-update/#add
    class Using < Operator
      include SPARQL::Algebra::Update

      NAME = [:using]

      ##
      # Executes this upate on the given `writable` graph or repository.
      #
      # @param  [RDF::Queryable] queryable
      #   the graph or repository to write
      # @param  [Hash{Symbol => Object}] options
      #   any additional keyword options
      # @option options [Boolean] debug
      #   Query execution debugging
      # @return [RDF::Queryable]
      #   Returns queryable.
      # @raise [IOError]
      #   If `from` does not exist, unless the `silent` operator is present
      # @see    http://www.w3.org/TR/sparql11-update/
      def execute(queryable, options = {})
        debug(options) {"Using"}
        queryable
      end
    end # Using
  end # Operator
end; end # SPARQL::Algebra
