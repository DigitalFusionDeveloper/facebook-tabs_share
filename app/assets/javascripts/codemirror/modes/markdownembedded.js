CodeMirror.defineMode("markdownembedded", function(config, parserConfig) {

  //config settings
  var scriptStartRegex = parserConfig.scriptStartRegex || /^<%=?/i,
      scriptEndRegex = parserConfig.scriptEndRegex || /^%>/i;

  //inner modes
  var scriptingMode, markdownMode, textMode;

  //tokenizer when in markdown mode
  function markdownDispatch(stream, state) {
      if (stream.match(scriptStartRegex, true)) {
          state.scriptingState = CodeMirror.startState(scriptingMode);
          state.markdownState = CodeMirror.startState(markdownMode);
          state.token=scriptingDispatch;
          return scriptingMode.token(stream, state.scriptState);
          }
      else
          return markdownMode.token(stream, state.markdownState);
    }

  //tokenizer when in scripting mode
  function scriptingDispatch(stream, state) {
      if (stream.match(scriptEndRegex, true))  {
          state.scriptingState = CodeMirror.startState(scriptingMode);
          state.markdownState = CodeMirror.startState(markdownMode);
          state.token=markdownDispatch;
          return markdownMode.token(stream, state.markdownState);
         }
      else {
          return scriptingMode.token(stream, state.scriptState);
      }
   }

   function textDispatch(stream, state) {
      return textMode.token(stream, state.textState);
   }


  return {
    startState: function() {
      scriptingMode = scriptingMode || CodeMirror.getMode(config, "ruby");
      markdownMode = markdownMode || CodeMirror.getMode(config, "markdown");
      textMode = textMode || CodeMirror.getMode(config, "text/plain");
      return {
          token :  parserConfig.startOpen ? scriptingDispatch : markdownDispatch,
          markdownState : CodeMirror.startState(markdownMode),
          scriptState : CodeMirror.startState(scriptingMode),
          textState : CodeMirror.startState(textMode)
      };
    },

    token: function(stream, state) {
      return state.token(stream, state);
    },

    indent: function(state, textAfter) {
      if (state.token == markdownDispatch)
        //return markdownMode.indent(state.markdownState, textAfter);
        return;
      else if (scriptingMode.indent)
        return scriptingMode.indent(state.scriptState, textAfter);
    },

    copyState: function(state) {
      return {
       token : state.token,
       markdownState : CodeMirror.copyState(markdownMode, state.markdownState),
       scriptState : CodeMirror.copyState(scriptingMode, state.scriptState)
      };
    },

    electricChars: "/{}:",

    innerMode: function(state) {
      if (state.token == scriptingDispatch) return {state: state.scriptState, mode: scriptingMode};
      else return {state: state.markdownState, mode: markdownMode};
    }
  };
}, "markdown");

CodeMirror.defineMIME("application/x-merb", { name: "markdownembedded", scriptingModeSpec:"ruby"});
