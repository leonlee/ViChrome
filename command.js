(function() {
  var escape, g, sendToBackground, triggerInsideContent;
  var __indexOf = Array.prototype.indexOf || function(item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (this[i] === item) return i;
    }
    return -1;
  }, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  g = this;
  sendToBackground = function(com, args) {
    return chrome.extension.sendRequest({
      command: com,
      args: args
    }, g.handler.onCommandResponse);
  };
  triggerInsideContent = function(com, args) {
    return g.model.triggerCommand("req" + com, args);
  };
  escape = function(com) {
    return triggerInsideContent("Escape");
  };
  g.CommandExecuter = (function() {
    function CommandExecuter() {}
    CommandExecuter.prototype.commandsBeforeReady = ["OpenNewTab", "CloseCurTab", "MoveToNextTab", "MoveToPrevTab", "NMap", "IMap", "Alias", "OpenNewWindow", "RestoreTab"];
    CommandExecuter.prototype.commandTable = {
      Open: triggerInsideContent,
      OpenNewTab: sendToBackground,
      CloseCurTab: sendToBackground,
      MoveToNextTab: sendToBackground,
      MoveToPrevTab: sendToBackground,
      NMap: sendToBackground,
      IMap: sendToBackground,
      Alias: sendToBackground,
      OpenNewWindow: sendToBackground,
      ReloadTab: triggerInsideContent,
      ScrollUp: triggerInsideContent,
      ScrollDown: triggerInsideContent,
      ScrollLeft: triggerInsideContent,
      ScrollRight: triggerInsideContent,
      PageHalfUp: triggerInsideContent,
      PageHalfDown: triggerInsideContent,
      PageUp: triggerInsideContent,
      PageDown: triggerInsideContent,
      GoTop: triggerInsideContent,
      GoBottom: triggerInsideContent,
      NextSearch: triggerInsideContent,
      PrevSearch: triggerInsideContent,
      BackHist: triggerInsideContent,
      ForwardHist: triggerInsideContent,
      GoCommandMode: triggerInsideContent,
      GoSearchModeForward: triggerInsideContent,
      GoSearchModeBackward: triggerInsideContent,
      GoLinkTextSearchMode: triggerInsideContent,
      GoFMode: triggerInsideContent,
      FocusOnFirstInput: triggerInsideContent,
      BackToPageMark: triggerInsideContent,
      RestoreTab: sendToBackground,
      Escape: escape,
      "_ChangeLogLevel": triggerInsideContent
    };
    CommandExecuter.prototype.get = function() {
      return this.command;
    };
    CommandExecuter.prototype.set = function(command, times) {
      if (!command) {
        throw "invalid command";
      }
      this.command = command.replace(/^[\t ]*/, "").replace(/[\t ]*$/, "");
      this.times = times != null ? times : 1;
      return this;
    };
    CommandExecuter.prototype.parse = function() {
      var aliases;
      this.args = this.command.split(/\ +/);
      if (!this.args || this.args.length === 0) {
        throw "invalid command";
      }
      aliases = g.model.getAlias();
      if (aliases[this.args[0]]) {
        this.args = aliases[this.args[0]].split(' ').concat(this.args.slice(1));
      }
      if (this.commandTable[this.args[0]]) {
        return this;
      } else {
        throw "invalid command";
      }
    };
    CommandExecuter.prototype.execute = function() {
      var com;
      com = this.args[0];
      if (!(g.model.isReady() || __indexOf.call(this.commandsBeforeReady, com) >= 0)) {
        return;
      }
      return setTimeout(__bind(function() {
        var _results;
        _results = [];
        while (this.times--) {
          _results.push(this.commandTable[com](com, this.args.slice(1)));
        }
        return _results;
      }, this), 0);
    };
    return CommandExecuter;
  })();
  g.CommandManager = (function() {
    CommandManager.prototype.keyQueue = {
      init: function() {
        this.a = "";
        this.times = "";
        this.timerId = 0;
        return this.waiting = false;
      },
      stopTimer: function() {
        if (this.waiting) {
          g.logger.d("stop timeout");
          clearTimeout(this.timerId);
          return this.waiting = false;
        }
      },
      startTimer: function(callback, ms) {
        if (this.waiting) {
          return g.logger.e("startTimer:timer already running");
        } else {
          this.waiting = true;
          return this.timerId = setTimeout(callback, ms);
        }
      },
      queue: function(s) {
        if (s.search(/[0-9]/) >= 0 && this.a.length === 0) {
          this.times += s;
        } else {
          this.a += s;
        }
        return this;
      },
      reset: function() {
        this.a = "";
        this.times = "";
        return this.stopTimer();
      },
      isWaiting: function() {
        return this.waiting;
      },
      getTimes: function() {
        if (this.times.length === 0) {
          return 1;
        }
        return parseInt(this.times, 10);
      },
      getNextKeySequence: function() {
        var ret;
        this.stopTimer();
        if (g.model.isValidKeySeq(this.a)) {
          ret = this.a;
          this.reset();
          return ret;
        } else {
          if (!g.model.isValidKeySeqAvailable(this.a)) {
            g.logger.d("invalid key sequence: " + this.a);
            this.reset();
          } else {
            this.startTimer(__bind(function() {
              this.a = "";
              this.times = "";
              return this.waiting = false;
            }, this), g.model.getSetting("commandWaitTimeOut"));
          }
          return null;
        }
      }
    };
    function CommandManager() {
      this.keyQueue.init();
    }
    CommandManager.prototype.getCommandFromKeySeq = function(s, keyMap) {
      var keySeq;
      this.keyQueue.queue(s);
      keySeq = this.keyQueue.getNextKeySequence();
      if (keyMap && keySeq) {
        return keyMap[keySeq];
      }
    };
    CommandManager.prototype.reset = function() {
      return this.keyQueue.reset();
    };
    CommandManager.prototype.isWaitingNextKey = function() {
      return this.keyQueue.isWaiting();
    };
    CommandManager.prototype.handleKey = function(msg, keyMap) {
      var com, s, times;
      s = KeyManager.getKeyCodeStr(msg);
      times = this.keyQueue.getTimes();
      com = this.getCommandFromKeySeq(s, keyMap);
      if ((com != null) && com !== "<NOP>") {
        (new g.CommandExecuter).set(com, times).parse().execute();
        event.stopPropagation();
        return event.preventDefault();
      } else if (this.isWaitingNextKey()) {
        event.stopPropagation();
        return event.preventDefault();
      }
    };
    return CommandManager;
  })();
}).call(this);
