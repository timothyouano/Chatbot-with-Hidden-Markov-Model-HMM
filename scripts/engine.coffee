###
===============================================================================
Description:
  An engine who handles the Messenger to hubot interactions which calls out the
  Hidden Markov Model which parses the answers/replies to the messages received

For full documentation
  Please see READEME.md

Messenger Hubot Documentation:
  https://github.com/chen-ye/hubot-fb
  See .env for Setup (API Keys and more)
===============================================================================
###

Firebase                = require 'firebase'
FirebaseTokenGenerator  = require 'firebase-token-generator'

{Response} = require 'hubot'
hmmHandler = require "./hmmHandler"

autocorrect = require('autocorrect')()
emojiStrip = require('emoji-strip')
moment = require('moment')

keywordChecker = require "./keywordChecker"

module.exports = (robot) ->

    ###
    Random Fun Facts
    Saved in the firebase database under botEnv/funFacts
    ### 
    funFacts = []

    ###
    These are chats by the users that has static replies and does not
    need any Hidden Markov Model.
    These are usually commands by admins to the bot
    Save in the firebase database under botEnv/reservedWords
    ###
    reservedWords = []

    ###
    Threshold which the bot replies base on pre-defined message if exceeds or equal the threshold
    Save in the firebase database under botEnv/threshold
    ###
    threshold = parseFloat(0)

    # HMM Handler
    handler = new hmmHandler

    # Local Database
    json = []

    # Do not load unless configured
    return robot.logger.warning "firebase-brain: FIREBASE_URL not set. Not attempting to load FireBase brain." unless process.env.FIREBASE_URL?

    robot.logger.info "firebase-brain: Connecting to FireBase brain at #{process.env.FIREBASE_URL} "

    # Turn off autosave until Firebase connected successfully
    robot.brain.setAutoSave false

    # expose this reference to the Robot
    robot.firebaseBrain = new Firebase process.env.FIREBASE_URL
    
    # Log authentication
    onAuthCallback = (authData) ->
        if authData
            robot.logger.info 'firebase-brain: Authenticated successfully'
        else
            robot.logger.info 'firebase-brain: Client unauthenticated.'

    # Do authentication
    authenticate = (authData) =>
        robot.logger.info "firebase-brain: Attempting to authenticate using FIREBASE_SECRET"

        tokenGenerator = new FirebaseTokenGenerator process.env.FIREBASE_SECRET
        token = tokenGenerator.createToken({ "uid": "custom:hubot", "hubot": true });
        
        robot.firebaseBrain.authWithCustomToken token, (error, authData) ->
            if error
                robot.logger.warning 'firebase-brain: Login Failed!', error
    
    if process.env.FIREBASE_SECRET?
        do authenticate
        robot.firebaseBrain.offAuth authenticate
        robot.firebaseBrain.offAuth onAuthCallback
        robot.firebaseBrain.onAuth  onAuthCallback
        
    # Load the initial persistant brain
    robot.firebaseBrain.once 'value', (data) ->
        json = data.val()
        # Set Threshhold
        threshold = parseFloat(json['botEnv']['threshold'])
        # Set funFacts
        funFacts = (val for key, val of json['botEnv']['funFacts'])
        # Set reservedWords
        reservedWords = (val for key, val of json['botEnv']['reservedWords'])
        # Initialize all HMMs
        handler.initializeAll(json)
        # Initialize Keywords
        handler.intializeKeywords(json['botEnv']['keywords'])

    ###
    Concat words then push to a database
    @param words - words to be concatinated and pushed
    @param pushTo - database to be pushed
    ### 
    cleanAndPush = (words, pushTo) ->
        res = ""
        for i in [0..words.length - 1]
            res += words[i] + " "
        json[pushTo].push res.trim()
    
    ###
    Pushes variable json to firebase
    ###
    firebaseUpdate = () ->
        # Set funFacts
        funFacts = (val for key, val of json['botEnv']['funFacts'])
        # Set reservedWords
        reservedWords = (val for key, val of json['botEnv']['reservedWords'])
        # Initialize all HMMs
        handler.initializeAll(json)
        
        console.log "Updated Firebase"

        # Save new data to firebase
        sanatized_data = JSON.parse JSON.stringify(json)
        robot.firebaseBrain.set sanatized_data

    # Set Firebase update interval on start
    updateInterval = setInterval () ->
        firebaseUpdate()
    , ((60 * 5) * 1000)

    ###
    @param [String] arrray of words to be check if there are reserved words
    @return [Boolean] verdict if it is in the reservedWords variable
    ###
    checkReservedWords = (text) ->
        ctr = 0
        flag = false
        reservedCut = []
        for i in [0..reservedWords.length - 1]
            ctr = 0
            reservedCut = reservedWords[i].split(" ")
            if (reservedCut[0] in text) && text.length == 1
                flag = true
                break
            else
                for j in [0..reservedCut.length - 1]
                    if reservedCut[j] in text
                        ctr++
                if ctr >= reservedCut.length
                    flag = true
                    break
        return flag

    checkEmail = (text) ->
        emailPattern = /^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$/
        res = false
        if text.match( emailPattern )
            res = true
        return res

    
    # Every user chat gets captured and parsed by HMM for probability
    robot.hear /(.*)+/i, (res) ->

        # If user not in current saved users
        #if res.message.user not in json['users']
            #json['users'].push res.message.user

        # Make lower case, rmove emoji, remove ? and split by word
        words = emojiStrip(res.match[1]).trim().toLowerCase().replace("?", "").split " "
        console.log words
        if !checkReservedWords(words) && !checkEmail(res.match[1])
            for i in [0..words.length - 1]
                words[i] = words[i].trim()
                words[i] = autocorrect(words[i])
                console.log words[i]
                console.log "________________________"

            # Default reply
            messageRes = json['botEnv']['predefinedAnswers']['default']

            if handler.checkKeywords("entranceSched", words)
                cleanAndPush words, "entranceSched"
                if ( handler.getProbByName("entranceSched", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['entranceSched']
            else if handler.checkKeywords("admission", words)
                cleanAndPush words, "admission"
                if ( handler.getProbByName("admission", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['admission']
            else if handler.checkKeywords("automate", words)
                cleanAndPush words, "automate"
                if ( handler.getProbByName("automate", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['automate']
            else if handler.checkKeywords("cutOff", words)
                cleanAndPush words, "cutOff"
                if ( handler.getProbByName("cutOff", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['cutOff']
            else if handler.checkKeywords("citPresident", words)
                cleanAndPush words, "citPresident"
                if ( handler.getProbByName("citPresident", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['citPresident']
            else if handler.checkKeywords("info", words)
                cleanAndPush words, "info"
                if ( handler.getProbByName("info", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['info']
            else if handler.checkKeywords("facts", words)
                cleanAndPush words, "facts"
                if ( handler.getProbByName("facts", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['facts']
                    messageRes += funFacts[Math.floor(Math.random() * funFacts.length)]
            else if handler.checkKeywords("tuition", words)
                cleanAndPush words, "tuition"
                if ( handler.getProbByName("tuition", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['tuition']
            else if handler.checkKeywords("ssgPresident", words)
                cleanAndPush words, "ssgPresident"
                if ( handler.getProbByName("ssgPresident", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['ssgPresident']
            else if handler.checkKeywords("careers", words)
                cleanAndPush words, "careers"
                if ( handler.getProbByName("careers",words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['careers']
            else if handler.checkKeywords("heads", words)
                cleanAndPush words, "heads"
                if ( handler.getProbByName("heads", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['heads']
            else if handler.checkKeywords("courses", words)
                cleanAndPush words, "courses"
                if ( handler.getProbByName("courses", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['courses']
            else if handler.checkKeywords("acadCalendar", words)
                cleanAndPush words, "acadCalendar"
                if ( handler.getProbByName("acadCalendar", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['acadCalendar']
            else if handler.checkKeywords("scholarship", words)
                cleanAndPush words, "scholarship"
                if ( handler.getProbByName("scholarship", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['scholarship'] 
            else if handler.checkKeywords("whyCIT", words)
                cleanAndPush words, "whyCIT"
                if ( handler.getProbByName("whyCIT", words) ) >= threshold
                    messageRes = json['botEnv']['predefinedAnswers']['whyCIT']      
            else
                json['unknown'].push emojiStrip(res.match[1]).trim().replace("?", "")


            res.send messageRes

    ###
    ========================
    Static generated replies
    ========================
    ###

    robot.hear /^[h|H]ello/i, (res) ->
        sender   = res.message.user.name
        res.envelope.fb = {
            richMsg: {
                attachment: {
                    type: "template",
                    payload: {
                        template_type: "generic",
                        elements:[
                            title:"Hi, " + sender + json['botEnv']['predefinedAnswers']['greetings'],
                            image_url:"https://scontent.fceb2-1.fna.fbcdn.net/v/t1.0-9/53336723_310413972993505_7510075656533704704_n.png?_nc_cat=101&_nc_eui2=AeFdhz2PTpK6ESz-OUccju_ojY4z2GRoErJXLflwC8E5CyRf-eJM2Ak8ihwD5N6bY6y62Kqlg6gScnQ-6lk-cJM4xvcKVR7o4NhWeaWlpIfoVg&_nc_ht=scontent.fceb2-1.fna&oh=d7ab0aeb541ff74ce0e1ecb1f4122e17&oe=5D185B26",
                            buttons:[
                                {
                                    type: "postback",
                                    title: "FAQs",
                                    payload: "faqs"
                                },
                                {
                                    type: "postback",
                                    title: "Ask for Human Representative",
                                    payload: "ask_human"
                                }
                            ]
                        ]
                    }
                }
            }
        }
        res.send()

    robot.hear /^[h|H]i/i, (res) ->
        sender   = res.message.user.name
        res.envelope.fb = {
            richMsg: {
                attachment: {
                    type: "template",
                    payload: {
                        template_type: "generic",
                        elements:[
                            title:"Hello, " + sender + json['botEnv']['predefinedAnswers']['greetings'],
                            image_url:"https://scontent.fceb2-1.fna.fbcdn.net/v/t1.0-9/53336723_310413972993505_7510075656533704704_n.png?_nc_cat=101&_nc_eui2=AeFdhz2PTpK6ESz-OUccju_ojY4z2GRoErJXLflwC8E5CyRf-eJM2Ak8ihwD5N6bY6y62Kqlg6gScnQ-6lk-cJM4xvcKVR7o4NhWeaWlpIfoVg&_nc_ht=scontent.fceb2-1.fna&oh=d7ab0aeb541ff74ce0e1ecb1f4122e17&oe=5D185B26",
                            buttons:[
                                {
                                    type: "postback",
                                    title: "FAQs",
                                    payload: "faqs"
                                },
                                {
                                    type: "postback",
                                    title: "Ask for Human Representative",
                                    payload: "ask_human"
                                }
                            ]
                        ]
                    }
                }
            }
        }
        res.send()

    # Send options when hearing help
    robot.hear /!help/i, (res) ->
        res.envelope.fb = {
            richMsg: {
                attachment: {
                    type: "template",
                    payload: {
                        template_type: "button",
                        text: json['botEnv']['predefinedAnswers']['helpDefault'],
                        buttons: [
                            {
                                type: "postback",
                                title: "Why CIT-U?",
                                payload: "why_cit"
                            },
                            {
                                type: "postback",
                                title: "Enrollment Requirements",
                                payload: "requirements"
                            },
                            {
                                type: "postback",
                                title: "More Options",
                                payload: "more_options"
                            }
                        ]
                    }
                }
            }
        }
        res.send()

    ###
    Postbacks from '!help' buttons
    ###
    robot.on "fb_postback", (envelope) -> 
        res = new Response robot, envelope, undefined
        if envelope.payload is "why_cit"
            res.send json['botEnv']['predefinedAnswers']['whyCIT']
        else if envelope.payload is "requirements"
            res.send json['botEnv']['predefinedAnswers']['admission']
        else if envelope.payload is "much_more_options"
            res.envelope.fb = {
                richMsg: {
                    attachment: {
                        type: "template",
                        payload: {
                            template_type: "button",
                            text: "Here are more options I could help you with",
                            buttons: [
                                {
                                    type: "postback",
                                    title: "Cut-off grade",
                                    payload: "cut_off"
                                },
                                {
                                    type: "postback",
                                    title: "Quota per program",
                                    payload: "quota_program"
                                },
                                {
                                    type: "postback",
                                    title: "Entrance Sched",
                                    payload: "sched_exam"
                                }
                            ]
                        }
                    }
                }
            }
            res.send()
        else if envelope.payload is "cut_off"
            res.send json['botEnv']['predefinedAnswers']['cutOff']
        else if envelope.payload is "quota_program"
            res.send ['botEnv']['predefinedAnswers']['quota']
        else if envelope.payload is "sched_exam"
            res.send ['botEnv']['predefinedAnswers']['entranceSched']
        else if envelope.payload is "enroll_timespan"
            res.send ['botEnv']['predefinedAnswers']['enrollTimespan']
        else if envelope.payload is "scholarships"
            res.send ['botEnv']['predefinedAnswers']['scholarship']
        else if envelope.payload is "more_options"
            res.envelope.fb = {
                richMsg: {
                    attachment: {
                        type: "template",
                        payload: {
                            template_type: "button",
                            text: "Here are more options I could help you with",
                            buttons: [
                                {
                                    type: "postback",
                                    title: "Enrollment timespan",
                                    payload: "enroll_timespan"
                                },
                                {
                                    type: "postback",
                                    title: "Available Scholarships",
                                    payload: "scholarships"
                                },
                                {
                                    type: "postback",
                                    title: "More Options",
                                    payload: "much_more_options"
                                }
                            ]
                        }
                    }
                }
            }
            res.send()
        else if envelope.payload is "ask_human"
            res.send "Okay, please wait a minute."
        else if envelope.payload is "faqs"
            res.envelope.fb = {
                richMsg: {
                    attachment: {
                        type: "template",
                        payload: {
                            template_type: "button",
                            text: "What can I do to help you?",
                            buttons: [
                                {
                                    type: "postback",
                                    title: "Why CIT-U?",
                                    payload: "why_cit"
                                },
                                {
                                    type: "postback",
                                    title: "Enrollment Requirements",
                                    payload: "requirements"
                                },
                                {
                                    type: "postback",
                                    title: "More Options",
                                    payload: "more_options"
                                }
                            ]
                        }
                    }
                }
            }
            res.send()

    # Override timed update (Updates immediately but does not resets timeclock of timed update)
    robot.hear /!overrideupdate/, (res) ->
        firebaseUpdate()
        res.send "Updated the database"

    # What is your name
    robot.hear /^[w|W]hat is your name$/i, (res) ->
        sender = res.message.user.name
        res.envelope.fb = {
            richMsg: {
                attachment: {
                    type: "template",
                    payload: {
                        template_type: "generic",
                        elements:[
                            title:"Hi " + sender + ".\nI'm Tiknoy. The CIT-U's helpful chatbot!",
                            image_url:"https://scontent.fceb2-1.fna.fbcdn.net/v/t1.0-9/53336723_310413972993505_7510075656533704704_n.png?_nc_cat=101&_nc_eui2=AeFdhz2PTpK6ESz-OUccju_ojY4z2GRoErJXLflwC8E5CyRf-eJM2Ak8ihwD5N6bY6y62Kqlg6gScnQ-6lk-cJM4xvcKVR7o4NhWeaWlpIfoVg&_nc_ht=scontent.fceb2-1.fna&oh=d7ab0aeb541ff74ce0e1ecb1f4122e17&oe=5D185B26"
                        ]
                    }
                }
            }
        }
        res.send()

    # Static how old are you
    # [h|H] = How or how
    robot.hear /^[h|H]ow old are you[?]?$/i, (res) ->
        dateCreated = moment("Dec 19, 2018")
        dateNow = moment()

        diffDuration = moment.duration(dateNow.diff(dateCreated))

        res.send "As of the moment I am " + diffDuration.months() + " months, " + diffDuration.days() + " days, and " + diffDuration.hours() + " hours old."

    # Static how long will the enrollment take
    # [h|H] = How or how
    robot.hear /^[h|H]ow long [will|is] the enrollment take [?]?$/i, (res) ->
        res.send "The admission and enrollment application process takes only 4 hours or half of a day, provided that all requirements are present upon application"

    # Sets the bot's threshold through chat
    robot.hear /!setthreshold (.*)+/i, (res) ->
        threshold = parseFloat( res.match[1] , 10 )
        json['botEnv']['threshold'] = threshold
        res.send "The threshold is currently: " + threshold
    
    # Gets the bot's threshold
    robot.hear /!getthreshold/i, (res) ->
        res.send "The threshold is currently: " + threshold

    # Gets the bot's threshold
    robot.hear /!handler/i, (res) ->
        # Get scholarship data
        scholarData = []
        for i in [1..json['scholarship'].length - 1]
            scholarData.push json['scholarship'][i].split(" ")

        handler.create "scholarship"
        handler.initializeAll(json)

        console.log handler.getProbByName("scholarship", ["what", "are", "the", "scholarships"])


    # If bot hears an email
    robot.hear /^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$/i, (res) ->
        messageRes = "I have passed your email to a human representative, expect a response within 24 hours 😄\nIn the mean time I have a fun fact for you! 🎊 🎉 💯\n\n"
        messageRes += funFacts[Math.floor(Math.random() * funFacts.length)]
        json['emails'].push res.message.text
        res.send messageRes