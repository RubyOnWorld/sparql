module SPARQL; module Algebra
  class Operator
    ##
    # The SPARQL GraphPattern `leftjoin` operator.
    #
    # [57]  OptionalGraphPattern    ::= 'OPTIONAL' GroupGraphPattern
    #
    # @example SPARQL Grammar
    #   PREFIX :    <http://example/>
    #   SELECT * { 
    #     ?x :p ?v .
    #     OPTIONAL { 
    #       ?y :q ?w .
    #       FILTER(?v=2)
    #     }
    #   }
    #
    # @example SSE
    #   (prefix ((: <http://example/>))
    #     (leftjoin
    #       (bgp (triple ?x :p ?v))
    #       (bgp (triple ?y :q ?w))
    #       (= ?v 2)))
    #
    # @see https://www.w3.org/TR/sparql11-query/#sparqlAlgebra
    class LeftJoin < Operator
      include Query
      
      NAME = [:leftjoin]

      ##
      # Executes each operand with `queryable` and performs the `leftjoin` operation
      # by adding every solution from the left, merging compatible solutions from the right
      # that match an optional filter.
      #
      # @param  [RDF::Queryable] queryable
      #   the graph or repository to query
      # @param  [Hash{Symbol => Object}] options
      #   any additional keyword options
      # @yield  [solution]
      #   each matching solution
      # @yieldparam  [RDF::Query::Solution] solution
      # @yieldreturn [void] ignored
      # @return [RDF::Query::Solutions]
      #   the resulting solution sequence
      # @see    https://www.w3.org/TR/sparql11-query/#sparqlAlgebra
      # @see    https://ruby-rdf.github.io/rdf/RDF/Query/Solution#merge-instance_method
      # @see    https://ruby-rdf.github.io/rdf/RDF/Query/Solution#compatible%3F-instance_method
      def execute(queryable, **options, &block)
        filter = operand(2)

        raise ArgumentError,
          "leftjoin operator accepts at most two arguments with an optional filter" if
          operands.length < 2 || operands.length > 3

        debug(options) {"LeftJoin"}
        left = queryable.query(operand(0), depth: options[:depth].to_i + 1, **options)
        debug(options) {"=>(leftjoin left) #{left.inspect}"}

        right = queryable.query(operand(1), depth: options[:depth].to_i + 1, **options)
        debug(options) {"=>(leftjoin right) #{right.inspect}"}

        # LeftJoin(??1, ??2, expr) =
        @solutions = RDF::Query::Solutions()
        left.each do |s1|
          load_left = true
          right.each do |s2|
            s = s2.merge(s1)
            # Re-bind to bindings, if defined, as they might not be found in solution
            options[:bindings].each_binding do |name, value|
              s[name] = value if filter.variables.include?(name)
            end if options[:bindings] && filter.respond_to?(:variables)

            expr = filter ? boolean(filter.evaluate(s)).true? : true rescue false
            debug(options) {"===>(evaluate) #{s.inspect}"} if filter

            if expr && s1.compatible?(s2)
              # { merge(??1, ??2) | ??1 in ??1 and ??2 in ??2, and ??1 and ??2 are compatible and expr(merge(??1, ??2)) is true }
              debug(options) {"=>(merge s1 s2) #{s.inspect}"}
              @solutions << s
              load_left = false   # Left solution added one or more times due to merge
            end
          end
          if load_left
            debug(options) {"=>(add) #{s1.inspect}"}
            @solutions << s1
          end
        end
        
        debug(options) {"=> #{@solutions.inspect}"}
        @solutions.each(&block) if block_given?
        @solutions
      end

      # The same blank node label cannot be used in two different basic graph patterns in the same query
      def validate!
        left_nodes, right_nodes = operand(0).ndvars, operand(1).ndvars

        unless (left_nodes.compact & right_nodes.compact).empty?
          raise ArgumentError,
               "sub-operands share non-distinguished variables: #{(left_nodes.compact & right_nodes.compact).to_sse}"
        end
        super
      end

      ##
      # Optimizes this query.
      #
      # If optimize operands, and if the first two operands are both Queries, replace
      # with the unique sum of the query elements
      #
      # @return [Object] a copy of `self`
      # @see SPARQL::Algebra::Expression#optimize
      # FIXME
      def optimize!(**options)
        return self
        ops = operands.map {|o| o.optimize(**options) }.select {|o| o.respond_to?(:empty?) && !o.empty?}
        expr = ops.pop unless ops.last.executable?
        expr = nil if expr.respond_to?(:true?) && expr.true?
        
        # ops now is one or two executable operators
        # expr is a filter expression, which may have been optimized to 'true'
        case ops.length
        when 0
          RDF::Query.new  # Empty query, expr doesn't matter
        when 1
          expr ? Filter.new(expr, ops.first) : ops.first
        else
          expr ? LeftJoin.new(ops[0], ops[1], expr) : LeftJoin.new(ops[0], ops[1])
        end
      end

      ##
      #
      # Returns a partial SPARQL grammar for this operator.
      #
      # @param [Boolean] top_level (true)
      #   Treat this as a top-level, generating SELECT ... WHERE {}
      # @param [Hash{String => Operator}] extensions
      #   Variable bindings
      # @param [Array<Operator>] filter_ops ([])
      #   Filter Operations
      # @return [String]
      def to_sparql(top_level: true, filter_ops: [], extensions: {}, **options)
        str = "{\n" + operands[0].to_sparql(top_level: false, extensions: {}, **options)
        str << 
          "\nOPTIONAL {\n" +
          operands[1].to_sparql(top_level: false, extensions: {}, **options)
        case operands[2]
        when SPARQL::Algebra::Operator::Exprlist
          operands[2].operands.each do |op|
            str << "\nFILTER (" + op.to_sparql(**options) + ")"
          end
        when nil
        else
          str << "\nFILTER (" + operands[2].to_sparql(**options) + ")"
        end
        str << "\n}}"
        top_level ? Operator.to_sparql(str, filter_ops: filter_ops, extensions: extensions, **options) : str
      end
    end # LeftJoin
  end # Operator
end; end # SPARQL::Algebra
