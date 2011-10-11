g = this

getNMapFirst = ->
    nmap    = g.object( @getSetting "keyMappingNormal" )
    pageMap = @getSetting "pageMap"

    unless window.location.href?.length > 0
        return nmap

    myMap = nmap
    for url,map of pageMap
        if @isUrlMatched( window.location.href, url )
            g.extend( map.nmap, myMap )

    @getNMap = -> myMap
    myMap

getIMapFirst = ->
    imap    = g.object( @getSetting "keyMappingInsert" )
    pageMap = @getSetting "pageMap"

    unless window.location.href?.length > 0
        return nmap

    myMap = imap
    for url,map of pageMap
        if @isUrlMatched( window.location.href, url )
            g.extend( map.imap, myMap )

    @getIMap = -> myMap
    myMap

getAliasFirst = ->
    aliases = g.object( @getSetting "aliases" )
    pageMap = @getSetting "pageMap"

    unless window.location.href?.length > 0
        return nmap

    myAlias = aliases
    for url,map of pageMap
        if @isUrlMatched( window.location.href, url )
            g.extend( map.alias, myAlias )

    @getAlias = -> myAlias
    myAlias

g.model =
    initEnabled  : false
    domReady     : false
    disAutoFocus : false
    searcher     : null
    pmRegister   : null
    curMode      : null
    settings     : null

    changeMode   :(newMode) ->
        if @curMode? then @curMode.exit()
        @curMode = newMode
        @curMode.enter()

    init : ->
        @enterNormalMode()
        @commandManager = new g.CommandManager
        @pmRegister     = new g.PageMarkRegister

    isReady : -> @initEnabled and @domReady

    setPageMark : (key) ->
        mark      = {}
        mark.top  = window.pageYOffset
        mark.left = window.pageXOffset

        @pmRegister.set mark, key

    goPageMark : (key) ->
        offset = @pmRegister.get key
        if offset then g.view.scrollTo offset.left, offset.top

    setSearcher : (@searcher) ->

    cancelSearchHighlight : -> if @searcher? then @searcher.cancelHighlight()

    enterNormalMode : ->
        g.logger.d "enterNormalMode"
        @changeMode new g.NormalMode

    enterInsertMode : ->
        g.logger.d "enterInsertMode"
        @changeMode new g.InsertMode

    enterCommandMode : ->
        g.logger.d "enterCommandMode"
        @cancelSearchHighlight()
        @changeMode new g.CommandMode

    enterSearchMode : (backward, searcher_) ->
        @searcher = searcher_ ? new g.NormalSearcher

        g.logger.d "enterSearchMode"

        @changeMode( (new g.SearchMode).init( @searcher, backward ) )
        @setPageMark();

    enterFMode : (opt) ->
        g.logger.d "enterFMode"
        @changeMode( (new g.FMode).setOption( opt ) )

    isInNormalMode  : -> @curMode.getName() == "NormalMode"
    isInInsertMode  : -> @curMode.getName() == "InsertMode"
    isInSearchMode  : -> @curMode.getName() == "SearchMode"
    isInCommandMode : -> @curMode.getName() == "CommandMode"
    isInFMode       : -> @curMode.getName() == "FMode"

    goNextSearchResult : (reverse) ->
        unless @searcher? then return

        @setPageMark()
        @searcher.goNext reverse

    getNMap : getNMapFirst

    getIMap : getIMapFirst

    getAlias : getAliasFirst

    getSetting : (name) -> @settings[name]

    escape : ->
        @commandManager.reset()
        g.view.hideStatusLine()
        if not @isInNormalMode() then @enterNormalMode()

    onBlur : -> @curMode.blur()

    prePostKeyEvent : (key, ctrl, alt, meta) ->
        @disAutoFocus = false
        @curMode.prePostKeyEvent(key, ctrl, alt, meta)

    isValidKeySeq : (keySeq) ->
        if @getKeyMapping()[keySeq]
            return true
        else
            return false

    isValidKeySeqAvailable : (keySeq) ->
        # since escaping meta character for regexp is so complex that
        # using regexp to compare should cause bugs, using slice & comparison
        # with '==' may be a better & simple way.
        keyMapping = @getKeyMapping()
        length     = keySeq.length

        for seq, command of keyMapping
            cmpStr = seq.slice( 0, length )
            pos    = cmpStr.indexOf("<", 0)
            if pos >= 0
                pos = seq.indexOf( ">", pos )
                if pos >= length
                    cmpStr = seq.slice( 0, pos+1 )
            if keySeq == cmpStr
                return true

        return false

    isUrlMatched : (url, matchPattern) ->
        str = matchPattern.replace(/\*/g, ".*" )
                          .replace(/\/$/g, "")
                          .replace(/\//g, "\\/")
        str = "^" + str + "$"
        url = url.replace(/\/$/g, "")

        regexp = new RegExp(str, "m")
        if regexp.test( url )
            g.logger.d "URL pattern matched:#{url}:#{matchPattern}"
            return true

        return false

    isEnabled : ->
        urls = @getSetting "ignoredUrls"

        for url in urls
            if @isUrlMatched window.location.href, url
                g.logger.d "matched ignored list"
                return false

        return true

    handleKey : (msg) -> @commandManager.handleKey msg, @getKeyMapping()

    triggerCommand : (method, args) ->
        if @curMode[method]?
            @curMode[method]( args )
        else
            g.logger.e "INVALID command!:", method

    onSettings : (msg) ->
        if msg.name == "all"
            @settings = msg.value
        else
            @settings[msg.name] = msg.value

        if not @isEnabled()
            @settings.keyMappingNormal = {}
            @settings.keyMappingInsert = {}

        if msg.name == "keyMappingNormal"
            @getNMap = getNMapFirst
        else if msg.name == "keyMappingInsert"
            @getIMap = getIMapFirst
        else if msg.name == "aliases"
            @getAlias = getAliasFirst

    onFocus : (target) ->
        if @isInCommandMode() or @isInSearchMode()
            g.logger.d "onFocus:current mode is command or search.do nothing"
            return

        if @disAutoFocus
            setTimeout( =>
                @disAutoFocus = false
            , 500)
            @enterNormalMode()
            g.view.blurActiveElement()
        else
            if g.util.isEditable target
                @enterInsertMode()
            else
                @enterNormalMode()

    getKeyMapping : -> @curMode.getKeyMapping()

    onInitEnabled : ( msg ) ->
        g.logger.d "onInitEnabled"
        @onSettings msg

        @disAutoFocus = @getSetting "disableAutoFocus"
        @initEnabled = true
        if @domReady then @onDomReady()

    onDomReady : ->
        g.logger.d "onDomReady"
        @domReady = true

        if not @initEnabled
            g.logger.w "onDomReady is called before onInitEnabled"
            return

        g.view.init()

        if g.util.isEditable( document.activeElement ) and not @disAutoFocus
            @enterInsertMode()
        else
            @enterNormalMode()
$(document.body).ready( =>
    g.model.onDomReady()
)

