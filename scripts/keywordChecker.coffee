###
Checks the keywords for the Hidden Markov Model
See functions for full documentation

Author: Timothy Ouano & Ma.Trisha Tagadiad
###

class KeywordChecker

    ###
    Constructs a new Keyword Checker.
    @param [Dict<int,Array[String]>] pairedWords - contains the paired words to be check
    @param [Array<String>] singleWord - contains the words to be check
    @return [KeywordCheck] new Keyword Checker
    ###
    constructor: (
        @pairedWords = [],
        @singleWord = []
    ) ->

    ###
    Pushes an array of strings to the pairedWords
    @param [String] firstWord - first word to be pushed
    @param [String] secondWord - second word to be pushed
    ###
    addPair: (firstWord, secondWord) ->
        @pairedWords.push [firstWord, secondWord]

    ###
    Pushes a string to the singleWord variable
    @param [String] word - Word to be pushed
    ###
    addSingle: (word) ->
        @singleWord.push word

    ###
    Checks in pairs if contains keywords
    @private
    @param [Array<String>] wordArr - the array to be checked if there are keywords
    @return [Boolean] Result of the check
    ###
    checkPair: (wordArr) ->
        res = false
        for own key,val of @pairedWords
            if (val[0] in wordArr) && (val[1] in wordArr)
                res = true
                break;
        return res

    ###
    Checks a word if it is a keyword
    @private
    @param [Array<String>] wordArr - the array to be checked if there are keywords
    @return [Boolean] Result of the check
    ###
    checkSingle: (wordArr) ->
        res = false
        for i in [0..@singleWord.length - 1]
            if (@singleWord[i] in wordArr)
                res = true
                break;
        return res

    ###
    Checks if the given word is a keyword
    @param [Array<String>] wordArr - the array to be checked if there are keywords
    @return [Boolean] Result of the check
    ###
    check: (wordArr) ->
        return @checkSingle(wordArr) || @checkPair(wordArr) ? true : false

module.exports = KeywordChecker