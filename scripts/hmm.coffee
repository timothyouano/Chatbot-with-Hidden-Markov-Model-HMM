###
Hidden Markov Model

Author: Timothy Ouano & Ma.Trisha Tagadiad
###

class HMM

    ###
    Constructs a new Hidden Markov Model.
    @param [Array<String>] states - States of the model. (Optional)
    @param [String] finalState - Final state of the model. (Optional)
    @param [Array<String>] symbols - Symbols of the model. (Optional)
    @param [Dict<String,Float>] initialProbability - Initial Probability of the model. (Optional)
    @param [Dict<String, Dict<String, Float>>] transitionProbability - Transition Probability of the model. (Optional)
    @param [Dict<String, Dict<String, Float>>] emissionProbability - Emission Probability of the model. (Optional)
    @return [HMM] New Hidden Markov Model.
    ###
    constructor: (
        @states = [],
        @finalState = '',
        @symbols = [],
        @initialProbability = {},
        @transitionProbability = {},
        @emissionProbability = {}
    ) ->

    ###
    Returns the initial probability of given state.
    @private
    @param [String] state - State whose initial probability will be retrieved.
    @return [Float] Probability that the initial state is given one.
    ###
    initProbability: (state) ->
        return @initialProbability[state] ? 0

    ###
    Returns the probability of moving from given source state to given destination
    state.
    @private
    @param [String] source - Starting/Initial State
    @param [String] target - Destination/End State.
    @return [Float] Probability of moving from given stating state to given end state.
    ###
    transProbability: (source, target) ->
        return @transitionProbability[source]?[target] ? 0

    ###
    gets the probability that given state emits given symbol.
    @private
    @param [String] state - State that will be emitting the symbol.
    @param [String] symbol - Symbol that should be emitted.
    @return [Float] Probability that given state emits given symbol.
    ###
    emitProbability: (state, symbol) ->
        return @emissionProbability[state]?[symbol] ? 0

    ###
    Reestimates this model to properly classify given obversed sequences.
    @param [Array<String>] items Items used to reestimate this model.
    @param [Array<String>] path Optional. Array of optimal paths for each one of
    given items. If no paths are given they are computed with Viterbi algorithm.
    ###
    reestimate: (items, paths) ->

        shouldRemitProbabilityeat = true

        while shouldRemitProbabilityeat

            # Initialize
            initials = {}
            transitions = {}
            symbols = {}

            # Original variables from constructing the Hidden Markov
            original =
                st: @states
                sy: @symbols
                fs: @finalState
                initProbability: @initialProbability
                transProbability: JSON.stringify @transitionProbability
                emitProbability: JSON.stringify @emissionProbability

            # If there are no initialized paths upon construction, create paths
            unless paths?
                paths = []
                for item in items
                    paths.push @viterbi( item ).path

            @transitionProbability = {}
            @emissionProbability = {}

            # for each path
            for path in paths
                head = path[0]
                # Checks if initials[ head ] is undefined or null
                initials[ head ] ?= 0
                initials[ head ]++

            # For each Initial Probability = Number of occurence / Path length 
            for state, count of initials
                @initialProbability[ state ] = count / paths.length

            sum = {}
            for path, index in paths
                item = items[ index ]
                for j in [0...(path.length - 1)]
                    source = path[ j ]
                    target = path[ j + 1 ]
                    # Check if sum[ source ] is null or undefined
                    sum[ source ] ?= 0
                    sum[ source ]++
                    # Check if transitions[ source ] is null or undefined
                    transitions[ source ] ?= {}
                    transitions[ source ][ target ] ?= 0
                    transitions[ source ][ target ]++
                    # Check if symbols[ source ] is null or undefined
                    symbols[ source ] ?= {}
                    symbols[ source ][ item[ j ] ] ?= 0
                    symbols[ source ][ item[ j ] ]++

            for src, transition of transitions
                for dst, transition_count of transition
                    @transitionProbability[ src ] ?= {}
                    # Current transition probability = number of transitions / the sum of the current source
                    @transitionProbability[ src ][ dst ] = transition_count / sum[ src ]
                for symbol, symbol_count of symbols[ src ]
                    @emissionProbability[ src ] ?= {}
                    # Current emission probability = number of symbols / the sum of the current source
                    @emissionProbability[ src ][ symbol ] = symbol_count / sum[ src ]

            # Repeat if not true
            shouldRemitProbabilityeat =
                original.st isnt @states or
                original.sy isnt @symbols or
                original.initProbability isnt @initialProbability or
                original.transProbability isnt JSON.stringify @transitionProbability or
                original.emitProbability isnt JSON.stringify @emissionProbability

    ###
    Initializes this model with given items.
    @param [Array<String>] items - Items used to reestimate the model
    @param [Integer] n - Number of states to use in this model
    ###
    initialize: (items, n) ->
        paths = []
        @symbols = []
        @states = ("#{i}" for i in [1..n])
        @finalState = 'F'
        @states.push @finalState

        ###
        Items = sentence
        Symbol = Words

        Example:
            Where is CIT located?
            - [ 'Where' , 'is', 'CIT', 'located']
        ###
        for sequence in items
            for symbol in sequence
                # Push if not yet in Symbols
                @symbols.push symbol unless symbol in @symbols

        ###
        Push possible paths of each word

        Example:
            Where -> is -> CIT -> located
                  -> are -> you -> located
        ###
        for sequence in items
            path = []
            for j in [1..sequence.length]
                path.push "#{1 + Math.floor j * n / (sequence.length + 1)}"
            path.push @finalState
            paths.push path

        @reestimate items, paths

    ###
    Returns the Viterbi approximation to the probability of this model generating
    given item using the fastest implementation available.
    @param [Array<String>] item - Item whose generation probability will be returned.
    @return [Float] Viterbi approximation to the probability of this markov model
    generating given item.
    ###
    viterbiApproximation: (item) ->
        return @viterbi( item ).probability

    ###
    Gets the most probable sequence of states generating given item (if there are any).
    @param [Array<String>] item - Item whose optimal state sequence will be returned.
    @return [Array<String>] Optimal state sequence generating given item.
    If given item can't be generate undefined is returned.
    ###
    optimalStateSequence: ( item ) ->
        return @viterbi( item ).path

    ###
    Returns the Viterbi approximation to the probability of this model generating
    given item.
    @param [Array<String>] item - Item whose generation probability will be returned.
    @return [Object] Viterbi approximation to the probability of this markov model
    generating given item: an object with a `probability` and a `path` key.
    ###
    viterbi: (item) ->

        V = [ {} ]
        path = {}
        
        for state in @states
            # Initial Probability of the state * Emission Probability of the state which emits a symbol item[0]
            V[ 0 ][ state ] = @initProbability( state ) * @emitProbability( state, item[0] )
            path[ state ] = [ state ]

        for t in [1...item.length]
            V.push {}
            newpath = {}

            for target in @states
                max = [ 0, null ]
                for source in @states
                    # Calculate transition probability * emission probability of item(parameter)
                    temitProbability = @transProbability( source, target ) * @emitProbability( target, item[ t ] )
                    calc = V[ t - 1 ][ source ] * temitProbability
                    max = [ calc, source ] if calc >= max[0]

                V[ t ][ target ] = max[0]
                # Concatinate the pat to the new path
                newpath[ target ] = path[ max[1] ].concat target
            
            path = newpath

        V.push {}
        newpath = {}

        max = [ 0, null ]
        for source in @states
            # Viterbi * transitionProbability from the source to the final state
            calc = V[ t - 1 ][ source ] * @transProbability source, @finalState
            # If calc is greater than the max then max = calc
            max = [ calc, source ] if calc >= max[0]

        # Vetirbi last item = max
        V[ item.length ][ @finalState ] = max[0]
        # Concatinate the final state to the path
        path[ @finalState ] = path[ max[1] ].concat @finalState

        max = [ 0, null ]
        for state in @states
            calc = V[ item.length ][ state ] ? 0
            max = [ calc, state ] if calc >= max[0]

        return {
            probability: parseFloat max[0].toFixed 6
            path: path[ max[1] ]
        }

module.exports = HMM