###
Handles making of hmm from firebase
###

hmm = require "./hmm"
keywordsChecker = require "./keywordChecker"

class hmmHandler

    ###
    Constructs a new Hidden Markov Model. All parameters are optional.
    @param [Dict<String,hmm>] name - name of HMM and hmm
    @param [Dict<String,keywordsChecker>] keywordsCheckerContainer - container of all the
    keywords checker of hmms
    @param [Array<String>] keys - contains all the keys of from the database
    @return [hmmHandler] new hmm Handler
    ###
    constructor: (
        @hmms = [],
        @keywordsCheckerContainer = []
        @keys = []
    ) ->

    ###
    Initializes a new hmm using the name received
    @param [String] name - prefered name of hmm in the dictionary
    ###
    create: (name) ->
        @hmms[name] = new hmm
        
    ###
    Intializes the hmmHandler by name
    @param [String] name - prefered name of the hmm in the dictionary
    @param [Dict<String,String>] data - Json file containing a key for each hmm and values respectively
    ###
    initializeByName: (name, data) ->
        @hmms[name].initialize( data, data.length )
        console.log @hmms[name]

    ###
    Initialize all hmms
    @param [Dict<String,String>] data -  Json file containing a key for each hmm and values respectively
    ###
    initializeAll: (data) ->
        # temp variable
        temp = []
        # example key = scholarship, value = what are the scholarships available
        for own key,value of data
            temp = []
            if key != "unknown" && key != "botEnv" && key != "emails"
                @hmms[key] = new hmm
                # Push the key
                @keys.push key
                # split values to words
                for j in [1..data[key].length - 1]
                    temp.push (data[key][j] + "").split(" ")
                @hmms[key].initialize( temp, temp.length )

    ###
    Keywords Check Initialize
    @param [Dict<String,String>] data - Json file containing a key for each hmm and values respectively
    ###
    intializeKeywords: (data) ->

        for i in [0..@keys.length - 1]
            # initialize
            @keywordsCheckerContainer[ @keys[i] ] = new keywordsChecker
            for own key,val of data[ @keys[i] ]
                # Check if has comma (regex)
                if /,/.test(val)
                    splitWords = val.split(",")
                    @keywordsCheckerContainer[ @keys[i] ].addPair splitWords[0], splitWords[1]
                else 
                    @keywordsCheckerContainer[ @keys[i] ].addSingle val

    ###
    Check keywords by name
    @param [String] key - Key of the HMM to be checked
    @param [Array<String>] wordArr - array of words to be check
    @return [Boolean] result of the keyword search
    ###
    checkKeywords: (key, wordArr) ->
        return @keywordsCheckerContainer[key].check wordArr

    ###
    @param [String] name - name of the hmm which will be tested into
    @param [Array<String>] words - sentences which is separated into words
    @return [Float] viterbiApproximation of the words in the hmm
    ###
    getProbByName: (name, words) ->
        return @hmms[name].viterbiApproximation( words ) * 10000

module.exports = hmmHandler